//+------------------------------------------------------------------+
//| AstraPipeline.mqh                                                |
//| Astra Trader AI                                                  |
//|                                                                  |
//| PHASE 1: directional decision is validated before Global Bank.  |
//| Global Bank is intentionally deferred to Phase 2.                |
//+------------------------------------------------------------------+
//| ORQUESTRADOR CENTRAL DO PIPELINE                                 |
//|                                                                  |
//| CONTRATO:                                                        |
//|   AnalysisContext = única fonte de verdade                       |
//|                                                                  |
//| FLUXO OPERACIONAL:                                               |
//|                                                                  |
//|   POSITION MANAGEMENT                                             |
//|        -> POSITION GATE INICIAL                                  |
//|        -> MARKET DATA                                            |
//|        -> MEMPOOL CONTEXT                                        |
//|        -> MARKET STRUCTURE                                       |
//|        -> ORDER BLOCK                                             |
//|        -> PATTERN                                                 |
//|        -> VOLATILITY                                              |
//|        -> MOMENTUM                                                |
//|        -> VOLUME PROFILE                                          |
//|        -> TRAFFIC LIGHT                                           |
//|        -> MARKET DECISION                                         |
//|        -> SIGNAL VALIDATOR                                        |
//|        -> RISK MANAGEMENT                                         |
//|        -> POSITION GATE FINAL                                     |
//|        -> EXECUTION POSITION GATE                                 |
//|        -> TRADE VALIDATOR                                         |
//|        -> TRADE EXECUTION                                         |
//|                                                                  |
//| REGRAS:                                                          |
//|   - PositionManager nunca abre novas posições.                   |
//|   - PositionManager tem prioridade sobre o gate de nova entrada. |
//|   - SINGLE_POSITION bloqueia somente nova entrada.               |
//|   - HEDGE_ALLOWED permite direção oposta, bloqueando repetição   |
//|     na mesma direção.                                            |
//|   - Mempool fornece somente contexto analítico.                  |
//+------------------------------------------------------------------+
#ifndef ASTRA_ASTRAPIPELINE_MQH
#define ASTRA_ASTRAPIPELINE_MQH

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>

#include <AstraTrader\Mempool\AstraMempoolIndicator.mqh>
#include <AstraTrader\OnChain\AstraOnChainEngine.mqh>
#include <AstraTrader\Quant\AstraQuantEngine.mqh>

#include <AstraTrader\engines\MarketDataEngine.mqh>
#include <AstraTrader\engines\ExternalDataEngine.mqh>
#include <AstraTrader\engines\MarketStructureEngine.mqh>
#include <AstraTrader\engines\FVGEngine.mqh>
#include <AstraTrader\engines\OrderBlockEngine.mqh>
#include <AstraTrader\Analysis\MarketEvidenceEngine.mqh>
#include <AstraTrader\engines\PatternRecognitionEngine.mqh>
#include <AstraTrader\engines\VolatilityEngine.mqh>
#include <AstraTrader\engines\MomentumEngine.mqh>
#include <AstraTrader\engines\VolumeProfileEngine.mqh>
#include <AstraTrader\engines\TrafficLightEngine.mqh>
#include <AstraTrader\Liquidity\LiquidityEngine.mqh>
#include <AstraTrader\SmartMoney\SmartMoneyEngine.mqh>
#include <AstraTrader\Wyckoff\WyckoffEngine.mqh>
#include <AstraTrader\Strategies\MesaDeSinaisEngine.mqh>
#include <AstraTrader\Prediction\PredictionEngine.mqh>

#include <AstraTrader\Decision\MarketDecisionEngine.mqh>
#include <AstraTrader\Validation\SignalValidator.mqh>
#include <AstraTrader\Risk\RiskManagementEngine.mqh>
#include <AstraTrader\Risk\ExposureGate.mqh>
#include <AstraTrader\Execution\TradeValidator.mqh>
#include <AstraTrader\Execution\TradeExecutionEngine.mqh>
#include <AstraTrader\Execution\PositionManager.mqh>


//==================================================================
// POLÍTICA DE POSIÇÕES
//==================================================================

enum ENUM_ASTRA_POSITION_POLICY
{
   ASTRA_POSITION_POLICY_SINGLE   = 0,
   ASTRA_POSITION_POLICY_HEDGE    = 1,
   ASTRA_POSITION_POLICY_PYRAMID  = 2
};


class AstraPipeline
{
private:

   //=================================================================
   // ESTADO

   //=================================================================
   // COMPARAÇÃO DIAGNÓSTICA DO FVG
   //=================================================================

   void LogFVGComparison(
      const AnalysisContext &c,
      const bool fvgValid,
      const bool fvgBullish,
      const bool fvgBearish,
      const double fvgBullHigh,
      const double fvgBullLow,
      const double fvgBearHigh,
      const double fvgBearLow,
      const double fvgScore,
      const ENUM_LAYER_STATE fvgState,
      const bool orderBlockEngineFvgBullish,
      const bool orderBlockEngineFvgBearish,
      const bool bullishOrderBlockPresent,
      const bool bearishOrderBlockPresent
   ) const
   {
      const bool match =
         fvgBullish == orderBlockEngineFvgBullish &&
         fvgBearish == orderBlockEngineFvgBearish;

      if(match)
      {
         PrintFormat(
            "[FVG_COMPARE] MATCH "
            "Symbol=%s | TF=%s | Cycle=%I64u | "
            "FVGEngineValid=%s | FVGEngineBull=%s | FVGEngineBear=%s | "
            "FVGEngineBounds=%.8f/%.8f/%.8f/%.8f | "
            "FVGEngineScore=%.2f | FVGEngineState=%s | "
            "OrderBlockEngineFVGBull=%s | "
            "OrderBlockEngineFVGBear=%s | "
            "OrderBlockPresentBull=%s | "
            "OrderBlockPresentBear=%s | "
            "fairValueGap=%s",
            c.symbol,
            EnumToString(c.primaryTF),
            c.cycleId,
            fvgValid ? "true" : "false",
            fvgBullish ? "true" : "false",
            fvgBearish ? "true" : "false",
            fvgBullHigh,
            fvgBullLow,
            fvgBearHigh,
            fvgBearLow,
            fvgScore,
            EnumToString(fvgState),
            orderBlockEngineFvgBullish ? "true" : "false",
            orderBlockEngineFvgBearish ? "true" : "false",
            bullishOrderBlockPresent ? "true" : "false",
            bearishOrderBlockPresent ? "true" : "false",
            c.fairValueGap ? "true" : "false"
         );

         return;
      }

      if(ArraySize(c.marketBars) < 4)
      {
         PrintFormat(
            "[FVG_COMPARE] MISMATCH "
            "Symbol=%s | TF=%s | Cycle=%I64u | "
            "FourthBar=unavailable | "
            "FVGEngineValid=%s | FVGEngineBull=%s | "
            "FVGEngineBear=%s | "
            "OrderBlockEngineFVGBull=%s | "
            "OrderBlockEngineFVGBear=%s | "
            "OrderBlockPresentBull=%s | "
            "OrderBlockPresentBear=%s | "
            "Reason=direction_flags_differ",
            c.symbol,
            EnumToString(c.primaryTF),
            c.cycleId,
            fvgValid ? "true" : "false",
            fvgBullish ? "true" : "false",
            fvgBearish ? "true" : "false",
            orderBlockEngineFvgBullish ? "true" : "false",
            orderBlockEngineFvgBearish ? "true" : "false",
            bullishOrderBlockPresent ? "true" : "false",
            bearishOrderBlockPresent ? "true" : "false"
         );

         return;
      }

      PrintFormat(
         "[FVG_COMPARE] MISMATCH "
         "Symbol=%s | TF=%s | Cycle=%I64u | "
         "Bar1Time=%I64d | Bar2Time=%I64d | Bar3Time=%I64d | "
         "Bar1OHLC=%.8f/%.8f/%.8f/%.8f | "
         "Bar2OHLC=%.8f/%.8f/%.8f/%.8f | "
         "Bar3OHLC=%.8f/%.8f/%.8f/%.8f | "
         "FVGEngineValid=%s | FVGEngineBull=%s | FVGEngineBear=%s | "
         "FVGEngineBounds=%.8f/%.8f/%.8f/%.8f | "
         "FVGEngineScore=%.2f | FVGEngineState=%s | "
         "OrderBlockEngineFVGBull=%s | "
         "OrderBlockEngineFVGBear=%s | "
         "OrderBlockPresentBull=%s | "
         "OrderBlockPresentBear=%s | "
         "OrderBlockBounds=unavailable | fairValueGap=%s | "
         "Reason=direction_flags_differ",
         c.symbol,
         EnumToString(c.primaryTF),
         c.cycleId,
         c.marketBars[1].time,
         c.marketBars[2].time,
         c.marketBars[3].time,
         c.marketBars[1].open,
         c.marketBars[1].high,
         c.marketBars[1].low,
         c.marketBars[1].close,
         c.marketBars[2].open,
         c.marketBars[2].high,
         c.marketBars[2].low,
         c.marketBars[2].close,
         c.marketBars[3].open,
         c.marketBars[3].high,
         c.marketBars[3].low,
         c.marketBars[3].close,
         fvgValid ? "true" : "false",
         fvgBullish ? "true" : "false",
         fvgBearish ? "true" : "false",
         fvgBullHigh,
         fvgBullLow,
         fvgBearHigh,
         fvgBearLow,
         fvgScore,
         EnumToString(fvgState),
         orderBlockEngineFvgBullish ? "true" : "false",
         orderBlockEngineFvgBearish ? "true" : "false",
         bullishOrderBlockPresent ? "true" : "false",
         bearishOrderBlockPresent ? "true" : "false",
         c.fairValueGap ? "true" : "false"
      );
   }
   //=================================================================

