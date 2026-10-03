//+------------------------------------------------------------------+
//|                                              AstraTraderAI.mq5   |
//|                                  Copyright Astra Trader AI       |
//|                                            Version 2.00          |
//+------------------------------------------------------------------+
#property copyright "Astra Trader AI"
#property version   "2.200"
#property description "Astra Trader AI - Institutional Engine"

//==================================================================
// INCLUDES
//==================================================================
#include <AstraTrader\Pipeline\AstraPipeline.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\EngineeringAI\EngineeringObserver.mqh>

//==================================================================
// INPUTS
//==================================================================
input ulong           InpMagicNumber   = ASTRA_DEFAULT_MAGIC;
input ENUM_TIMEFRAMES InpTimeframe     = PERIOD_CURRENT;
input int             InpTimerSeconds  = 1;
input bool            InpProcessOnTick = true;

//==================================================================
// ESTADO GLOBAL
//==================================================================
AstraPipeline g_pipeline;
EngineeringObserver g_engineeringObserver;
bool g_initialized = false;
bool g_pipelineRunning = false;

//==================================================================
// FUNÇÕES AUXILIARES
//==================================================================
ENUM_TIMEFRAMES ResolveTimeframe()
{
   return (InpTimeframe == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : InpTimeframe;
}

bool IsValidTimeframe(const ENUM_TIMEFRAMES tf)
{
   return (tf >= PERIOD_M1 && tf <= PERIOD_MN1);
}

bool IsValidMagic(const ulong magic)
{
   return (magic > 0);
}

bool ExecutePipeline(const string caller)
{
   if(!g_initialized) return false;
   
   if(g_pipelineRunning)
   {
      PrintFormat("[ASTRA][PIPELINE] Execução ignorada por reentrada | Caller=%s", caller);
      return false;
   }

   g_pipelineRunning = true;
   ResetLastError();
   
   bool result = g_pipeline.Run();
   int error = GetLastError();

   AnalysisContext *context = g_pipeline.GetContext();
   if(context != NULL)
      g_engineeringObserver.Process(*context);
   
   g_pipelineRunning = false;

   if(!result)
   {
      static datetime s_lastPipelineErrorLog = 0;
      datetime now = TimeCurrent();
      
      if(error != 0 && (s_lastPipelineErrorLog == 0 || (now - s_lastPipelineErrorLog) >= 60))
      {
         PrintFormat("[ASTRA][PIPELINE] Run() falhou | Caller=%s | Error=%d", caller, error);
         s_lastPipelineErrorLog = now;
      }
      return false;
   }
   
   return true;
}

//==================================================================
// EVENT HANDLERS
//==================================================================
int OnInit()
{
   Print("==================================================");
   Print("[ASTRA] Astra Trader AI - Institutional Engine v2.00");
   Print("[ASTRA] Inicializando...");
   Print("==================================================");

   if(_Symbol == "")
   {
      Print("[ASTRA][FATAL] Symbol inválido.");
      return INIT_FAILED;
   }

   if(!IsValidMagic(InpMagicNumber))
   {
      PrintFormat("[ASTRA][FATAL] MagicNumber inválido: %llu", InpMagicNumber);
      return INIT_FAILED;
   }

   ResetLastError();
   if(!SymbolSelect(_Symbol, true))
   {
      PrintFormat("[ASTRA][FATAL] Não foi possível selecionar símbolo %s | Error=%d", _Symbol, GetLastError());
      return INIT_FAILED;
   }

   ENUM_TIMEFRAMES tf = ResolveTimeframe();
   if(!IsValidTimeframe(tf))
   {
      PrintFormat("[ASTRA][FATAL] Timeframe inválido ou não suportado: %s", EnumToString(tf));
      return INIT_FAILED;
   }

   int timerSeconds = (InpTimerSeconds < 1) ? 1 : InpTimerSeconds;
   
   g_initialized = false;
   g_pipelineRunning = false;

   ResetLastError();
   if(!g_pipeline.Init(_Symbol, tf, InpMagicNumber))
   {
      PrintFormat("[ASTRA][FATAL] Falha crítica ao inicializar AstraPipeline | Error=%d", GetLastError());
      return INIT_FAILED;
   }

   ResetLastError();
   if(!EventSetTimer(timerSeconds))
   {
      PrintFormat("[ASTRA][WARNING] Falha ao criar timer | Seconds=%d | Error=%d", timerSeconds, GetLastError());
   }

   g_initialized = true;

   Print("--------------------------------------------------");
   PrintFormat("[ASTRA] Inicializado com sucesso | Symbol=%s | Magic=%llu | TF=%s | Timer=%ds", 
               _Symbol, InpMagicNumber, EnumToString(tf), timerSeconds);
   PrintFormat("[ASTRA] ProcessOnTick=%s", InpProcessOnTick ? "TRUE" : "FALSE");
   Print("[ASTRA] Inteligência de mercado: ATIVA");
   Print("[ASTRA] Pipeline institucional: ATIVO");
   Print("--------------------------------------------------");

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   
   g_initialized = false;
   g_pipelineRunning = false;

   ResetLastError();
   g_pipeline.Deinit();
   
   int error = GetLastError();
   if(error != 0)
   {
      PrintFormat("[ASTRA][WARNING] Erro durante AstraPipeline.Deinit() | Error=%d", error);
   }

   PrintFormat("[ASTRA] EA finalizado | Reason=%d", reason);
}

void OnTick()
{
   if(!g_initialized || !InpProcessOnTick) return;
   ExecutePipeline("OnTick");
}

void OnTimer()
{
   if(!g_initialized || InpProcessOnTick) return;
   ExecutePipeline("OnTimer");
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(!g_initialized) return;

   if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED)
   {
      static datetime s_lastTradeLog = 0;
      datetime now = TimeCurrent();

      if(s_lastTradeLog == 0 || (now - s_lastTradeLog) >= 5)
      {
         PrintFormat("[ASTRA][TRADE] Falha na Transação | Retcode=%u | Order=%llu | Deal=%llu", 
                     result.retcode, (ulong)result.order, (ulong)result.deal);
         s_lastTradeLog = now;
      }
   }
}