//+------------------------------------------------------------------+
//| AstraTrader.mq5                                                  |
//| Astra Trader AI                                                  |
//|                                                                  |
//| EA principal.                                                    |
//|                                                                  |
//| RESPONSABILIDADE DESTE ARQUIVO:                                  |
//|  - controlar ciclo de vida do EA                                 |
//|  - resolver símbolo/timeframe                                    |
//|  - inicializar/desinicializar AstraPipeline                      |
//|  - disparar o pipeline                                            |
//|  - controlar timer                                                |
//|  - fornecer diagnóstico básico                                    |
//|  - fornecer telemetria de trade via OnTradeTransaction()         |
//|                                                                  |
//| NÃO É RESPONSABILIDADE DESTE ARQUIVO:                            |
//|  - análise de mercado                                             |
//|  - decisão BUY/SELL                                               |
//|  - cálculo de risco                                               |
//|  - cálculo de lote                                                |
//|  - cálculo de SL/TP                                               |
//|  - execução direta de ordens                                      |
//+------------------------------------------------------------------+
#property copyright "Astra Trader AI"
#property version   "2.200"
#property strict


//==================================================================
// INCLUDES
//==================================================================

#include "..\Include\AstraTrader\Pipeline\AstraPipeline.mqh"
#include "..\Include\AstraTrader\Core\Config.mqh"


//==================================================================
// INPUTS
//==================================================================

input ulong           InpMagicNumber   = ASTRA_DEFAULT_MAGIC;
input ENUM_TIMEFRAMES InpTimeframe     = PERIOD_CURRENT;

input int             InpTimerSeconds  = 1;

input bool            InpProcessOnTick = true;

// Pyramiding: permite novas entradas na mesma direcao ate o limite definido.
// Neste EA, o pyramiding fica ativo por padrao com limite de 2 posicoes.
input bool            InpEnablePyramiding = true;
input int             InpMaxSameDirectionPositions = 2;
input double           InpMaxAggregateRiskPercent = ASTRA_MAX_AGGREGATE_RISK_PERCENT_DEFAULT;
input string           InpDeepModelPath = "";
// Fallback OTC para MT5 e opt-in; false bloqueia se OTC externo falhar.
input bool             InpAllowOtcMt5Fallback = false;


//==================================================================
// ESTADO GLOBAL
//==================================================================

struct AstraRuntimeConfiguration
{
   ulong magicNumber;
   ENUM_TIMEFRAMES requestedTimeframe;
   ENUM_TIMEFRAMES effectiveTimeframe;
   int timerSeconds;
   bool processOnTick;
   bool pyramidingRequested;
   bool pyramidingEffective;
   int maxSameDirectionPositionsRequested;
   int maxSameDirectionPositionsEffective;
   double maxAggregateRiskPercentEffective;
   bool otcMt5FallbackRequested;
   bool otcMt5FallbackEffective;
   bool modelRequested;
   string modelRequestedPath;
   bool modelActive;
   string modelLoadStatus;
   string modelResolvedPath;
   string modelArtifactHash;
   int marketStructureFractalDepth;
   double marketStructureBreakTolerancePoints;
   double marketStructureMinimumScore;
   double minConfidence;
   double minConsensus;
   double minConfluence;
   int maxSpreadPoints;
   double validEvidenceQualityThreshold;
   double neutralEvidenceQualityThreshold;
   int defaultSlippage;
   double defaultRiskPercent;
   double minRiskReward;
   double marginBuffer;
   bool btcModifierEnabled;
   double btcMaxModifier;
   string btcPriceUrl;
   int btcPriceTimeoutMs;
   int btcPriceMaxAgeSeconds;
   string mempoolUrl;
   int mempoolTimeoutMs;
   int mempoolUpdateIntervalSeconds;
   int mempoolStaleMultiplier;
   bool volumeProfileEnabled;
   bool onChainEnabled;
   bool quantEnabled;
};

AstraPipeline g_pipeline;
static AstraRuntimeConfiguration g_runtimeConfiguration;

bool g_initialized = false;

// Proteção contra execução simultânea do pipeline.
// Evita uma segunda chamada enquanto a primeira ainda estiver
// em andamento.
bool g_pipelineRunning = false;