   bool m_initialized;
   bool m_volumeProfileEnabled;

   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   ulong           m_magicNumber;

   ENUM_ASTRA_POSITION_POLICY m_positionPolicy;
   int m_maxSameDirectionPositions;
   double m_maxAggregateRiskPercent;

   AnalysisContext m_context;


   //=================================================================
   // MEMPOOL
   //=================================================================

   CAstraMempoolIndicator m_mempoolIndicator;


   //=================================================================
   // ON-CHAIN / QUANT (ADITIVOS - NÃO BLOQUEANTES)
   //=================================================================

   AstraOnChainEngine m_onChainEngine;
   AstraQuantEngine   m_quantEngine;

   BitcoinPriceClient m_btcPriceClient;

   bool m_onChainEnabled;
   bool m_quantEnabled;


   //=================================================================
   // ENGINES
   //=================================================================

   MarketDataEngine         m_marketDataEngine;
   ExternalDataEngine       m_externalDataEngine;
   MarketStructureEngine    m_marketStructureEngine;
      MarketEvidenceEngine     m_marketEvidenceEngine;
   FVGEngine                m_fvgEngine;
   OrderBlockEngine         m_orderBlockEngine;
   PatternRecognitionEngine m_patternRecognitionEngine;
   VolatilityEngine         m_volatilityEngine;
   MomentumEngine            m_momentumEngine;
   VolumeProfileEngine      m_volumeProfileEngine;
   TrafficLightEngine       m_trafficLightEngine;
   LiquidityEngine           m_liquidityEngine;
   SmartMoneyEngine          m_smartMoneyEngine;
   WyckoffEngine             m_wyckoffEngine;
   MesaDeSinaisEngine       m_mesaDeSinaisEngine;
   PredictionEngine         m_predictionEngine;

   MarketDecisionEngine     m_marketDecisionEngine;
   SignalValidator          m_signalValidator;
   RiskManagementEngine     m_riskManagementEngine;
   ExposureGate             m_exposureGate;

   TradeValidator           m_tradeValidator;
   TradeExecutionEngine     m_tradeExecutionEngine;
   PositionManager          m_positionManager;


   //=================================================================
   // MAGIC EFETIVO
   //=================================================================

   ulong GetEffectiveMagic(const AnalysisContext &c) const
   {
      if(c.magicNumber > 0)
         return c.magicNumber;

      return (ulong)ASTRA_DEFAULT_MAGIC;
   }


   //=================================================================
   // ATUALIZA CONTEXTO DO BTC PRICE
   //=================================================================

   void UpdateBitcoinPriceContext(AnalysisContext &c)
   {
      const bool fetched =
         m_btcPriceClient.Fetch();

      c.btcPrice =
         m_btcPriceClient.GetData();

      PrintFormat(
         "[ASTRA][Cycle=%I64u][BTC_PRICE] "
         "Valid=%s | Stale=%s | Age=%d | "
         "BTCUSD=%.2f | Timestamp=%I64d",
         c.cycleId,
         c.btcPrice.valid ? "true" : "false",
         c.btcPrice.stale ? "true" : "false",
         c.btcPrice.ageSeconds,
         c.btcPrice.btcUsd,
         c.btcPrice.timestamp
      );

      if(!fetched && c.btcPrice.error != "")
      {
         PrintFormat(
            "[ASTRA][Cycle=%I64u][BTC_PRICE] "
            "Indisponivel | Error=%s | Pipeline continua.",
            c.cycleId,
            c.btcPrice.error
         );
      }
   }


   //=================================================================
   // ATUALIZA CONTEXTO DO MEMPOOL
   //=================================================================

   void UpdateMempoolContext(AnalysisContext &c)
   {
      if(!m_mempoolIndicator.IsInitialized())
      {
         c.mempoolEnabled       = true;
         c.mempoolValid         = false;
         c.mempoolConnected     = false;
         c.mempoolStale         = true;
         c.mempoolAnalysisReady = false;
         c.mempoolPercentileAvailable = false;

         c.mempoolPressureIndex = 0.0;
         c.mempoolAnomalyScore  = 0.0;
         c.mempoolZScore        = 0.0;
         c.mempoolPercentile    = 0.0;
         c.mempoolMomentum      = 0.0;
         c.mempoolAcceleration   = 0.0;
         c.mempoolAgeSeconds     = -1;

         c.mempoolState =
            "UNAVAILABLE";

         c.mempoolApiState =
            "UNAVAILABLE";

         c.mempoolTimestampUTC =
            "";

         c.mempoolError =
            "MEMPOOL_INDICATOR_NOT_INITIALIZED";

         c.mempoolStateLayer =
            LAYER_INVALID;

         PrintFormat(
            "[ASTRA][Cycle=%I64u][MEMPOOL] "
            "Indicator nao inicializado | "
            "Mempool permanece indisponivel.",
            c.cycleId
         );

         return;
      }


      m_mempoolIndicator.OnTimer();

      MempoolPressureData data =
         m_mempoolIndicator.GetData();


      c.mempoolEnabled =
         true;

      c.mempoolValid =
         data.valid;

      c.mempoolConnected =
         m_mempoolIndicator.IsConnected();

      c.mempoolStale =
         m_mempoolIndicator.IsStale();

      c.mempoolAnalysisReady =
         m_mempoolIndicator.IsAnalysisReady();


      c.mempoolPressureIndex =
         data.pressure_index;

      c.mempoolAnomalyScore =
         data.anomaly_score;

      c.mempoolZScore =
         data.zscore;

      c.mempoolPercentile =
         data.percentile;

      c.mempoolPercentileAvailable =
         data.percentile_available;

      c.mempoolMomentum =
         data.momentum;

      c.mempoolAcceleration =
         data.acceleration;

      c.mempoolAgeSeconds =
         m_mempoolIndicator.GetEffectiveAgeSeconds();


      c.mempoolState =
         data.state;

      c.mempoolApiState =
         data.api_state;

      c.mempoolTimestampUTC =
         data.timestamp_utc;

      c.mempoolError =
         data.last_error;


      if(
         c.mempoolValid &&
         c.mempoolConnected &&
         !c.mempoolStale &&
         c.mempoolAnalysisReady
      )
      {
         c.mempoolStateLayer =
            LAYER_VALID;
      }
      else
      {
         c.mempoolStateLayer =
            LAYER_INVALID;
      }


      PrintFormat(
         "[ASTRA][Cycle=%I64u][MEMPOOL] "
         "Valid=%s | Connected=%s | Stale=%s | Ready=%s | "
         "Pressure=%.2f | ApiState=%s | State=%s | Z=%.4f | "
         "PercentileAvailable=%s | Percentile=%.2f | "
         "Momentum=%.6f | Acceleration=%.6f | Age=%d | Layer=%s",
         c.cycleId,
         c.mempoolValid ? "true" : "false",
         c.mempoolConnected ? "true" : "false",
         c.mempoolStale ? "true" : "false",
         c.mempoolAnalysisReady ? "true" : "false",
         c.mempoolPressureIndex,
         c.mempoolApiState,
         c.mempoolState,
         c.mempoolZScore,
         c.mempoolPercentileAvailable ? "true" : "false",
         c.mempoolPercentile,
         c.mempoolMomentum,
         c.mempoolAcceleration,
         c.mempoolAgeSeconds,
         c.LayerStateToString(
            c.mempoolStateLayer
         )
      );


      if(c.mempoolStateLayer == LAYER_INVALID)
      {
         if(StringLen(c.mempoolError) > 0)
         {
            PrintFormat(
               "[ASTRA][Cycle=%I64u][MEMPOOL] "
               "Dados indisponiveis para inteligencia | "
               "Error=%s",
               c.cycleId,
               c.mempoolError
            );
         }
      }
   }


   void UpdateOnChainContext(
      AnalysisContext &c
   )
   {
      c.onChainEnabled =
         m_onChainEnabled;

      c.onChainValid =
         false;

      c.onChainReady =
         false;

      c.onChainAsset =
         "BTC";

      c.onChainStatus =
         "DISABLED";

      c.onChainSource =
         "";

      c.onChainError =
         "";

      c.onChainMempoolTransactions =
         0;

      c.onChainUnconfirmedTransactions =
         0;

      c.onChainLatestBlockHeight =
         0;

      c.onChainBtcPrice =
         0.0;

      c.onChainNetworkHashRate =
         0.0;

      c.onChainNetworkDifficulty =
         0.0;

      c.onChainExchangeNetflow =
         0.0;

      c.onChainRealizedValue =
         0.0;

      c.onChainMarketCap =
         0.0;

      if(!m_onChainEnabled)
         return;

      const bool analyzed =
         m_onChainEngine.Refresh();

      AstraOnChainSnapshot snapshot =
         m_onChainEngine.GetSnapshot();

      c.onChainAsset =
         "BTC";

      c.onChainValid =
         snapshot.status == ASTRA_ONCHAIN_READY;

      c.onChainReady =
         c.onChainValid;

      if(c.onChainValid)
      {
         c.onChainStatus =
            "READY";
      }
      else
      {
         c.onChainStatus =
            "ERROR";
      }

      c.onChainSource =
         "mempool.space";

      c.onChainError =
         snapshot.error;

      if(!analyzed && c.onChainError == "")
      {
         c.onChainError =
            "ONCHAIN_ANALYZE_FAILED";
      }

      c.onChainMempoolTransactions =
         snapshot.mempoolTransactions;

      c.onChainUnconfirmedTransactions =
         0;

      c.onChainLatestBlockHeight =
         snapshot.latestBlockHeight;

      c.onChainBtcPrice =
         snapshot.btcPrice;

      c.onChainNetworkHashRate =
         snapshot.networkHashRate;

      c.onChainNetworkDifficulty =
         snapshot.networkDifficulty;

      c.onChainExchangeNetflow =
         0.0;

      c.onChainRealizedValue =
         0.0;

      c.onChainMarketCap =
         0.0;
   }


