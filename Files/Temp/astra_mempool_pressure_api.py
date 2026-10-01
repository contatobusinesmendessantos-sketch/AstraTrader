#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Astra Mempool Pressure Service: API local para Expert Advisors do MT5."""

import csv
from datetime import datetime, timezone
import ipaddress
import json
import logging
from logging.handlers import RotatingFileHandler
import math
import re
import socket
import subprocess
import sys
import threading
import time
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Dict, Optional, Tuple
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

MEMPOOL_URL = "https://mempool.space/api/mempool"
FEES_URL = "https://mempool.space/api/v1/fees/recommended"
REQUEST_TIMEOUT_SECONDS = 10
LOG_MAX_BYTES = 5 * 1024 * 1024
LOG_BACKUP_COUNT = 5
SERVICE_NAME = "AstraMempoolService"
BASE_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG = {
    "host": "127.0.0.1",
    "port": 8765,
    "refresh_seconds": 60,
    "log_level": "INFO",
}
LOGGER = logging.getLogger("astra_mempool_pressure")


class JsonLogFormatter(logging.Formatter):
    """Emite eventos de log como objetos JSON, incluindo excecoes completas."""

    def format(self, record: logging.LogRecord) -> str:
        event = {
            "timestamp": datetime.fromtimestamp(record.created, timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "thread": record.threadName,
            "message": record.getMessage(),
        }
        if record.exc_info:
            event["exception"] = self.formatException(record.exc_info)
        return json.dumps(event, ensure_ascii=False, separators=(",", ":"))


def configure_logging(config: Dict[str, Any]) -> None:
    """Configura console e log rotativo logs/astra.log (5 MB, cinco backups)."""
    log_dir = BASE_DIR / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    level_name = str(config.get("log_level", "INFO")).upper()
    level = getattr(logging, level_name, logging.INFO)
    formatter = JsonLogFormatter()
    file_handler = RotatingFileHandler(
        log_dir / "astra.log",
        maxBytes=LOG_MAX_BYTES,
        backupCount=LOG_BACKUP_COUNT,
        encoding="utf-8",
    )
    console_handler = logging.StreamHandler()
    for handler in (file_handler, console_handler):
        handler.setFormatter(formatter)
        handler.setLevel(level)
    for old_handler in LOGGER.handlers[:]:
        LOGGER.removeHandler(old_handler)
        old_handler.close()
    LOGGER.setLevel(level)
    LOGGER.propagate = False
    LOGGER.addHandler(file_handler)
    LOGGER.addHandler(console_handler)


def load_config() -> Dict[str, Any]:
    """Carrega config.json ao lado do script e valida os valores essenciais."""
    config_path = BASE_DIR / "config.json"
    config = dict(DEFAULT_CONFIG)
    try:
        with config_path.open("r", encoding="utf-8") as config_file:
            loaded = json.load(config_file)
        if not isinstance(loaded, dict):
            raise ValueError("A raiz de config.json deve ser um objeto JSON.")
        config.update(loaded)
    except FileNotFoundError:
        print("config.json nao encontrado; usando configuracao padrao.", file=sys.stderr)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        raise RuntimeError("Configuracao invalida em {}: {}".format(config_path, exc)) from exc

    try:
        host = str(config["host"])
        host_ip = ipaddress.ip_address(host)
        if host_ip.version != 4 or not host_ip.is_loopback:
            raise ValueError("host deve ser um endereco de loopback, como 127.0.0.1")
        port = int(config["port"])
        refresh_seconds = int(config["refresh_seconds"])
        if not 1 <= port <= 65535:
            raise ValueError("port deve estar entre 1 e 65535")
        if refresh_seconds < 1:
            raise ValueError("refresh_seconds deve ser maior que zero")
        level_name = str(config.get("log_level", "INFO")).upper()
        if level_name not in logging._nameToLevel:
            raise ValueError("log_level invalido: {}".format(level_name))
    except (KeyError, TypeError, ValueError) as exc:
        raise RuntimeError("Valores invalidos em config.json: {}".format(exc)) from exc
    config.update({"host": host, "port": port, "refresh_seconds": refresh_seconds})
    config["log_level"] = level_name
    return config


def default_payload() -> Dict[str, Any]:
    """Representa a indisponibilidade dos dados sem derrubar o endpoint."""
    return {
        "success": False,
        "pressure_index": 0,
        "state": "LOW",
        "momentum": 0,
        "acceleration": 0,
        "recommended_fee": 0,
        "mempool_size": 0,
        "timestamp": 0,
    }


def find_listening_process(port: int) -> Tuple[Optional[int], str]:
    """Retorna PID e nome do processo que escuta a porta, usando ferramentas Windows."""
    try:
        result = subprocess.run(
            ["netstat", "-ano", "-p", "tcp"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        pid = None
        for line in result.stdout.splitlines():
            columns = line.split()
            if len(columns) < 5 or columns[3].upper() != "LISTENING":
                continue
            local_endpoint = columns[1].strip("[]")
            if local_endpoint.rsplit(":", 1)[-1] == str(port):
                try:
                    pid = int(columns[-1])
                except ValueError:
                    continue
                break
        if pid is None:
            return None, "desconhecido"

        process = subprocess.run(
            ["tasklist", "/FI", "PID eq {}".format(pid), "/FO", "CSV", "/NH"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        rows = list(csv.reader(process.stdout.splitlines()))
        process_name = rows[0][0] if rows and rows[0] else "desconhecido"
        return pid, process_name
    except (OSError, subprocess.SubprocessError, csv.Error) as exc:
        LOGGER.exception("Falha ao identificar processo da porta %d: %s", port, exc)
        return None, "desconhecido"


def port_is_available(host: str, port: int) -> bool:
    """Testa o bind local sem deixar o socket de verificacao aberto."""
    probe = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        probe.bind((host, port))
        return True
    except OSError:
        return False
    finally:
        probe.close()


def ensure_port_available(host: str, port: int) -> bool:
    """Mostra processo conflitante e so o finaliza apos confirmacao interativa."""
    if port_is_available(host, port):
        return True

    pid, process_name = find_listening_process(port)
    LOGGER.error(
        "Porta %d ocupada. Processo: %s; PID: %s", port, process_name, pid or "desconhecido"
    )
    print("Porta {} ocupada por {} (PID {}).".format(port, process_name, pid or "desconhecido"))
    if not sys.stdin.isatty():
        LOGGER.error("Sem terminal interativo; nao encerrarei processos automaticamente.")
        return False
    if pid is None:
        LOGGER.error("Nao foi possivel identificar o PID; liberacao automatica cancelada.")
        return False

    try:
        answer = input("Deseja finalizar esse processo com taskkill /F /PID {}? [s/N]: ".format(pid))
    except (EOFError, KeyboardInterrupt):
        return False
    if answer.strip().lower() not in ("s", "sim", "y", "yes"):
        LOGGER.warning("Inicializacao cancelada pelo usuario: porta %d ocupada.", port)
        return False

    try:
        result = subprocess.run(
            ["taskkill", "/F", "/PID", str(pid)],
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        LOGGER.exception("Nao foi possivel executar taskkill para PID %d: %s", pid, exc)
        return False
    if result.returncode != 0:
        LOGGER.error("taskkill falhou para PID %d: %s", pid, result.stderr.strip())
        return False
    LOGGER.warning("Processo PID %d finalizado a pedido do usuario.", pid)
    for _ in range(20):
        if port_is_available(host, port):
            return True
        time.sleep(0.25)
    LOGGER.error("A porta %d continua ocupada apos encerrar o PID %d.", port, pid)
    return False


def clamp(value: float, lower: float, upper: float) -> float:
    """Limita um numero a um intervalo inclusivo."""
    return max(lower, min(upper, value))


def non_negative_number(value: Any, field_name: str) -> float:
    """Converte valor numerico da API e rejeita NaN, infinito e valores negativos."""
    number = float(value)
    if not math.isfinite(number) or number < 0:
        raise ValueError("Campo {} nao e um numero finito nao negativo.".format(field_name))
    return number


class MempoolPressureEngine:
    """Coleta dados externos e calcula pressao e variacao entre atualizacoes."""

    def __init__(self, refresh_seconds: int) -> None:
        self.refresh_seconds = refresh_seconds
        self._lock = threading.Lock()
        self._history = deque(maxlen=3)
        self._data = default_payload()
        self._stop_event = threading.Event()
        self._consecutive_failures = 0
        self._last_attempt = 0.0
        self._last_update = 0.0
        self._thread = self._new_worker()
        self._supervisor = threading.Thread(
            target=self._supervise,
            name="mempool-supervisor",
            daemon=True,
        )

    def _new_worker(self) -> threading.Thread:
        """Cria uma nova thread de polling para o supervisor poder reinicia-la."""
        return threading.Thread(
            target=self._update_loop,
            name="mempool-updater",
            daemon=True,
        )

    def start(self) -> None:
        """Inicia a primeira consulta imediatamente em uma thread dedicada."""
        LOGGER.info("Iniciando thread de polling do mempool.space")
        self._thread.start()
        self._supervisor.start()

    def stop(self) -> None:
        """Solicita parada e aguarda a consulta em andamento por ate o timeout HTTP."""
        self._stop_event.set()
        if self._thread.is_alive():
            self._thread.join(timeout=REQUEST_TIMEOUT_SECONDS * 2 + 1)
        if self._supervisor.is_alive():
            self._supervisor.join(timeout=2)

    @staticmethod
    def _fetch_json(url: str) -> Dict[str, Any]:
        """Consulta um endpoint HTTPS do mempool.space usando urllib da stdlib."""
        request = Request(
            url,
            headers={
                "Accept": "application/json",
                "User-Agent": "AstraMempoolPressureService/1.0",
            },
        )
        with urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
            if response.status != 200:
                raise URLError("HTTP {} recebido de {}".format(response.status, url))
            payload = json.loads(response.read().decode("utf-8"))
        if not isinstance(payload, dict):
            raise ValueError("Resposta JSON inesperada de {}".format(url))
        return payload

    def update(self) -> bool:
        """Atualiza métricas; retorna sucesso e registra stack trace de qualquer falha."""
        LOGGER.info("Consultando dados publicos do mempool.space")
        with self._lock:
            self._last_attempt = time.time()
        try:
            mempool = self._fetch_json(MEMPOOL_URL)
            fees = self._fetch_json(FEES_URL)
            count_value = non_negative_number(mempool["count"], "count")
            vsize = non_negative_number(mempool["vsize"], "vsize")
            recommended_fee = non_negative_number(fees["fastestFee"], "fastestFee")
            mempool_size = int(count_value)

            # Indice proprio ponderado: taxa recomendada 55%, quantidade 30% e
            # volume virtual 15%. Cada sinal e limitado a 0..100.
            fee_pressure = clamp(recommended_fee, 0.0, 100.0)
            count_pressure = clamp(mempool_size / 300000.0 * 100.0, 0.0, 100.0)
            vsize_pressure = clamp(vsize / 1_500_000_000.0 * 100.0, 0.0, 100.0)
            pressure_index = int(round(
                0.55 * fee_pressure + 0.30 * count_pressure + 0.15 * vsize_pressure
            ))
            pressure_index = int(clamp(pressure_index, 0, 100))

            with self._lock:
                previous = list(self._history)
                momentum = pressure_index - previous[-1] if previous else 0
                acceleration = (
                    momentum - (previous[-1] - previous[-2]) if len(previous) >= 2 else 0
                )
                self._history.append(pressure_index)
                self._last_update = time.time()
                self._consecutive_failures = 0
                if pressure_index <= 25:
                    state = "LOW"
                elif pressure_index <= 50:
                    state = "NORMAL"
                elif pressure_index <= 75:
                    state = "HIGH"
                else:
                    state = "EXTREME"
                self._data = {
                    "success": True,
                    "pressure_index": pressure_index,
                    "state": state,
                    "momentum": momentum,
                    "acceleration": acceleration,
                    "recommended_fee": recommended_fee,
                    "mempool_size": mempool_size,
                    "timestamp": int(time.time()),
                }

            LOGGER.info(
                "Atualizacao concluida: pressure=%d state=%s count=%d vsize=%.0f "
                "fee=%.2f sat/vB momentum=%d acceleration=%d",
                pressure_index,
                state,
                mempool_size,
                vsize,
                recommended_fee,
                momentum,
                acceleration,
            )
            return True
        except (HTTPError, URLError, OSError, ValueError, TypeError, KeyError) as exc:
            LOGGER.exception("Falha ao atualizar dados do mempool.space: %s", exc)
            self._record_failure()
        except Exception:
            # Protege a thread de polling contra formatos inesperados da API.
            LOGGER.exception("Erro inesperado durante a atualizacao do mempool.space")
            self._record_failure()
        return False

    def _record_failure(self) -> None:
        """Invalida dados antigos e registra o contador de falhas consecutivas."""
        with self._lock:
            self._data = default_payload()
            self._consecutive_failures += 1

    def health_snapshot(self, port: int, started_at: float) -> Dict[str, Any]:
        """Retorna saude do listener, idade dos dados e estado do polling."""
        with self._lock:
            worker_alive = self._thread.is_alive()
            last_update = (
                datetime.fromtimestamp(self._last_update, timezone.utc).isoformat()
                if self._last_update > 0
                else ""
            )
            last_attempt = (
                datetime.fromtimestamp(self._last_attempt, timezone.utc).isoformat()
                if self._last_attempt > 0
                else ""
            )
            data_success = self._data["success"]
            failures = self._consecutive_failures
        return {
            "status": "ok",
            "service": SERVICE_NAME,
            "port": port,
            "last_update": last_update,
            "uptime": round(max(0.0, time.monotonic() - started_at), 2),
            "last_attempt": last_attempt,
            "data_success": data_success,
            "polling_status": "running" if worker_alive else "restarting",
            "consecutive_failures": failures,
        }

    def _supervise(self) -> None:
        """Recria a thread de polling se ela morrer inesperadamente."""
        while not self._stop_event.wait(5):
            if not self._thread.is_alive():
                LOGGER.error("Thread de polling encerrada; reiniciando coleta")
                self._thread = self._new_worker()
                self._thread.start()

    def _update_loop(self) -> None:
        """Executa já; falhas acionam retry progressivo e sucesso mantém o intervalo."""
        while not self._stop_event.is_set():
            succeeded = self.update()
            with self._lock:
                failures = self._consecutive_failures
            retry_delay = min(self.refresh_seconds, 5 * (2 ** min(failures, 4)))
            delay = self.refresh_seconds if succeeded else retry_delay
            if not succeeded:
                LOGGER.warning("Polling falhou; nova tentativa em %d segundos", delay)
            if self._stop_event.wait(delay):
                break

    def snapshot(self) -> Dict[str, Any]:
        """Retorna uma copia consistente do estado atual."""
        with self._lock:
            return dict(self._data)


class PressureRequestHandler(BaseHTTPRequestHandler):
    """Expõe /pressure e /health e registra acessos no log rotativo."""

    engine: Optional[MempoolPressureEngine] = None
    service_port = DEFAULT_CONFIG["port"]
    started_at = time.monotonic()

    def do_GET(self) -> None:
        path = urlsplit(self.path).path
        LOGGER.info("HTTP recebido: GET %s de %s", self.path, self.client_address[0])
        if path == "/health":
            health = (
                self.engine.health_snapshot(self.service_port, self.started_at)
                if self.engine
                else {
                    "status": "starting",
                    "service": SERVICE_NAME,
                    "port": self.service_port,
                    "last_update": "",
                    "uptime": 0,
                    "data_success": False,
                    "polling_status": "starting",
                    "consecutive_failures": 0,
                }
            )
            self._send_json(health, status=200)
        elif path == "/pressure":
            payload = self.engine.snapshot() if self.engine else default_payload()
            self._send_json(payload, status=200)
        else:
            self._send_json({"error": "not found"}, status=404)

    def _send_json(self, payload: Dict[str, Any], status: int) -> None:
        """Serializa e envia uma resposta JSON UTF-8 sem cache."""
        body = json.dumps(payload, separators=(",", ":"), allow_nan=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            LOGGER.warning("Cliente encerrou a conexao antes do envio completo da resposta")

    def log_message(self, format_string: str, *args: Any) -> None:
        """Redireciona os logs HTTP nativos para o sistema de logging do servico."""
        LOGGER.info("HTTP %s", format_string % args)


class LocalThreadingHTTPServer(ThreadingHTTPServer):
    """Servidor HTTP concorrente com threads de requisicao descartaveis."""

    daemon_threads = True
    allow_reuse_address = True


def main() -> int:
    """Carrega configuracao, valida porta e inicia o servidor local."""
    try:
        configure_logging(DEFAULT_CONFIG)
        config = load_config()
        configure_logging(config)
    except (OSError, RuntimeError) as exc:
        if LOGGER.handlers:
            LOGGER.exception("Falha de configuracao/inicializacao: %s", exc)
        else:
            print("Falha de configuracao/inicializacao: {}".format(exc), file=sys.stderr)
        return 1

    host = config["host"]
    port = config["port"]
    LOGGER.info("Inicializando Astra Mempool Pressure Service")
    LOGGER.info("Python %s; endpoint http://%s:%d", sys.version.split()[0], host, port)
    if not ensure_port_available(host, port):
        LOGGER.error("Inicializacao abortada: porta %d indisponivel.", port)
        return 2

    engine = MempoolPressureEngine(config["refresh_seconds"])
    PressureRequestHandler.engine = engine
    PressureRequestHandler.service_port = port
    PressureRequestHandler.started_at = time.monotonic()
    try:
        server = LocalThreadingHTTPServer((host, port), PressureRequestHandler)
    except OSError:
        LOGGER.exception("Nao foi possivel vincular o servidor a %s:%d", host, port)
        return 3

    engine.start()
    LOGGER.info(
        "Servidor pronto; polling imediato e intervalo de %d segundos.",
        config["refresh_seconds"],
    )
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        LOGGER.info("Interrupcao de console recebida; iniciando shutdown")
    except Exception:
        LOGGER.exception("Falha fatal no servidor HTTP")
        return 4
    finally:
        server.shutdown()
        server.server_close()
        engine.stop()
        LOGGER.info("Shutdown concluido")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())