//==================================================================
// RESOLVE TIMEFRAME
//==================================================================

ENUM_TIMEFRAMES ResolveTimeframe()
{
   ENUM_TIMEFRAMES tf = InpTimeframe;

   if(tf == PERIOD_CURRENT)
      tf = (ENUM_TIMEFRAMES)_Period;

   return tf;
}


//==================================================================
// VALIDA TIMEFRAME
//==================================================================

bool IsValidTimeframe(
   const ENUM_TIMEFRAMES tf
)
{
   return (tf != PERIOD_CURRENT);
}


//==================================================================
// VALIDA MAGIC
//==================================================================

bool IsValidMagic(
   const ulong magic
)
{
   return (magic > 0);
}

void CaptureRuntimeConfiguration(
   const ENUM_TIMEFRAMES effectiveTimeframe,
   const int timerSeconds
)
{
   g_runtimeConfiguration.magicNumber = g_pipeline.GetMagicNumber();
   g_runtimeConfiguration.requestedTimeframe = InpTimeframe;
   g_runtimeConfiguration.effectiveTimeframe = effectiveTimeframe;
   g_runtimeConfiguration.timerSeconds = timerSeconds;
   g_runtimeConfiguration.processOnTick = InpProcessOnTick;
   g_runtimeConfiguration.pyramidingRequested = InpEnablePyramiding;
   g_runtimeConfiguration.pyramidingEffective =
      g_pipeline.GetPositionPolicy() == ASTRA_POSITION_POLICY_PYRAMID;
   g_runtimeConfiguration.maxSameDirectionPositionsRequested = InpMaxSameDirectionPositions;
   g_runtimeConfiguration.maxSameDirectionPositionsEffective =
      g_pipeline.GetMaxSameDirectionPositions();
   g_runtimeConfiguration.maxAggregateRiskPercentEffective =
      g_pipeline.GetMaxAggregateRiskPercent();
   g_runtimeConfiguration.otcMt5FallbackRequested =
      InpAllowOtcMt5Fallback;
   g_runtimeConfiguration.otcMt5FallbackEffective =
      g_pipeline.IsOtcMt5FallbackAllowed();

   g_runtimeConfiguration.modelRequested = InpDeepModelPath != "";
   g_runtimeConfiguration.modelRequestedPath = InpDeepModelPath;
   g_runtimeConfiguration.modelActive = g_pipeline.IsPredictionModelActive();
   g_runtimeConfiguration.modelLoadStatus = g_pipeline.GetPredictionModelStatus();
   g_runtimeConfiguration.modelResolvedPath = g_pipeline.GetPredictionModelResolvedPath();
   g_runtimeConfiguration.modelArtifactHash = g_pipeline.GetPredictionModelArtifactHash();

   g_runtimeConfiguration.marketStructureFractalDepth =
      g_pipeline.GetMarketStructureFractalDepth();
   g_runtimeConfiguration.marketStructureBreakTolerancePoints =
      g_pipeline.GetMarketStructureBreakTolerancePoints();
   g_runtimeConfiguration.marketStructureMinimumScore =
      g_pipeline.GetMarketStructureMinimumScore();

   g_runtimeConfiguration.minConfidence = ASTRA_MIN_CONFIDENCE_DEFAULT;
   g_runtimeConfiguration.minConsensus = ASTRA_MIN_CONSENSUS_DEFAULT;
   g_runtimeConfiguration.minConfluence = ASTRA_MIN_CONFLUENCE;
   g_runtimeConfiguration.maxSpreadPoints = ASTRA_MAX_SPREAD_POINTS;
   g_runtimeConfiguration.validEvidenceQualityThreshold = ASTRA_CONFLUENCE_VALID_QUALITY_DEFAULT;
   g_runtimeConfiguration.neutralEvidenceQualityThreshold = ASTRA_CONFLUENCE_NEUTRAL_QUALITY_DEFAULT;
   g_runtimeConfiguration.defaultSlippage = ASTRA_DEFAULT_SLIPPAGE;
   g_runtimeConfiguration.defaultRiskPercent = ASTRA_DEFAULT_RISK_PERCENT;
   g_runtimeConfiguration.minRiskReward = ASTRA_MIN_RISK_REWARD_DEFAULT;
   g_runtimeConfiguration.marginBuffer = ASTRA_DEFAULT_MARGIN_BUFFER;
   g_runtimeConfiguration.btcModifierEnabled = ASTRA_BTC_MODIFIER_ENABLED;
   g_runtimeConfiguration.btcMaxModifier = ASTRA_BTC_MAX_MODIFIER;

   g_runtimeConfiguration.btcPriceUrl = ASTRA_BTC_PRICE_DEFAULT_URL;
   g_runtimeConfiguration.btcPriceTimeoutMs = ASTRA_BTC_PRICE_DEFAULT_TIMEOUT_MS;
   g_runtimeConfiguration.btcPriceMaxAgeSeconds = ASTRA_BTC_PRICE_DEFAULT_MAX_AGE_SEC;
   g_runtimeConfiguration.mempoolUrl = ASTRA_MEMPOOL_DEFAULT_URL;
   g_runtimeConfiguration.mempoolTimeoutMs = ASTRA_MEMPOOL_DEFAULT_TIMEOUT;
   g_runtimeConfiguration.mempoolUpdateIntervalSeconds = ASTRA_MEMPOOL_DEFAULT_INTERVAL;
   g_runtimeConfiguration.mempoolStaleMultiplier = ASTRA_MEMPOOL_STALE_MULTIPLIER;
   g_runtimeConfiguration.volumeProfileEnabled = g_pipeline.IsVolumeProfileEnabled();
   g_runtimeConfiguration.onChainEnabled = g_pipeline.IsOnChainEnabled();
   g_runtimeConfiguration.quantEnabled = g_pipeline.IsQuantEnabled();
}