   void UpdateQuantContext(
      AnalysisContext &c
   )
   {
      c.quantEnabled =
         m_quantEnabled;

      c.quantValid =
         false;

      c.quantReady =
         false;

      c.quantCorrelation30D =
         0.0;

      c.quantR2 =
         0.0;

      c.quantSlope =
         0.0;

      c.quantZScore =
         0.0;

      c.quantPercentile =
         0.0;

      c.quantVelocity =
         0.0;

      c.quantAcceleration =
         0.0;

      c.quantDivergence =
         0.0;

      c.quantLaggedCorrelation =
         0.0;

      c.quantConfidence =
         0.0;

      c.quantError =
         "";

      c.btcQuantDataValid = false;
      c.btcReturnValid = false;
      c.btcReturn = 0.0;
      c.btcMomentumFast = 0.0;
      c.btcMomentumSlow = 0.0;
      c.btcAcceleration = 0.0;
      c.btcVolatility20 = 0.0;
      c.btcVolatility60 = 0.0;
      c.btcVolatilityRatio = 0.0;
      c.btcZScore = 0.0;
      c.btcZScoreValid = false;
      c.btcZScoreState = "INVALID";
      c.btcZScoreWindow = 20;
      c.btcZScoreMean = 0.0;
      c.btcZScoreStdDev = 0.0;
      c.btcPercentile = 0.0;
      c.btcPercentileValid = false;
      c.btcHistorySize = 0;
      c.btcQuantError = "";

      c.btcXauCorrelationValid = false;
      c.btcXauCorrelation30 = 0.0;
      c.btcXauHistorySize = 0;
      c.btcXauError = "";
      c.btcXauLaggedCorrelationValid = false;
      c.btcXauCorrLag1 = 0.0;
      c.btcXauCorrLag2 = 0.0;
      c.btcXauCorrLag3 = 0.0;
      c.btcXauCorrLag5 = 0.0;
      c.btcXauBestLag = 0;
      c.btcXauBestLagCorrelation = 0.0;
      c.btcXauDivergenceValid = false;
      c.btcXauDivergence = "INVALID";
      c.btcXauDivergenceBtcReturn = 0.0;
      c.btcXauDivergenceXauReturn = 0.0;
      c.btcXauDivergenceBtcThreshold = 0.0;
      c.btcXauDivergenceXauThreshold = 0.0;
      c.btcRegimeValid = false;
      c.btcRegime = "UNAVAILABLE";
      c.btcQuantScoreValid = false;
      c.btcMomentumContribution = 0.0;
      c.btcZScoreContribution = 0.0;
      c.btcAccelerationContribution = 0.0;
      c.btcPercentileContribution = 0.0;
      c.btcCorrelationContribution = 0.0;
      c.btcDivergenceContribution = 0.0;
      c.btcQuantScore = 0.0;
      c.btcModifierActive = false;
      c.btcConfidenceModifier = 0.0;
      c.btcModifierApplied = false;

      if(!m_quantEnabled)
         return;

      AstraQuantResult result;

      if(!m_quantEngine.Calculate(c, result))
      {
         c.quantError =
            result.error;

         return;
      }

      c.quantValid =
         result.valid &&
         result.hasData;

      c.quantReady =
         c.quantValid;

      c.quantCorrelation30D =
         result.correlation30D;

      c.quantR2 =
         result.rSquared;

      c.quantSlope =
         result.slope;

      c.quantZScore =
         result.zScore;

      c.quantPercentile =
         result.percentile;

      c.quantVelocity =
         result.velocity;

      c.quantAcceleration =
         result.acceleration;

      c.quantDivergence =
         result.divergence;

      c.quantLaggedCorrelation =
         result.laggedCorrelation;

      c.quantConfidence =
         result.confidence;

      c.btcQuantDataValid = result.btcQuantDataValid;
      c.btcReturnValid = result.btcReturnValid;
      c.btcReturn = result.btcReturn;
      c.btcMomentumFast = result.btcMomentumFast;
      c.btcMomentumSlow = result.btcMomentumSlow;
      c.btcAcceleration = result.btcAcceleration;
      c.btcVolatility20 = result.btcVolatility20;
      c.btcVolatility60 = result.btcVolatility60;
      c.btcVolatilityRatio = result.btcVolatilityRatio;
      c.btcZScore = result.btcZScore;
      c.btcZScoreValid = result.btcZScoreValid;
      c.btcZScoreState = result.btcZScoreState;
      c.btcZScoreWindow = result.btcZScoreWindow;
      c.btcZScoreMean = result.btcZScoreMean;
      c.btcZScoreStdDev = result.btcZScoreStdDev;
      c.btcPercentile = result.btcPercentile;
      c.btcPercentileValid = result.btcPercentileValid;
      c.btcHistorySize = result.btcHistorySize;
      c.btcQuantError = result.error;
      c.btcXauCorrelationValid = result.btcXauCorrelationValid;
      c.btcXauCorrelation30 = result.btcXauCorrelation30;
      c.btcXauHistorySize = result.btcXauHistorySize;
      c.btcXauError = result.btcXauError;
      c.btcXauLaggedCorrelationValid = result.btcXauLaggedCorrelationValid;
      c.btcXauCorrLag1 = result.btcXauCorrLag1;
      c.btcXauCorrLag2 = result.btcXauCorrLag2;
      c.btcXauCorrLag3 = result.btcXauCorrLag3;
      c.btcXauCorrLag5 = result.btcXauCorrLag5;
      c.btcXauBestLag = result.btcXauBestLag;
      c.btcXauBestLagCorrelation = result.btcXauBestLagCorrelation;
      c.btcXauDivergenceValid = result.btcXauDivergenceValid;
      c.btcXauDivergence = result.btcXauDivergence;
      c.btcXauDivergenceBtcReturn = result.btcXauDivergenceBtcReturn;
      c.btcXauDivergenceXauReturn = result.btcXauDivergenceXauReturn;
      c.btcXauDivergenceBtcThreshold = result.btcXauDivergenceBtcThreshold;
      c.btcXauDivergenceXauThreshold = result.btcXauDivergenceXauThreshold;
      c.btcRegimeValid = result.btcRegimeValid;
      c.btcRegime = result.btcRegime;
      c.btcQuantScoreValid = result.btcQuantScoreValid;
      c.btcMomentumContribution = result.btcMomentumContribution;
      c.btcZScoreContribution = result.btcZScoreContribution;
      c.btcAccelerationContribution = result.btcAccelerationContribution;
      c.btcPercentileContribution = result.btcPercentileContribution;
      c.btcCorrelationContribution = result.btcCorrelationContribution;
      c.btcDivergenceContribution = result.btcDivergenceContribution;
      c.btcQuantScore = result.btcQuantScore;
   }


   //=================================================================
   // DIAGNÓSTICO DETERMINÍSTICO DE POSIÇÕES
   //=================================================================

   bool FindMatchingPosition(
      const string symbol,
      const ulong magic,
      ulong  &matchedTicket,
      string &matchedSymbol,
      long   &matchedMagic,
      long   &matchedType,
      double &matchedVolume,
      double &matchedPrice
   ) const
   {
      matchedTicket = 0;
      matchedSymbol = "";
      matchedMagic  = 0;
      matchedType   = -1;
      matchedVolume = 0.0;
      matchedPrice  = 0.0;


      if(symbol == "" || magic == 0)
         return false;


      const int total =
         PositionsTotal();


      for(int i = 0; i < total; i++)
      {
         const ulong ticket =
            PositionGetTicket(i);


         if(
            ticket == 0 ||
            !PositionSelectByTicket(ticket)
         )
         {
            continue;
         }


         const string positionSymbol =
            PositionGetString(
               POSITION_SYMBOL
            );

         const long positionMagic =
            PositionGetInteger(
               POSITION_MAGIC
            );

         const long positionType =
            PositionGetInteger(
               POSITION_TYPE
            );

         const double positionVolume =
            PositionGetDouble(
               POSITION_VOLUME
            );

         const double positionPrice =
            PositionGetDouble(
               POSITION_PRICE_OPEN
            );


         const bool symbolMatch =
            (positionSymbol == symbol);

         const bool magicMatch =
            (positionMagic == (long)magic);


         PrintFormat(
            "[ASTRA][POSITION_DIAGNOSTIC] "
            "Index=%d | Ticket=%I64u | Symbol=%s | Magic=%I64d | "
            "Type=%s | Volume=%.8f | Price=%.8f | "
            "SymbolMatch=%s | MagicMatch=%s",
            i,
            ticket,
            positionSymbol,
            positionMagic,
            EnumToString(
               (ENUM_POSITION_TYPE)positionType
            ),
            positionVolume,
            positionPrice,
            symbolMatch ? "true" : "false",
            magicMatch ? "true" : "false"
         );


         if(symbolMatch && magicMatch)
         {
            matchedTicket =
               ticket;

            matchedSymbol =
               positionSymbol;

            matchedMagic =
               positionMagic;

            matchedType =
               positionType;

            matchedVolume =
               positionVolume;

            matchedPrice =
               positionPrice;

            return true;
         }
      }


      return false;
   }


   //=================================================================
   // POSIÇÃO ASTRA ABERTA
   //=================================================================

   bool HasOpenPosition(
      const string symbol,
      const ulong magic
   ) const
   {
      ulong matchedTicket = 0;
      string matchedSymbol = "";
      long matchedMagic = 0;
      long matchedType = -1;
      double matchedVolume = 0.0;
      double matchedPrice = 0.0;


      return FindMatchingPosition(
         symbol,
         magic,
         matchedTicket,
         matchedSymbol,
         matchedMagic,
         matchedType,
         matchedVolume,
         matchedPrice
      );
   }


   //=================================================================
   // MESMA DIREÇÃO
   //=================================================================

   int CountSameDirectionPositions(
      const string symbol,
      const ulong magic,
      const ENUM_DECISION decision
   ) const
   {
      if(symbol == "" || magic == 0)
         return 0;

      if(
         decision != DECISION_BUY &&
         decision != DECISION_SELL
      )
      {
         return 0;
      }

      const ENUM_POSITION_TYPE desiredType =
         (
            decision == DECISION_BUY
            ? POSITION_TYPE_BUY
            : POSITION_TYPE_SELL
         );

      int count = 0;
      const int total = PositionsTotal();

      for(int i = 0; i < total; i++)
      {
         const ulong ticket = PositionGetTicket(i);

         if(
            ticket == 0 ||
            !PositionSelectByTicket(ticket)
         )
         {
            continue;
         }

         if(PositionGetString(POSITION_SYMBOL) != symbol)
            continue;

         if(PositionGetInteger(POSITION_MAGIC) != (long)magic)
            continue;

         if(PositionGetInteger(POSITION_TYPE) != (long)desiredType)
            continue;

         count++;
      }

      return count;
   }


   //=================================================================
   // MESMA DIREÇÃO
   //=================================================================

   bool FindSameDirectionPosition(
      const string symbol,
      const ulong magic,
      const ENUM_DECISION decision,
      ulong  &matchedTicket,
      long   &matchedType,
      double &matchedVolume,
      double &matchedPrice
   ) const
   {
      matchedTicket = 0;
      matchedType   = -1;
      matchedVolume = 0.0;
      matchedPrice  = 0.0;


      if(symbol == "" || magic == 0)
         return false;


      if(
         decision != DECISION_BUY &&
         decision != DECISION_SELL
      )
      {
         return false;
      }


      const ENUM_POSITION_TYPE desiredType =
         (
            decision == DECISION_BUY
            ? POSITION_TYPE_BUY
            : POSITION_TYPE_SELL
         );


      const int total =
         PositionsTotal();


      for(int i = 0; i < total; i++)
      {
         const ulong ticket =
            PositionGetTicket(i);


         if(
            ticket == 0 ||
            !PositionSelectByTicket(ticket)
         )
         {
            continue;
         }


         if(
            PositionGetString(
               POSITION_SYMBOL
            ) != symbol
         )
         {
            continue;
         }


         if(
            PositionGetInteger(
               POSITION_MAGIC
            ) != (long)magic
         )
         {
            continue;
         }


         if(
            PositionGetInteger(
               POSITION_TYPE
            ) != (long)desiredType
         )
         {
            continue;
         }


         matchedTicket =
            ticket;

         matchedType =
            PositionGetInteger(
               POSITION_TYPE
            );

         matchedVolume =
            PositionGetDouble(
               POSITION_VOLUME
            );

         matchedPrice =
            PositionGetDouble(
               POSITION_PRICE_OPEN
            );

         return true;
      }


      return false;
   }


   //=================================================================
   // POSITION MANAGEMENT
   //=================================================================

   bool ManageOpenPositions()
   {
      if(!m_initialized)
         return false;


      if(m_context.symbol == "")
         return false;


      if(
         m_context.primaryTF ==
         PERIOD_CURRENT
      )
      {
         return false;
      }


      PrintFormat(
         "[ASTRA][Cycle=%I64u][POSITION_MANAGEMENT] "
         "START | Symbol=%s | TF=%s | Magic=%I64u",
         m_context.cycleId,
         m_context.symbol,
         EnumToString(
            m_context.primaryTF
         ),
         GetEffectiveMagic(
            m_context
         )
      );


      m_positionManager.ManageOpenPositions(
         m_context
      );


      PrintFormat(
         "[ASTRA][Cycle=%I64u][POSITION_MANAGEMENT] "
         "COMPLETE",
         m_context.cycleId
      );


      return true;
   }


   //=================================================================
   // POSITION GATE
   //=================================================================

   bool CheckPositionGate(
      AnalysisContext &c,
      const string stage
   )
   {
      const ulong magic =
         GetEffectiveMagic(c);

      const int positionsTotal =
         PositionsTotal();


      PrintFormat(
         "[ASTRA][Cycle=%I64u][%s][POSITION_POLICY] "
         "Policy=%s | Symbol=%s | Magic=%I64u | "
         "PositionsTotal=%d | Decision=%s",
         c.cycleId,
         stage,
         m_positionPolicy == ASTRA_POSITION_POLICY_HEDGE
         ? "HEDGE_ALLOWED"
         : (m_positionPolicy == ASTRA_POSITION_POLICY_PYRAMID
            ? "PYRAMID_LIMITED"
            : "SINGLE_POSITION"),
         c.symbol,
         magic,
         positionsTotal,
         c.DecisionToString()
      );


      if(
         stage ==
         "POSITION_GATE_INITIAL"
      )
      {
         if(
            m_positionPolicy ==
            ASTRA_POSITION_POLICY_SINGLE
         )
         {
            const bool existingPosition =
               HasOpenPosition(
                  c.symbol,
                  magic
               );

            PrintFormat(
               "[ASTRA][Cycle=%I64u][%s] "
               "ANALYSIS_CONTINUES | Policy=SINGLE_POSITION | "
               "Symbol=%s | Magic=%I64u | ExistingPositionDetected=%s | "
               "NewEntryBlockedAtExecutionOnly=true",
               c.cycleId,
               stage,
               c.symbol,
               magic,
               existingPosition ? "true" : "false"
            );

            return true;
         }
      }


      if(
         m_positionPolicy ==
         ASTRA_POSITION_POLICY_SINGLE
      )
      {
         ulong matchedTicket = 0;
         string matchedSymbol = "";
         long matchedMagic = 0;
         long matchedType = -1;
         double matchedVolume = 0.0;
         double matchedPrice = 0.0;


         const bool matched =
            FindMatchingPosition(
               c.symbol,
               magic,
               matchedTicket,
               matchedSymbol,
               matchedMagic,
               matchedType,
               matchedVolume,
               matchedPrice
            );


         if(!matched)
         {
            PrintFormat(
               "[ASTRA][Cycle=%I64u][%s]"
               "[POSITION_DIAGNOSTIC] "
               "RESULT | MATCH=false | Symbol=%s | Magic=%I64u | "
               "PositionsTotal=%d",
               c.cycleId,
               stage,
               c.symbol,
               magic,
               positionsTotal
            );


            PrintFormat(
               "[ASTRA][Cycle=%I64u][%s] "
               "CLEAR | Policy=SINGLE_POSITION | "
               "Symbol=%s | Magic=%I64u",
               c.cycleId,
               stage,
               c.symbol,
               magic
            );


            return true;
         }


         PrintFormat(
            "[ASTRA][Cycle=%I64u][%s]"
            "[POSITION_DIAGNOSTIC] "
            "RESULT | MATCH=true | Ticket=%I64u | "
            "Symbol=%s | Magic=%I64d | Type=%s | "
            "Volume=%.8f | Price=%.8f",
            c.cycleId,
            stage,
            matchedTicket,
            matchedSymbol,
            matchedMagic,
            EnumToString(
               (ENUM_POSITION_TYPE)matchedType
            ),
            matchedVolume,
            matchedPrice
         );


         Reject(
            c,
            stage,
            "NO_NEW_ENTRY_POSITION",
            ASTRA_BLOCK_POSITION_ALREADY_OPEN
         );


         c.blockDescription =
            "Posicao Astra ja aberta para "
            "symbol/magic; nova entrada bloqueada.";


         PrintFormat(
            "[ASTRA][Cycle=%I64u][%s] "
            "BLOCKED | NO_NEW_ENTRY_POSITION | "
            "Policy=SINGLE_POSITION | Symbol=%s | "
            "Magic=%I64u | Ticket=%I64u | "
            "Volume=%.8f | Price=%.8f",
            c.cycleId,
            stage,
            c.symbol,
            magic,
            matchedTicket,
            matchedVolume,
            matchedPrice
         );


         return false;
      }


      if(m_positionPolicy == ASTRA_POSITION_POLICY_PYRAMID)
      {
         if(stage == "POSITION_GATE_INITIAL")
         {
            PrintFormat(
               "[ASTRA][Cycle=%I64u][%s] "
               "OPEN_FOR_ANALYSIS | Policy=PYRAMID_LIMITED | "
               "MaxSameDirection=%d | ExistingPositions=%d | "
               "DirectionCheck=DEFERRED",
               c.cycleId,
               stage,
               m_maxSameDirectionPositions,
               positionsTotal
            );

            return true;
         }

         if(
            c.decision != DECISION_BUY &&
            c.decision != DECISION_SELL
         )
         {
            Reject(
               c,
               stage,
               "POSITION_POLICY_INVALID_DIRECTION",
               ASTRA_BLOCK_NO_DECISION
            );

            c.blockDescription =
               "PYRAMID_LIMITED requer DECISION_BUY ou DECISION_SELL.";

            return false;
         }

         const int sameDirectionCount =
            CountSameDirectionPositions(
               c.symbol,
               magic,
               c.decision
            );

         if(sameDirectionCount >= m_maxSameDirectionPositions)
         {
            Reject(
               c,
               stage,
               "POSITION_LIMIT_REACHED",
               ASTRA_BLOCK_POSITION_ALREADY_OPEN
            );

            c.blockDescription =
               "PYRAMID_LIMITED: limite de posicoes na mesma direcao atingido.";

            PrintFormat(
               "[ASTRA][Cycle=%I64u][%s] BLOCKED | "
               "POSITION_LIMIT_REACHED | Policy=PYRAMID_LIMITED | "
               "Decision=%s | SameDirection=%d | MaxSameDirection=%d | "
               "Symbol=%s | Magic=%I64u",
               c.cycleId,
               stage,
               c.DecisionToString(),
               sameDirectionCount,
               m_maxSameDirectionPositions,
               c.symbol,
               magic
            );

            return false;
         }

         // Pyramiding permite reforco na mesma direcao, mas nao cria
         // uma segunda direcao oposta. Se existir posicao oposta,
         // o hedge continua bloqueado explicitamente.
         const ENUM_DECISION oppositeDecision =
            (c.decision == DECISION_BUY ? DECISION_SELL : DECISION_BUY);

         ulong oppositeTicket = 0;
         long oppositeType = -1;
         double oppositeVolume = 0.0;
         double oppositePrice = 0.0;

         if(FindSameDirectionPosition(
               c.symbol,
               magic,
               oppositeDecision,
               oppositeTicket,
               oppositeType,
               oppositeVolume,
               oppositePrice
            ))
         {
            Reject(
               c,
               stage,
               "OPPOSITE_POSITION_OPEN",
               ASTRA_BLOCK_POSITION_ALREADY_OPEN
            );

            c.blockDescription =
               "PYRAMID_LIMITED: posicao oposta aberta para symbol/magic.";

            return false;
         }

         PrintFormat(
            "[ASTRA][Cycle=%I64u][%s] CLEAR | "
            "Policy=PYRAMID_LIMITED | Decision=%s | "
            "SameDirection=%d/%d | Symbol=%s | Magic=%I64u",
            c.cycleId,
            stage,
            c.DecisionToString(),
            sameDirectionCount,
            m_maxSameDirectionPositions,
            c.symbol,
            magic
         );

         return true;
      }


      if(stage == "POSITION_GATE_INITIAL")
      {
         PrintFormat(
            "[ASTRA][Cycle=%I64u][%s] "
            "OPEN_FOR_ANALYSIS | Policy=HEDGE_ALLOWED | "
            "ExistingPositions=%d | DirectionCheck=DEFERRED",
            c.cycleId,
            stage,
            positionsTotal
         );


         return true;
      }


      if(
         c.decision != DECISION_BUY &&
         c.decision != DECISION_SELL
      )
      {
         Reject(
            c,
            stage,
            "POSITION_POLICY_INVALID_DIRECTION",
            ASTRA_BLOCK_NO_DECISION
         );


         c.blockDescription =
            "HEDGE_ALLOWED requer DECISION_BUY "
            "ou DECISION_SELL no gate final.";


         PrintFormat(
            "[ASTRA][Cycle=%I64u][%s] "
            "BLOCKED | POSITION_POLICY_INVALID_DIRECTION | "
            "Policy=HEDGE_ALLOWED",
            c.cycleId,
            stage
         );


         return false;
      }


      ulong sameDirectionTicket = 0;
      long sameDirectionType = -1;
      double sameDirectionVolume = 0.0;
      double sameDirectionPrice = 0.0;


      const bool sameDirection =
         FindSameDirectionPosition(
            c.symbol,
            magic,
            c.decision,
            sameDirectionTicket,
            sameDirectionType,
            sameDirectionVolume,
            sameDirectionPrice
         );


      if(sameDirection)
      {
         Reject(
            c,
            stage,
            "NO_NEW_ENTRY_SAME_DIRECTION",
            ASTRA_BLOCK_POSITION_ALREADY_OPEN
         );


         c.blockDescription =
            "HEDGE_ALLOWED: ja existe posicao Astra "
            "na mesma direcao para symbol/magic.";


         PrintFormat(
            "[ASTRA][Cycle=%I64u][%s] "
            "BLOCKED | NO_NEW_ENTRY_SAME_DIRECTION | "
            "Policy=HEDGE_ALLOWED | Decision=%s | Symbol=%s | "
            "Magic=%I64u | Ticket=%I64u | Type=%s | "
            "Volume=%.8f | Price=%.8f",
            c.cycleId,
            stage,
            c.DecisionToString(),
            c.symbol,
            magic,
            sameDirectionTicket,
            EnumToString(
               (ENUM_POSITION_TYPE)sameDirectionType
            ),
            sameDirectionVolume,
            sameDirectionPrice
         );


         return false;
      }


      PrintFormat(
         "[ASTRA][Cycle=%I64u][%s] "
         "CLEAR | Policy=HEDGE_ALLOWED | Decision=%s | "
         "Symbol=%s | Magic=%I64u | OppositeDirectionAllowed=true",
         c.cycleId,
         stage,
         c.DecisionToString(),
         c.symbol,
         magic
      );


      return true;
   }