//==================================================================
// EXECUTA PIPELINE
//
// Único ponto deste EA responsável por chamar Run().
// Isso facilita:
//  - controle de concorrência
//  - diagnóstico
//  - futura telemetria
//==================================================================

bool ExecutePipeline(
   const string caller
)
{
   if(!g_initialized)
      return false;


   if(g_pipelineRunning)
   {
      PrintFormat(
         "[ASTRA][PIPELINE] Execução ignorada por reentrada | Caller=%s",
         caller
      );

      return false;
   }


   g_pipelineRunning = true;

   ResetLastError();


   bool result =
      g_pipeline.Run();


   int error =
      GetLastError();


   g_pipelineRunning = false;


   if(!result)
   {
      static datetime s_lastPipelineErrorLog = 0;

      datetime now =
         TimeCurrent();


      if(
         error != 0 &&
         (
            s_lastPipelineErrorLog == 0 ||
            now - s_lastPipelineErrorLog >= 60
         )
      )
      {
         PrintFormat(
            "[ASTRA][PIPELINE] Run() falhou | "
            "Caller=%s | Error=%d",
            caller,
            error
         );

         s_lastPipelineErrorLog =
            now;
      }


      return false;
   }


   return true;
}


//==================================================================
// ON INIT
//==================================================================