   //=================================================================
   // REJEIÇÃO CENTRALIZADA
   //=================================================================

   void Reject(
      AnalysisContext &c,
      const string stage,
      const string reason,
      const ENUM_ASTRA_BLOCK_REASON br =
         ASTRA_BLOCK_NO_DECISION
   )
   {
      c.executionAllowed =
         false;

      c.executionConfirmed =
         false;

      c.orderSent =
         false;

      c.tradeValidationPassed =
         false;


      c.pipelineStage =
         stage;

      c.rejectStage =
         stage;

      c.rejectReason =
         reason;


      c.executionRejection =
         reason;

      c.executionMessage =
         reason;


      c.blockReason =
         br;

      c.blockDescription =
         reason;
   }


   //=================================================================
   // LOG
   //=================================================================

   void LogStage(
      const AnalysisContext &c,
      const string stage,
      const string state,
      const string reason = ""
   )
   {
      if(reason == "")
      {
         PrintFormat(
            "[ASTRA][Cycle=%I64u][%s] %s",
            c.cycleId,
            stage,
            state
         );

         return;
      }


      PrintFormat(
         "[ASTRA][Cycle=%I64u][%s] %s | Reason=%s",
         c.cycleId,
         stage,
         state,
         reason
      );
   }


   //=================================================================
   // VALIDA SAÍDA DO RISK
   //=================================================================

   bool ValidateRiskOutput(
      AnalysisContext &c
   )
   {
      if(!c.riskApproved)
         return false;


      if(
         c.decision != DECISION_BUY &&
         c.decision != DECISION_SELL
      )
      {
         return false;
      }


      if(
         c.entryPrice <= 0.0 ||
         c.stopLoss <= 0.0 ||
         c.takeProfit <= 0.0 ||
         c.riskReward <= 0.0 ||
         c.lotSize <= 0.0 ||
         c.riskAmount <= 0.0 ||
         c.riskPercent <= 0.0 ||
         c.riskPercent > 100.0
      )
      {
         return false;
      }


      if(c.decision == DECISION_BUY)
      {
         if(
            c.stopLoss >= c.entryPrice ||
            c.takeProfit <= c.entryPrice
         )
         {
            return false;
         }
      }


      if(c.decision == DECISION_SELL)
      {
         if(
            c.stopLoss <= c.entryPrice ||
            c.takeProfit >= c.entryPrice
         )
         {
            return false;
         }
      }


      return true;
   }


   //=================================================================
   // RESET OPERACIONAL
   //=================================================================

   void ResetExecutionState(
      AnalysisContext &c
   )
   {
      c.executionAllowed =
         false;

      c.tradeValidationPassed =
         false;

      c.executionConfirmed =
         false;

      c.orderSent =
         false;


      c.openedTicket =
         0;

      c.resultRetcode =
         0;

      c.executionPrice =
         0.0;


      c.executionRejection =
         "";

      c.executionMessage =
         "";
   }


public:

   //=================================================================
   // CONSTRUCTOR
   //=================================================================

   AstraPipeline()
   {
      m_initialized =
         false;

      m_volumeProfileEnabled =
         true;

      m_onChainEnabled =
         true;

      m_quantEnabled =
         true;


      m_symbol =
         "";

      m_timeframe =
         PERIOD_CURRENT;


      m_magicNumber =
         (ulong)ASTRA_DEFAULT_MAGIC;


      m_positionPolicy =
         ASTRA_POSITION_POLICY_SINGLE;

      m_maxSameDirectionPositions =
         2;

      m_maxAggregateRiskPercent =
         ASTRA_MAX_AGGREGATE_RISK_PERCENT_DEFAULT;
   }


   //=================================================================
   // INIT
   //=================================================================

   bool Init(
      const string symbol,
      const ENUM_TIMEFRAMES tf,
      const ulong magic,
      const string predictionModelPath = ""
   )
   {
      m_initialized =
         false;


      if(
         symbol == "" ||
         tf == PERIOD_CURRENT
      )
      {
         return false;
      }


      ResetLastError();


      if(!SymbolSelect(symbol, true))
         return false;


      m_symbol =
         symbol;

      m_timeframe =
         tf;

      m_magicNumber =
         magic;


      if(m_magicNumber == 0)
      {
         m_magicNumber =
            (ulong)ASTRA_DEFAULT_MAGIC;
      }


      m_context.Reset();


      m_context.symbol =
         symbol;

      m_context.primaryTF =
         tf;

      m_context.magicNumber =
         m_magicNumber;

      m_context.slippage =
         ASTRA_DEFAULT_SLIPPAGE;

      m_context.volumeProfileEnabled =
         m_volumeProfileEnabled;

      if(!m_predictionEngine.Init(predictionModelPath))
      {
         Print(
            "[AstraPipeline][PREDICTION] Falha ao inicializar. "
            "A camada de IA permanece neutra."
         );
      }

      m_exposureGate.SetMaxAggregateRiskPercent(m_maxAggregateRiskPercent);


      if(!m_mempoolIndicator.Init())
      {
         Print(
            "[AstraPipeline][MEMPOOL] "
            "Falha ao inicializar indicador. "
            "Mempool permanece indisponivel."
         );
      }
      else
      {
         Print(
            "[AstraPipeline][MEMPOOL] "
            "Indicador inicializado."
         );
      }


      //================================================================
      // ON-CHAIN
      //================================================================
      // Inicializacao unica. A coleta ocorre em UpdateOnChainContext().
      // A indisponibilidade do OnChain nunca bloqueia a analise.
      //================================================================
      if(!m_onChainEngine.Init())
      {
         Print(
            "[AstraPipeline][ONCHAIN] "
            "Falha ao inicializar engine. "
            "OnChain permanece indisponivel."
         );
      }
      else
      {
         Print(
            "[AstraPipeline][ONCHAIN] "
            "Engine inicializado."
         );
      }


      //================================================================
      // QUANT
      //================================================================
      // Inicializacao unica. O Quant e complementar e nunca bloqueia
      // o pipeline.
      //================================================================

      if(!m_quantEngine.Init())
      {
         m_quantEnabled =
            false;

         Print(
            "[AstraPipeline][QUANT] "
            "Falha ao inicializar engine. "
            "Quant permanece indisponivel."
         );
      }
      else
      {
         m_quantEnabled =
            true;

         Print(
            "[AstraPipeline][QUANT] "
            "Engine inicializado."
         );
      }


      m_initialized =
         true;


      PrintFormat(
         "[AstraPipeline] Inicializado | "
         "Symbol=%s | TF=%s | Magic=%I64u | "
         "QuantEnabled=%s | OnChainEnabled=%s",
         symbol,
         EnumToString(tf),
         m_magicNumber,
         m_quantEnabled ? "true" : "false",
         m_onChainEnabled ? "true" : "false"
      );


      return true;
   }


   //=================================================================
   // DEINIT
   //=================================================================

   void Deinit()
   {
      m_initialized =
         false;


      m_mempoolIndicator.Shutdown();


      m_symbol =
         "";

      m_timeframe =
         PERIOD_CURRENT;
   }


   //=================================================================
   // ANALYZE
   //=================================================================

   bool Analyze(
      AnalysisContext &c
   )
   {
      if(c.symbol == "")
      {
         Reject(
            c,
            "ANALYSIS",
            "invalid_context",
            ASTRA_BLOCK_INVALID_DATA
         );

         return false;
      }


      if(c.primaryTF == PERIOD_CURRENT)
      {
         Reject(
            c,
            "ANALYSIS",
            "invalid_timeframe",
            ASTRA_BLOCK_INVALID_DATA
         );

         return false;
      }


      if(
         !CheckPositionGate(
            c,
            "POSITION_GATE_INITIAL"
         )
      )
      {
         LogStage(
            c,
            "POSITION_GATE_INITIAL",
            "ANALYSIS_CONTINUES",
            c.rejectReason
         );
      }


      c.pipelineStage =
         "ANALYSIS";


      //================================================================
      // EXTERNAL DATA
      //================================================================

      const bool otcSymbol =
         StringFind(
            c.symbol,
            "OTC"
         ) >= 0;

      bool externalOk =
         false;

      if(otcSymbol)
      {
         externalOk =
            m_externalDataEngine.Process(c);
      }


      //================================================================
      // MARKET DATA
      //================================================================

      if(externalOk)
      {
         if(!c.Validate())
         {
            Reject(
               c,
               "ANALYSIS",
               c.validationMessage == ""
                  ? "external_market_data_invalid"
                  : c.validationMessage,
               ASTRA_BLOCK_INVALID_DATA
            );

            return false;
         }

         PrintFormat(
            "[ASTRA][Cycle=%I64u][MARKET_DATA] "
            "Source=EXTERNAL_OTC | SyntheticCandles=%d",
            c.cycleId,
            c.syntheticMarketBarsCount
         );
      }
      else
      {
         if(otcSymbol)
         {
            PrintFormat(
               "[ASTRA][Cycle=%I64u][MARKET_DATA] "
               "External OTC unavailable/invalid; "
               "explicitly attempting MT5 fallback.",
               c.cycleId
            );
         }

         if(!m_marketDataEngine.Process(c))
         {
            Reject(
               c,
               "ANALYSIS",
               c.validationMessage == ""
                  ? "market_data_failed"
                  : c.validationMessage,
               ASTRA_BLOCK_INVALID_DATA
            );

            return false;
         }

         PrintFormat(
            "[ASTRA][Cycle=%I64u][MARKET_DATA] "
            "Source=MT5%s",
            c.cycleId,
            otcSymbol ? " | FallbackFor=EXTERNAL_OTC" : ""
         );
      }

      if(c.dataQuality == ASTRA_DATA_INVALID)
      {
         Reject(
            c,
            "ANALYSIS",
            "market_data_invalid",
            ASTRA_BLOCK_INVALID_DATA
         );

         return false;
      }


      //================================================================
      // ON-CHAIN / QUANT
      //================================================================

      UpdateBitcoinPriceContext(c);
      UpdateOnChainContext(c);
      UpdateQuantContext(c);


      //================================================================
      // MEMPOOL
      //================================================================

      UpdateMempoolContext(c);


      //================================================================
      // MARKET STRUCTURE
      //================================================================

      if(!m_marketStructureEngine.Analyze(c))
      {
         Reject(
            c,
            "ANALYSIS",
            "market_structure_failed",
            ASTRA_BLOCK_INVALID_DATA
         );

         return false;
      }


      //================================================================
      // LIQUIDITY
      //================================================================

      if(!m_liquidityEngine.Analyze(c))
      {
         PrintFormat(
            "[ASTRA][Cycle=%I64u][LIQUIDITY] Engine indisponivel; continuando.",
            c.cycleId
         );
      }


      //================================================================
      // ORDER BLOCK
      //================================================================

      if(!m_fvgEngine.Update(c))
      {
         PrintFormat(
            "[ASTRA][Cycle=%I64u][FVG] Engine indisponivel; continuando.",
            c.cycleId
         );
      }

      const bool fvgValidBeforeOrderBlock =
         c.fvgValid;

      const bool fvgBullishBeforeOrderBlock =
         m_fvgEngine.IsBullishFVG();

      const bool fvgBearishBeforeOrderBlock =
         m_fvgEngine.IsBearishFVG();

      const double fvgBullHighBeforeOrderBlock =
         c.bullishFVGHigh;

      const double fvgBullLowBeforeOrderBlock =
         c.bullishFVGLow;

      const double fvgBearHighBeforeOrderBlock =
         c.bearishFVGHigh;

      const double fvgBearLowBeforeOrderBlock =
         c.bearishFVGLow;

      const double fvgScoreBeforeOrderBlock =
         c.fvgScore;

      const ENUM_LAYER_STATE fvgStateBeforeOrderBlock =
         c.fvgState;

      if(!m_orderBlockEngine.Analyze(c))
      {
         PrintFormat(
            "[ASTRA][Cycle=%I64u][ORDER_BLOCK] "
            "Engine indisponivel; continuando.",
            c.cycleId
         );
      }

      LogFVGComparison(
         c,
         fvgValidBeforeOrderBlock,
         fvgBullishBeforeOrderBlock,
         fvgBearishBeforeOrderBlock,
         fvgBullHighBeforeOrderBlock,
         fvgBullLowBeforeOrderBlock,
         fvgBearHighBeforeOrderBlock,
         fvgBearLowBeforeOrderBlock,
         fvgScoreBeforeOrderBlock,
         fvgStateBeforeOrderBlock,
         m_orderBlockEngine.HasBullishFVG(),
         m_orderBlockEngine.HasBearishFVG(),
         m_orderBlockEngine.HasBullishOrderBlock(),
         m_orderBlockEngine.HasBearishOrderBlock()
      );


      //================================================================
      // SMART MONEY (CONFIRMATION)
      //================================================================

      if(!m_smartMoneyEngine.Analyze(c))
      {
         PrintFormat(
            "[ASTRA][Cycle=%I64u][SMART_MONEY] Engine indisponivel; continuando.",
            c.cycleId
         );
      }


      //================================================================
      // PATTERN
      //================================================================

      if(!m_patternRecognitionEngine.Analyze(c))
      {
         PrintFormat(
            "[ASTRA][Cycle=%I64u][PATTERN] "
            "Engine sem confirmacao; continuando.",
            c.cycleId
         );
      }


      //================================================================
      // VOLATILITY
      //================================================================

      if(!m_volatilityEngine.Analyze(c))
      {
         Reject(
            c,
            "ANALYSIS",
            "volatility_failed",
            ASTRA_BLOCK_INVALID_DATA
         );

         return false;
      }


      //================================================================
      // MOMENTUM
      //================================================================

      if(!m_momentumEngine.Analyze(c))
      {
         Reject(
            c,
            "ANALYSIS",
            "momentum_failed",
            ASTRA_BLOCK_INVALID_DATA
         );

         return false;
      }


      //================================================================
      // VOLUME PROFILE
      //================================================================

      if(c.volumeProfileEnabled)
      {
         if(!m_volumeProfileEngine.Analyze(c))
         {
            Reject(
               c,
               "ANALYSIS",
               "volume_profile_failed",
               ASTRA_BLOCK_INVALID_DATA
            );

            return false;
         }
      }


      //================================================================
      // TRAFFIC LIGHT
      //================================================================

      if(!m_trafficLightEngine.Analyze(c))
      {
         Reject(
            c,
            "ANALYSIS",

            "traffic_light_failed",
            ASTRA_BLOCK_INVALID_DATA
         );

         return false;
      }


      //================================================================
      // MARKET EVIDENCE
      //================================================================

      // Executa como etapa independente, depois do MTF ser exportado.
      if(!m_marketEvidenceEngine.Analyze(c))
      {
         PrintFormat(
            "[ASTRA][Cycle=%I64u][MARKET_EVIDENCE] Dados insuficientes; continuando.",
            c.cycleId
         );
      }


      //================================================================
      // AI / PREDICTION (EVIDENCE ONLY)
      //================================================================

      if(!m_predictionEngine.Predict(c))
      {
         PrintFormat(
            "[ASTRA][Cycle=%I64u][PREDICTION] Evidencia indisponivel; "
            "decisao continua com as demais camadas.",
            c.cycleId
         );
      }


      //================================================================
      // WYCKOFF
      //================================================================

      if(!m_wyckoffEngine.Analyze(c))
      {
         PrintFormat(
            "[ASTRA][Cycle=%I64u][WYCKOFF] Engine indisponivel; continuando.",
            c.cycleId
         );
      }


      //================================================================
      // MESA DE SINAIS - OBSERVER MODE
      //================================================================

      MesaSignal mesaSignal;
      mesaSignal.Reset();

      if(!m_mesaDeSinaisEngine.Calculate(c, mesaSignal))
      {
         PrintFormat(
            "[MESA][Cycle=%I64u] ObserverMode | Symbol=%s | TF=%s | Valid=false | Reason=%s | Available=%d | Required=%d",
            c.cycleId,
            c.symbol,
            EnumToString(c.primaryTF),
            mesaSignal.reason,
            c.barsAvailable,
            240
         );
      }
      else
      {
         PrintFormat(
            "[MESA][Cycle=%I64u] ObserverMode | Symbol=%s | TF=%s | Valid=true | Direction=%d | CoreScore=%d | State=%s | Reason=%s",
            c.cycleId,
            c.symbol,
            EnumToString(c.primaryTF),
            mesaSignal.direction,
            mesaSignal.coreScore,
            mesaSignal.state,
            mesaSignal.reason
         );
      }

      LogStage(
         c,
         "ANALYSIS",
         "COMPLETE"
      );


      //================================================================
      // MARKET DECISION
      //================================================================

      if(!m_marketDecisionEngine.Analyze(c))
      {
         if(c.rejectReason == "")
         {
            Reject(
               c,
               "MARKET_DECISION",
               "market_decision_failed",
               ASTRA_BLOCK_INVALID_DATA
            );
         }


         LogStage(
            c,
            "MARKET_DECISION",
            "FAILED",
            c.rejectReason
         );


         return false;
      }


      if(c.decision == DECISION_NONE)
      {
         if(c.rejectReason == "")
         {
            Reject(
               c,
               "MARKET_DECISION",
               "NO_OPPORTUNITY",
               ASTRA_BLOCK_NO_DECISION
            );
         }


         LogStage(
            c,
            "MARKET_DECISION",
            "REJECTED",
            c.rejectReason
         );


         return true;
      }


      LogStage(
         c,
         "MARKET_DECISION",
         "APPROVED_FOR_VALIDATION",
         StringFormat(
            "Decision=%s | Confidence=%.3f | "
            "Consensus=%.2f | Confluence=%.2f | Conflict=%s",
            c.DecisionToString(),
            c.finalConfidence,
            c.consensusScore,
            c.confluenceScore,
            c.directionConflict
               ? "true"
               : "false"
         )
      );


      //================================================================
      // SIGNAL VALIDATION
      //================================================================

      if(!m_signalValidator.Validate(c))
      {
         const string reason =
            c.rejectReason == ""
            ? "signal_validation_rejected"
            : c.rejectReason;


         Reject(
            c,
            "SIGNAL_VALIDATION",
            reason,
            ASTRA_BLOCK_NO_DECISION
         );


         LogStage(
            c,
            "SIGNAL_VALIDATION",
            "REJECTED",
            reason
         );


         return true;
      }


      LogStage(
         c,
         "SIGNAL_VALIDATION",
         "APPROVED"
      );


      //================================================================
      // RISK MANAGEMENT
      //================================================================

      if(!m_riskManagementEngine.AnalyzeRisk(c))
      {
         const string reason =
            c.rejectReason == ""
            ? "risk_management_rejected"
            : c.rejectReason;


         Reject(
            c,
            "RISK_MANAGEMENT",
            reason,
            ASTRA_BLOCK_INVALID_RISK
         );


         LogStage(
            c,
            "RISK_MANAGEMENT",
            "REJECTED",
            reason
         );


         return true;
      }


      if(!ValidateRiskOutput(c))
      {
         Reject(
            c,
            "RISK_MANAGEMENT",
            "RISK_OUTPUT_INVALID",
            ASTRA_BLOCK_INVALID_RISK
         );


         LogStage(
            c,
            "RISK_MANAGEMENT",
            "CONTRACT_ERROR",
            c.rejectReason
         );


         return false;
      }


      LogStage(
         c,
         "RISK_MANAGEMENT",
         "APPROVED",
         StringFormat(
            "Entry=%.5f | SL=%.5f | TP=%.5f | "
            "RR=%.3f | Lot=%.8f | Risk=%.3f%%",
            c.entryPrice,
            c.stopLoss,
            c.takeProfit,
            c.riskReward,
            c.lotSize,
            c.riskPercent
         )
      );


      //================================================================
      // AGGREGATE EXPOSURE GATE
      //================================================================

      if(!m_exposureGate.Check(c))
      {
         LogStage(
            c,
            "AGGREGATE_EXPOSURE",
            "REJECTED",
            c.blockDescription
         );

         c.executionAllowed = false;
         c.executionRejection = "AGGREGATE_EXPOSURE_BLOCKED";
         c.rejectStage = "AGGREGATE_EXPOSURE";
         c.rejectReason = c.blockDescription;
         return true;
      }


      LogStage(
         c,
         "AGGREGATE_EXPOSURE",
         "APPROVED",
         StringFormat(
            "Current=%.3f%% | Proposed=%.3f%% | Projected=%.3f%% | Max=%.3f%%",
            c.aggregateCurrentRiskPercent,
            (c.aggregateProposedRiskMoney / MathMax(1.0, c.globalAccountEquity)) * 100.0,
            c.aggregateRiskPercent,
            c.maxAggregateRiskPercent
         )
      );


      //================================================================
      // POSITION GATE FINAL
      //================================================================

      if(
         !CheckPositionGate(
            c,
            "POSITION_GATE_FINAL"
         )
      )
      {
         LogStage(
            c,
            "POSITION_GATE_FINAL",
            "REJECTED",
            c.rejectReason
         );

         return true;
      }


      c.executionAllowed =
         false;

      c.tradeValidationPassed =
         false;

      c.executionConfirmed =
         false;

      c.orderSent =
         false;


      return true;
   }