int OnInit()
{
   Print(
      "=================================================="
   );


   PrintFormat(
      "[ASTRA][IDENTITY] VERSION=%s | BUILD=%s",
      ASTRA_VERSION,
      ASTRA_BUILD_ID
   );


   Print(
      "[ASTRA] Inicializando..."
   );


   Print(
      "=================================================="
   );


   //===============================================================
   // SYMBOL
   //===============================================================

   if(_Symbol == "")
   {
      Print(
         "[ASTRA][FATAL] Symbol invalido."
      );

      return INIT_FAILED;
   }


   //===============================================================
   // MAGIC
   //===============================================================

   if(
      !IsValidMagic(
         InpMagicNumber
      )
   )
   {
      PrintFormat(
         "[ASTRA][FATAL] MagicNumber invalido: %I64u",
         InpMagicNumber
      );

      return INIT_FAILED;
   }


   //===============================================================
   // SYMBOL SELECT
   //===============================================================

   ResetLastError();


   if(
      !SymbolSelect(
         _Symbol,
         true
      )
   )
   {
      int error =
         GetLastError();


      PrintFormat(
         "[ASTRA][FATAL] "
         "Nao foi possivel selecionar simbolo %s | Error=%d",
         _Symbol,
         error
      );


      return INIT_FAILED;
   }


   //===============================================================
   // TIMEFRAME
   //===============================================================

   ENUM_TIMEFRAMES tf =
      ResolveTimeframe();


   if(
      !IsValidTimeframe(
         tf
      )
   )
   {
      Print(
         "[ASTRA][FATAL] Timeframe invalido."
      );


      return INIT_FAILED;
   }


   //===============================================================
   // TIMER
   //===============================================================

   int timerSeconds =
      InpTimerSeconds;


   if(timerSeconds < 1)
      timerSeconds = 1;


   //===============================================================
   // RESET DO ESTADO LOCAL
   //===============================================================

   g_initialized =
      false;


   g_pipelineRunning =
      false;


   //===============================================================
   // INICIALIZA ASTRA PIPELINE
   //
   // CONTRATO ESPERADO:
   //
   // Init(symbol, timeframe, magic)
   //===============================================================

   ResetLastError();


   if(
      !g_pipeline.Init(
         _Symbol,
         tf,
         InpMagicNumber,
         InpDeepModelPath
      )
   )
   {
      int error =
         GetLastError();


      PrintFormat(
         "[ASTRA][FATAL] "
         "Falha critica ao inicializar AstraPipeline | Error=%d",
         error
      );


      return INIT_FAILED;
   }


   //===============================================================
   // POSITION POLICY
   //===============================================================

   // Alinha o EA principal com a politica implementada no AstraPipeline.
   // Com pyramiding ativo, novas entradas na mesma direcao sao permitidas
   // ate InpMaxSameDirectionPositions.
   g_pipeline.EnablePyramiding(
      InpEnablePyramiding,
      InpMaxSameDirectionPositions
   );


   g_pipeline.SetMaxAggregateRiskPercent(
      InpMaxAggregateRiskPercent
   );

   g_pipeline.SetAllowOtcMt5Fallback(
      InpAllowOtcMt5Fallback
   );

   CaptureRuntimeConfiguration(tf, timerSeconds);


   //===============================================================
   // TIMER
   //
   // Quando ProcessOnTick=true:
   //   - Timer é auxiliar.
   //
   // Quando ProcessOnTick=false:
   //   - Timer é o único mecanismo de execução.
   //   - Falha é fatal.
   //===============================================================

   ResetLastError();


   if(
      !EventSetTimer(
         timerSeconds
      )
   )
   {
      int error =
         GetLastError();


      //============================================================
      // SEM ONTICK = TIMER É OBRIGATÓRIO
      //============================================================

      if(!InpProcessOnTick)
      {
         PrintFormat(
            "[ASTRA][FATAL] "
            "Falha ao criar timer | "
            "Seconds=%d | "
            "Error=%d | "
            "ProcessOnTick=FALSE",
            timerSeconds,
            error
         );


         // O Pipeline já foi inicializado.
         // Liberamos seus recursos antes de abortar o Init.
         ResetLastError();


         g_pipeline.Deinit();


         int deinitError =
            GetLastError();


         if(deinitError != 0)
         {
            PrintFormat(
               "[ASTRA][WARNING] "
               "Erro durante AstraPipeline.Deinit() "
               "após falha do Timer | Error=%d",
               deinitError
            );
         }


         g_initialized =
            false;


         g_pipelineRunning =
            false;


         return INIT_FAILED;
      }


      //============================================================
      // ONTICK ATIVO = TIMER AUXILIAR
      //============================================================

      PrintFormat(
         "[ASTRA][WARNING] "
         "Falha ao criar timer | "
         "Seconds=%d | "
         "Error=%d | "
         "ProcessOnTick=TRUE",
         timerSeconds,
         error
      );
   }


   //===============================================================
   // ESTADO INICIALIZADO
   //===============================================================

   g_initialized =
      true;


   //===============================================================
   // LOG FINAL
   //===============================================================

   Print("--------------------------------------------------");

   PrintFormat(
      "[ASTRA] Inicializado com sucesso | "
      "Symbol=%s | Magic=%I64u | TF=%s | Timer=%ds",
      _Symbol,
      InpMagicNumber,
      EnumToString(tf),
      timerSeconds
   );

   PrintFormat(
      "[ASTRA] ProcessOnTick=%s",
      InpProcessOnTick
         ? "TRUE"
         : "FALSE"
   );

   PrintFormat(
      "[ASTRA][RUNTIME_CONFIG] Magic=%I64u | RequestedTF=%s | EffectiveTF=%s | TimerSeconds=%d | ProcessOnTick=%s | PyramidingRequested=%s | PyramidingEffective=%s | MaxPositionsRequested=%d | MaxPositionsEffective=%d | MaxAggregateRiskPercent=%.6f | OtcMt5FallbackRequested=%s | OtcMt5FallbackEffective=%s",
      g_runtimeConfiguration.magicNumber,
      EnumToString(g_runtimeConfiguration.requestedTimeframe),
      EnumToString(g_runtimeConfiguration.effectiveTimeframe),
      g_runtimeConfiguration.timerSeconds,
      g_runtimeConfiguration.processOnTick ? "true" : "false",
      g_runtimeConfiguration.pyramidingRequested ? "true" : "false",
      g_runtimeConfiguration.pyramidingEffective ? "true" : "false",
      g_runtimeConfiguration.maxSameDirectionPositionsRequested,
      g_runtimeConfiguration.maxSameDirectionPositionsEffective,
      g_runtimeConfiguration.maxAggregateRiskPercentEffective,
      g_runtimeConfiguration.otcMt5FallbackRequested ? "true" : "false",
      g_runtimeConfiguration.otcMt5FallbackEffective ? "true" : "false"
   );

   PrintFormat(
      "[ASTRA][RUNTIME_CONFIG][STATIC] MinConfidence=%.6f | MinConsensus=%.6f | MinConfluence=%.6f | MaxSpreadPoints=%d | ValidEvidenceQuality=%.6f | NeutralEvidenceQuality=%.6f | Slippage=%d | DefaultRiskPercent=%.6f | MinRiskReward=%.6f | MarginBuffer=%.6f | BTCModifierEnabled=%s | BTCMaxModifier=%.6f",
      g_runtimeConfiguration.minConfidence,
      g_runtimeConfiguration.minConsensus,
      g_runtimeConfiguration.minConfluence,
      g_runtimeConfiguration.maxSpreadPoints,
      g_runtimeConfiguration.validEvidenceQualityThreshold,
      g_runtimeConfiguration.neutralEvidenceQualityThreshold,
      g_runtimeConfiguration.defaultSlippage,
      g_runtimeConfiguration.defaultRiskPercent,
      g_runtimeConfiguration.minRiskReward,
      g_runtimeConfiguration.marginBuffer,
      g_runtimeConfiguration.btcModifierEnabled ? "true" : "false",
      g_runtimeConfiguration.btcMaxModifier
   );

   PrintFormat(
      "[ASTRA][RUNTIME_CONFIG][ENGINES] StructureFractalDepth=%d | StructureBreakTolerancePoints=%.6f | StructureMinimumScore=%.6f | VolumeProfileEnabled=%s | OnChainEnabled=%s | QuantEnabled=%s | BTCUrl=%s | BTCTimeoutMs=%d | BTCMaxAgeSeconds=%d | MempoolUrl=%s | MempoolTimeoutMs=%d | MempoolIntervalSeconds=%d | MempoolStaleMultiplier=%d",
      g_runtimeConfiguration.marketStructureFractalDepth,
      g_runtimeConfiguration.marketStructureBreakTolerancePoints,
      g_runtimeConfiguration.marketStructureMinimumScore,
      g_runtimeConfiguration.volumeProfileEnabled ? "true" : "false",
      g_runtimeConfiguration.onChainEnabled ? "true" : "false",
      g_runtimeConfiguration.quantEnabled ? "true" : "false",
      g_runtimeConfiguration.btcPriceUrl,
      g_runtimeConfiguration.btcPriceTimeoutMs,
      g_runtimeConfiguration.btcPriceMaxAgeSeconds,
      g_runtimeConfiguration.mempoolUrl,
      g_runtimeConfiguration.mempoolTimeoutMs,
      g_runtimeConfiguration.mempoolUpdateIntervalSeconds,
      g_runtimeConfiguration.mempoolStaleMultiplier
   );

   PrintFormat(
      "[ASTRA][RUNTIME_CONFIG][DEEP_MODEL] requested=%s | requested_path=%s | active=%s | load_status=%s | resolved_path=%s | artifact_sha256=%s",
      g_runtimeConfiguration.modelRequested ? "true" : "false",
      g_runtimeConfiguration.modelRequestedPath,
      g_runtimeConfiguration.modelActive ? "true" : "false",
      g_runtimeConfiguration.modelLoadStatus,
      g_runtimeConfiguration.modelResolvedPath,
      g_runtimeConfiguration.modelArtifactHash == "" ? "UNAVAILABLE" : g_runtimeConfiguration.modelArtifactHash
   );

   Print(
      "[ASTRA] Inteligencia de mercado: ATIVA"
   );

   Print(
      "[ASTRA] Pipeline institucional: ATIVO"
   );

   Print(
      "[ASTRA] Trade telemetry: ATIVA"
   );

   Print(
      "--------------------------------------------------"
   );


   return INIT_SUCCEEDED;
}