   //=================================================================
   // RUN
   //=================================================================

   bool Run()
   {
      if(!m_initialized)
         return false;


      m_context.BeginCycle(
         m_symbol,
         m_timeframe
      );


      m_context.magicNumber =
         m_magicNumber;

      m_context.slippage =
         ASTRA_DEFAULT_SLIPPAGE;

      m_context.volumeProfileEnabled =
         m_volumeProfileEnabled;


      ResetExecutionState(
         m_context
      );


      PrintFormat(
         "[ASTRA][Cycle=%I64u] START | "
         "Symbol=%s | TF=%s | Magic=%I64u",
         m_context.cycleId,
         m_symbol,
         EnumToString(m_timeframe),
         m_magicNumber
      );


      //================================================================
      // POSITION MANAGEMENT
      //================================================================

      if(!ManageOpenPositions())
      {
         Reject(
            m_context,
            "POSITION_MANAGEMENT",
            "position_management_context_invalid",
            ASTRA_BLOCK_INVALID_DATA
         );


         LogStage(
            m_context,
            "POSITION_MANAGEMENT",
            "FAILED",
            m_context.rejectReason
         );


         PrintFormat(
            "[ASTRA][Cycle=%I64u] END | "
            "NO_EXECUTION | Stage=%s | Reason=%s",
            m_context.cycleId,
            m_context.rejectStage,
            m_context.rejectReason
         );


         m_context.EndCycle();

         return false;
      }


      //================================================================
      // ANALYZE
      //================================================================

      if(!Analyze(m_context))
      {
         LogStage(
            m_context,
            "PIPELINE",
            "TECHNICAL_FAILURE",
            m_context.rejectReason
         );


         PrintFormat(
            "[ASTRA][Cycle=%I64u] END | "
            "NO_EXECUTION | Stage=%s | Reason=%s",
            m_context.cycleId,
            m_context.rejectStage,
            m_context.rejectReason
         );


         m_context.EndCycle();

         return false;
      }


      //================================================================
      // CURTO-CIRCUITO OPERACIONAL
      //================================================================

      if(
         m_context.decision == DECISION_NONE ||
         m_context.executionRejection != ""
      )
      {
         PrintFormat(
            "[ASTRA][Cycle=%I64u] END | "
            "NO_EXECUTION | Stage=%s | Reason=%s",
            m_context.cycleId,
            m_context.rejectStage,
            m_context.rejectReason
         );


         m_context.EndCycle();

         return true;
      }


      //================================================================
      // EXECUTION POSITION GATE
      //================================================================

      if(
         !CheckPositionGate(
            m_context,
            "EXECUTION_POSITION_GATE"
         )
      )
      {
         LogStage(
            m_context,
            "EXECUTION_POSITION_GATE",
            "REJECTED",
            m_context.rejectReason
         );


         m_context.EndCycle();

         return true;
      }


      //================================================================
      // TRADE VALIDATION
      //================================================================

      if(
         !m_tradeValidator.Validate(
            m_context
         )
      )
      {
         const string reason =
            m_context.rejectReason == ""
            ? "trade_validation_rejected"
            : m_context.rejectReason;


         Reject(
            m_context,
            "TRADE_VALIDATION",
            reason,
            ASTRA_BLOCK_NO_DECISION
         );


         LogStage(
            m_context,
            "TRADE_VALIDATION",
            "REJECTED",
            reason
         );


         m_context.EndCycle();

         return true;
      }


      LogStage(
         m_context,
         "TRADE_VALIDATION",
         "APPROVED"
      );


      if(!m_context.executionAllowed)
      {
         Reject(
            m_context,
            "TRADE_VALIDATION",
            "TRADE_VALIDATOR_APPROVED_WITHOUT_EXECUTION_PERMISSION",
            ASTRA_BLOCK_INVALID_RISK
         );


         m_context.EndCycle();

         return false;
      }


      m_context.tradeValidationPassed =
         true;


      //================================================================
      // TRADE EXECUTION
      //================================================================

      if(
         !m_tradeExecutionEngine.OpenPosition(
            m_context
         )
      )
      {
         LogStage(
            m_context,
            "EXECUTION",
            "FAILED",
            m_context.executionRejection
         );


         m_context.EndCycle();

         return false;
      }


      //================================================================
      // CONFIRMAÇÃO
      //================================================================

      if(!m_context.executionConfirmed)
      {
         LogStage(
            m_context,
            "EXECUTION",
            "CONTRACT_ERROR",
            "EXECUTION_RETURNED_SUCCESS_WITHOUT_CONFIRMATION"
         );


         m_context.EndCycle();

         return false;
      }


      //================================================================
      // EXECUTION CONFIRMED
      //================================================================

      LogStage(
         m_context,
         "EXECUTION",
         "CONFIRMED",
         StringFormat(
            "Ticket=%I64u | Retcode=%I64d | "
            "ExecutionPrice=%.8f",
            m_context.openedTicket,
            m_context.resultRetcode,
            m_context.executionPrice
         )
      );


      m_context.EndCycle();

      return true;
   }


   //=================================================================
   // GETTERS
   //=================================================================

   AnalysisContext *GetContext()
   {
      return GetPointer(
         m_context
      );
   }


   MarketDataEngine *GetMarketDataEngine()
   {
      return GetPointer(
         m_marketDataEngine
      );
   }


   ExternalDataEngine *GetExternalDataEngine()
   {
      return GetPointer(
         m_externalDataEngine
      );
   }


   MarketStructureEngine *GetMarketStructureEngine()
   {
      return GetPointer(
         m_marketStructureEngine
      );
   }

   int GetMarketStructureFractalDepth() const
   {
      return m_marketStructureEngine.GetFractalDepth();
   }

   double GetMarketStructureBreakTolerancePoints() const
   {
      return m_marketStructureEngine.GetBreakTolerancePoints();
   }

   double GetMarketStructureMinimumScore() const
   {
      return m_marketStructureEngine.GetMinimumStructureScore();
   }

   bool IsPredictionModelActive() const
   {
      return m_predictionEngine.IsModelLoaded();
   }

   string GetPredictionModelStatus() const
   {
      return m_predictionEngine.GetStatus();
   }

   string GetPredictionModelRequestedPath() const
   {
      return m_predictionEngine.GetModelPath();
   }

   string GetPredictionModelResolvedPath() const
   {
      return m_predictionEngine.GetResolvedModelPath();
   }

   string GetPredictionModelArtifactHash() const
   {
      return m_predictionEngine.GetModelArtifactHash();
   }


   OrderBlockEngine *GetOrderBlockEngine()
   {
      return GetPointer(
         m_orderBlockEngine
      );
   }


   PatternRecognitionEngine *GetPatternRecognitionEngine()
   {
      return GetPointer(
         m_patternRecognitionEngine
      );
   }


   VolatilityEngine *GetVolatilityEngine()
   {
      return GetPointer(
         m_volatilityEngine
      );
   }


   MomentumEngine *GetMomentumEngine()
   {
      return GetPointer(
         m_momentumEngine
      );
   }


   VolumeProfileEngine *GetVolumeProfileEngine()
   {
      return GetPointer(
         m_volumeProfileEngine
      );
   }


   TrafficLightEngine *GetTrafficLightEngine()
   {
      return GetPointer(
         m_trafficLightEngine
      );
   }


   MarketDecisionEngine *GetMarketDecisionEngine()
   {
      return GetPointer(
         m_marketDecisionEngine
      );
   }


   SignalValidator *GetSignalValidator()
   {
      return GetPointer(
         m_signalValidator
      );
   }


   RiskManagementEngine *GetRiskManagementEngine()
   {
      return GetPointer(
         m_riskManagementEngine
      );
   }


   TradeValidator *GetTradeValidator()
   {
      return GetPointer(
         m_tradeValidator
      );
   }


   TradeExecutionEngine *GetTradeExecutionEngine()
   {
      return GetPointer(
         m_tradeExecutionEngine
      );
   }


   PositionManager *GetPositionManager()
   {
      return GetPointer(
         m_positionManager
      );
   }


   //=================================================================
   // POSITION POLICY
   //=================================================================

   void SetPositionPolicy(
      const ENUM_ASTRA_POSITION_POLICY policy
   )
   {
      m_positionPolicy =
         policy;


      PrintFormat(
         "[AstraPipeline] PositionPolicy=%s",
         m_positionPolicy == ASTRA_POSITION_POLICY_HEDGE
         ? "HEDGE_ALLOWED"
         : (m_positionPolicy == ASTRA_POSITION_POLICY_PYRAMID
            ? "PYRAMID_LIMITED"
            : "SINGLE_POSITION")
      );
   }


   void EnableHedging(
      const bool enabled
   )
   {
      SetPositionPolicy(
         enabled
         ? ASTRA_POSITION_POLICY_HEDGE
         : ASTRA_POSITION_POLICY_SINGLE
      );
   }


   void SetMaxSameDirectionPositions(
      const int maxPositions
   )
   {
      m_maxSameDirectionPositions =
         MathMax(1, maxPositions);

      PrintFormat(
         "[AstraPipeline] MaxSameDirectionPositions=%d",
         m_maxSameDirectionPositions
      );
   }


   void SetMaxAggregateRiskPercent(
      const double maxPercent
   )
   {
      m_maxAggregateRiskPercent = MathMin(100.0, MathMax(0.10, maxPercent));
      m_exposureGate.SetMaxAggregateRiskPercent(m_maxAggregateRiskPercent);

      PrintFormat(
         "[AstraPipeline] MaxAggregateRiskPercent=%.3f",
         m_maxAggregateRiskPercent
      );
   }


   double GetMaxAggregateRiskPercent() const
   {
      return m_maxAggregateRiskPercent;
   }


   int GetMaxSameDirectionPositions() const
   {
      return m_maxSameDirectionPositions;
   }


   void EnablePyramiding(
      const bool enabled,
      const int maxPositions = 2
   )
   {
      if(enabled)
      {
         SetMaxSameDirectionPositions(maxPositions);
         SetPositionPolicy(ASTRA_POSITION_POLICY_PYRAMID);
         return;
      }

      SetPositionPolicy(ASTRA_POSITION_POLICY_SINGLE);
   }


   bool IsHedgingEnabled() const
   {
      return (
         m_positionPolicy ==
         ASTRA_POSITION_POLICY_HEDGE
      );
   }


   ENUM_ASTRA_POSITION_POLICY
   GetPositionPolicy() const
   {
      return m_positionPolicy;
   }


   string GetPositionPolicyString() const
   {
      return
         m_positionPolicy == ASTRA_POSITION_POLICY_HEDGE
         ? "HEDGE_ALLOWED"
         : (m_positionPolicy == ASTRA_POSITION_POLICY_PYRAMID
            ? "PYRAMID_LIMITED"
            : "SINGLE_POSITION");
   }


   //=================================================================
   // CONFIG & STATUS
   //=================================================================

   void SetVolumeProfileEnabled(
      const bool value
   )
   {
      m_volumeProfileEnabled =
         value;
   }

   bool IsVolumeProfileEnabled() const
   {
      return m_volumeProfileEnabled;
   }

   bool IsOnChainEnabled() const
   {
      return m_onChainEnabled;
   }

   bool IsQuantEnabled() const
   {
      return m_quantEnabled;
   }


   bool IsMempoolInitialized()
   {
      return m_mempoolIndicator.IsInitialized();
   }


   bool IsMempoolConnected()
   {
      return m_mempoolIndicator.IsConnected();
   }


   bool IsMempoolStale()
   {
      return m_mempoolIndicator.IsStale();
   }


   bool IsMempoolAnalysisReady()
   {
      return m_mempoolIndicator.IsAnalysisReady();
   }


   CAstraMempoolIndicator *GetMempoolIndicator()
   {
      return GetPointer(
         m_mempoolIndicator
      );
   }


   bool IsInitialized()
   {
      return m_initialized;
   }


   string GetSymbol()
   {
      return m_symbol;
   }


   ENUM_TIMEFRAMES GetTimeframe()
   {
      return m_timeframe;
   }


   ulong GetMagicNumber()
   {
      return m_magicNumber;
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_ASTRAPIPELINE_MQH