//==================================================================
// ON DEINIT
//==================================================================

void OnDeinit(
   const int reason
)
{
   //===============================================================
   // PARAR TIMER
   //===============================================================

   EventKillTimer();


   //===============================================================
   // IMPEDIR NOVAS EXECUÇÕES
   //===============================================================

   g_initialized =
      false;


   g_pipelineRunning =
      false;


   //===============================================================
   // DESINICIALIZAR PIPELINE
   //===============================================================

   ResetLastError();


   g_pipeline.Deinit();


   int error =
      GetLastError();


   if(error != 0)
   {
      PrintFormat(
         "[ASTRA][WARNING] "
         "Erro durante AstraPipeline.Deinit() | Error=%d",
         error
      );
   }


   //===============================================================
   // LOG
   //===============================================================

   PrintFormat(
      "[ASTRA] EA finalizado | Reason=%d",
      reason
   );
}


//==================================================================
// ON TICK
//==================================================================

void OnTick()
{
   if(!g_initialized)
      return;


   if(!InpProcessOnTick)
      return;


   ExecutePipeline(
      "OnTick"
   );
}


//==================================================================
// ON TIMER
//==================================================================

void OnTimer()
{
   if(!g_initialized)
      return;


   /*
      Atualmente o Timer é utilizado como mecanismo de disparo
      somente quando o processamento por tick está desativado.

      Isso evita executar o AstraPipeline duas vezes para o mesmo
      ciclo por causa de OnTick + OnTimer.
   */

   if(InpProcessOnTick)
      return;


   ExecutePipeline(
      "OnTimer"
   );
}


//==================================================================
// TELEMETRIA DE TRADE
//
// OBJETIVO:
//   Registrar eventos reais de DEAL_ADD do Astra para permitir:
//
//      ENTRY
//        ↓
//      POSITION_ID
//        ↓
//      EXIT
//        ↓
//      PROFIT
//        ↓
//      ROUND-TRIP
//
// IMPORTANTE:
//   Esta função NÃO executa ordens.
//   Esta função NÃO altera o pipeline.
//   Esta função apenas observa e registra transações confirmadas.
//==================================================================

void OnTradeTransaction(
   const MqlTradeTransaction &trans,
   const MqlTradeRequest &request,
   const MqlTradeResult &result
)
{
   if(!g_initialized)
      return;


   //================================================================
   // SOMENTE DEAL NOVO
   //
   // DEAL_ADD é o evento mais importante para a reconciliação,
   // porque permite localizar:
   //
   //   DEAL_POSITION_ID
   //   DEAL_ORDER
   //   DEAL_PRICE
   //   DEAL_VOLUME
   //   DEAL_PROFIT
   //   DEAL_ENTRY
   //   DEAL_REASON
   //================================================================

   if(
      trans.type !=
      TRADE_TRANSACTION_DEAL_ADD
   )
   {
      return;
   }


   const ulong dealTicket =
      trans.deal;


   if(dealTicket == 0)
      return;


   //================================================================
   // CARREGA DEAL DO HISTÓRICO
   //================================================================

   ResetLastError();


   if(
      !HistoryDealSelect(
         dealTicket
      )
   )
   {
      int error =
         GetLastError();


      PrintFormat(
         "[ASTRA][TRADE_TELEMETRY] "
         "DEAL_HISTORY_SELECT_FAILED | "
         "Deal=%I64u | Error=%d",
         dealTicket,
         error
      );


      return;
   }


   //================================================================
   // CAMPOS PRINCIPAIS
   //================================================================

   const string dealSymbol =
      HistoryDealGetString(
         dealTicket,
         DEAL_SYMBOL
      );


   const long dealMagic =
      HistoryDealGetInteger(
         dealTicket,
         DEAL_MAGIC
      );


   //================================================================
   // FILTRO ASTRA
   //
   // Somente transações do símbolo/magic efetivamente usado pelo EA.
   //================================================================

   if(
      dealSymbol != _Symbol ||
      dealMagic != (long)InpMagicNumber
   )
   {
      return;
   }


   const long dealType =
      HistoryDealGetInteger(
         dealTicket,
         DEAL_TYPE
      );


   //================================================================
   // SOMENTE BUY / SELL
   //
   // Evita registrar depósitos, créditos, ajustes etc.
   //================================================================

   if(
      dealType != DEAL_TYPE_BUY &&
      dealType != DEAL_TYPE_SELL
   )
   {
      return;
   }


   //================================================================
   // DADOS FINANCEIROS / EXECUÇÃO
   //================================================================

   const long positionId =
      HistoryDealGetInteger(
         dealTicket,
         DEAL_POSITION_ID
      );


   const long orderTicket =
      HistoryDealGetInteger(
         dealTicket,
         DEAL_ORDER
      );


   const long dealEntry =
      HistoryDealGetInteger(
         dealTicket,
         DEAL_ENTRY
      );


   const long dealReason =
      HistoryDealGetInteger(
         dealTicket,
         DEAL_REASON
      );


   const long dealTimeMsc =
      HistoryDealGetInteger(
         dealTicket,
         DEAL_TIME_MSC
      );


   const double dealPrice =
      HistoryDealGetDouble(
         dealTicket,
         DEAL_PRICE
      );


   const double dealVolume =
      HistoryDealGetDouble(
         dealTicket,
         DEAL_VOLUME
      );


   const double dealProfit =
      HistoryDealGetDouble(
         dealTicket,
         DEAL_PROFIT
      );


   const double dealSwap =
      HistoryDealGetDouble(
         dealTicket,
         DEAL_SWAP
      );


   const double dealCommission =
      HistoryDealGetDouble(
         dealTicket,
         DEAL_COMMISSION
      );


   const double dealFee =
      HistoryDealGetDouble(
         dealTicket,
         DEAL_FEE
      );


   //================================================================
   // TIPO TEXTUAL
   //================================================================

   string direction =
      "UNKNOWN";


   if(
      dealType ==
      DEAL_TYPE_BUY
   )
   {
      direction =
         "BUY";
   }
   else
   if(
      dealType ==
      DEAL_TYPE_SELL
   )
   {
      direction =
         "SELL";
   }


   //================================================================
   // ENTRADA / SAÍDA
   //================================================================

   string dealEntryText =
      "UNKNOWN";


   if(
      dealEntry ==
      DEAL_ENTRY_IN
   )
   {
      dealEntryText =
         "IN";
   }
   else
   if(
      dealEntry ==
      DEAL_ENTRY_OUT
   )
   {
      dealEntryText =
         "OUT";
   }
   else
   if(
      dealEntry ==
      DEAL_ENTRY_INOUT
   )
   {
      dealEntryText =
         "INOUT";
   }
   else
   if(
      dealEntry ==
      DEAL_ENTRY_OUT_BY
   )
   {
      dealEntryText =
         "OUT_BY";
   }


   //================================================================
   // MOTIVO
   //================================================================

   string reasonText =
      EnumToString(
         (ENUM_DEAL_REASON)dealReason
      );


   //================================================================
   // TIMESTAMP
   //================================================================

   datetime dealTime =
      (datetime)(
         dealTimeMsc / 1000
      );


   string timestamp =
      TimeToString(
         dealTime,
         TIME_DATE | TIME_SECONDS
      );


   //================================================================
   // P/L LÍQUIDO DA OPERAÇÃO
   //
   // Profit + Swap + Commission + Fee
   //================================================================

   double netResult =
      dealProfit;


   if(
      MathIsValidNumber(
         dealSwap
      )
   )
   {
      netResult +=
         dealSwap;
   }


   if(
      MathIsValidNumber(
         dealCommission
      )
   )
   {
      netResult +=
         dealCommission;
   }


   if(
      MathIsValidNumber(
         dealFee
      )
   )
   {
      netResult +=
         dealFee;
   }


   //================================================================
   // LOG CANÔNICO PARA O ANALYZER
   //
   // Este é o ponto principal da alteração.
   //================================================================

   PrintFormat(
      "[ASTRA][TRADE_TELEMETRY] "
      "DEAL_ADD | "
      "Timestamp=%s | "
      "Symbol=%s | "
      "Magic=%I64d | "
      "Deal=%I64u | "
      "Order=%I64d | "
      "PositionID=%I64d | "
      "Direction=%s | "
      "Entry=%s | "
      "Reason=%s | "
      "Volume=%.8f | "
      "Price=%.8f | "
      "Profit=%.2f | "
      "Swap=%.2f | "
      "Commission=%.2f | "
      "Fee=%.2f | "
      "Net=%.2f",
      timestamp,
      dealSymbol,
      dealMagic,
      dealTicket,
      orderTicket,
      positionId,
      direction,
      dealEntryText,
      reasonText,
      dealVolume,
      dealPrice,
      dealProfit,
      dealSwap,
      dealCommission,
      dealFee,
      netResult
   );


   //================================================================
   // DIAGNÓSTICO DE ENTRADA
   //================================================================

   if(
      dealEntry ==
      DEAL_ENTRY_IN
   )
   {
      PrintFormat(
         "[ASTRA][TRADE_TELEMETRY] "
         "ENTRY_CONFIRMED | "
         "Deal=%I64u | "
         "PositionID=%I64d | "
         "Direction=%s | "
         "Volume=%.8f | "
         "Price=%.8f",
         dealTicket,
         positionId,
         direction,
         dealVolume,
         dealPrice
      );
   }


   //================================================================
   // DIAGNÓSTICO DE SAÍDA
   //================================================================

   if(
      dealEntry ==
      DEAL_ENTRY_OUT ||
      dealEntry ==
      DEAL_ENTRY_OUT_BY ||
      dealEntry ==
      DEAL_ENTRY_INOUT
   )
   {
      PrintFormat(
         "[ASTRA][TRADE_TELEMETRY] "
         "EXIT_CONFIRMED | "
         "Deal=%I64u | "
         "PositionID=%I64d | "
         "Direction=%s | "
         "Volume=%.8f | "
         "Price=%.8f | "
         "Profit=%.2f | "
         "Swap=%.2f | "
         "Commission=%.2f | "
         "Fee=%.2f | "
         "Net=%.2f | "
         "Reason=%s",
         dealTicket,
         positionId,
         direction,
         dealVolume,
         dealPrice,
         dealProfit,
         dealSwap,
         dealCommission,
         dealFee,
         netResult,
         reasonText
      );
   }


   //================================================================
   // RETCODE DO EVENTO DE TRADE
   //
   // request/result podem não representar diretamente o deal já
   // confirmado, mas permanecem úteis para diagnóstico.
   //================================================================

   if(
      result.retcode != 0
   )
   {
      PrintFormat(
         "[ASTRA][TRADE_TELEMETRY] "
         "TRANSACTION_RESULT | "
         "Deal=%I64u | "
         "Retcode=%u | "
         "Order=%I64u | "
         "ResultDeal=%I64u",
         dealTicket,
         result.retcode,
         result.order,
         result.deal
      );
   }
}
//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
