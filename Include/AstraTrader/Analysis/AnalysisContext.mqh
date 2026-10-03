//+------------------------------------------------------------------+
//| AnalysisContext.mqh                                              |
//| Astra Trader AI                                                  |
//|                                                                  |
//| CONTRATO CENTRAL DO PIPELINE INSTITUCIONAL                       |
//|                                                                  |
//| AnalysisContext é a única fonte de verdade compartilhada entre  |
//| MarketData, ExternalData, Structure, Liquidity, Pattern,         |
//| Volatility, VolumeProfile, Decision, Risk, Validation e         |
//| Execution.                                                       |
//|                                                                  |
//| CONTRATO TEMPORAL:                                               |
//|   marketBars[0] = candle atual                                   |
//|   marketBars[1] = último candle fechado                          |
//|   marketBars[2] = segundo candle fechado                         |
//|   marketBars[3] = terceiro candle fechado                        |
//|   marketBars[4] = quarto candle fechado                          |
//|                                                                  |
//| REGRA:                                                           |
//|   Somente MarketDataEngine / ExternalDataEngine podem alimentar   |
//|   marketBars[].                                                   |
//+------------------------------------------------------------------+
#ifndef ASTRA_ANALYSISCONTEXT_MQH
#define ASTRA_ANALYSISCONTEXT_MQH

#property strict

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\BTC\BitcoinPriceClient.mqh>


class AnalysisContext
{
private:

   //=================================================================
   // CONTADOR INTERNO DE CICLOS
   //=================================================================

   ulong m_cycleCounter;


public:

   //=================================================================
   // HISTÓRICO CENTRAL
   //=================================================================

   MqlRates marketBars[];

   MqlRates mtfD1[];
   MqlRates mtfH4[];
   MqlRates mtfH1[];
   MqlRates mtfM15[];
   MqlRates mtfM5[];

   bool mtfDataReady;

   MqlRates currentBar;
   MqlRates previousBar;
   MqlRates olderBar;

   int  marketDataBarCount;
   int  marketBarsCount;

   bool marketDataReady;
   bool marketHistoryReady;


   //=================================================================
   // CAMADA 1: MARKET DATA
   //=================================================================

   string              symbol;
   ENUM_TIMEFRAMES     primaryTF;

   datetime            barTime;
   datetime            analysisStartTime;
   datetime            analysisEndTime;

   ulong               cycleId;
   uint                contextVersion;

   double              bid;
   double              ask;
   double              price;

   double              point;
   int                 digits;

   double              tickSize;
   double              tickValue;

   double              spreadPoints;

   long                volume;
   long                tickVolume;

   double              atr;
   double              volatility;
   string              marketDataSource;
   int                 syntheticMarketBarsCount;

   double              high;
   double              low;
   double              open;
   double              close;

   ENUM_ASTRA_DATA_QUALITY dataQuality;


   //=================================================================
   // CAMADA 2: MARKET STRUCTURE
   //=================================================================

   ENUM_BIAS           structuralBias;

   bool                bos;
   bool                choch;

   bool                higherHigh;
   bool                higherLow;
   bool                lowerHigh;
   bool                lowerLow;

   // Magnitude; structuralBias supplies the direction.
   double              structuralScore;

   double              lastSwingHighPrice;
   datetime            lastSwingHighTime;

   double              lastSwingLowPrice;
   datetime            lastSwingLowTime;

   ENUM_LAYER_STATE    structureState;
   // Evidências objetivas derivadas da estrutura e do candle fechado.
   double              nearestSupport;
   double              nearestResistance;
   double              distanceToSupport;
   double              distanceToResistance;
   double              supportStrength;
   double              resistanceStrength;
   ENUM_PRICE_LOCATION priceLocation;
   bool                bullishBreakoutConfirmed;
   bool                bearishBreakoutConfirmed;
   bool                volumeConfirmsTrend;
   bool                volumeDivergesFromTrend;
   double              knowledgeScore;


   //=================================================================
   // CAMADA 3: LIQUIDITY
   //=================================================================

   bool                liquiditySweep;
   bool                liquidityGrab;

   bool                buySideLiquidityTaken;
   bool                sellSideLiquidityTaken;

   // Magnitude only; buySide/sellSideLiquidityTaken supply direction.
   double              liquidityScore;

   double              nearestLiquidityHigh;
   double              nearestLiquidityLow;

   bool                orderBlockValid;
   bool                fvgPresent;

   ENUM_LAYER_STATE    liquidityState;


   //=================================================================
   // CAMADA 4: SMART MONEY / ORDER FLOW
   //=================================================================

   bool                orderBlock;
   bool                breakerBlock;
   bool                mitigation;

   bool                fairValueGap;
   bool                bullishFVG;
   bool                bearishFVG;

   //=================================================================
   // FVG - FAIR VALUE GAP
   //=================================================================

   // Validade do resultado produzido pelo FVGEngine.
   bool                fvgValid;

   // Limites do ultimo FVG bullish detectado.
   double              bullishFVGHigh;
   double              bullishFVGLow;

   // Limites do ultimo FVG bearish detectado.
   double              bearishFVGHigh;
   double              bearishFVGLow;

   // Score direcional: positivo = bullish, negativo = bearish.
   double              fvgScore;

   // Estado da camada FVG.
   ENUM_LAYER_STATE    fvgState;


   // Signed directional score (UpdateDirection exports +/- magnitude).
   double              smartMoneyScore;

   double              orderBlockStrength;
   double              breakerStrength;

   double              absorptionScore;
   double              institutionalFlowScore;

   ENUM_LAYER_STATE    smartMoneyState;


   //=================================================================
   // CAMADA 5: WYCKOFF
   //=================================================================

   ENUM_WYCKOFF_PHASE  wyckoffPhase;

   // Magnitude only; phase/event flags supply direction.
   double              wyckoffScore;
   double              accumulationScore;
   double              distributionScore;

   bool                springDetected;
   bool                upthrustDetected;
   bool                sosDetected;
   bool                sowDetected;

   ENUM_LAYER_STATE    wyckoffState;


   //=================================================================
   // CAMADA 6: ELLIOTT
   //=================================================================

   ENUM_ELLIOTT_WAVE   elliottWave;

   int                 elliottDegree;

   // Magnitude only; no directional field is currently exported.
   // Magnitude only; no directional field is currently exported.
   double              elliottScore;

   bool                waveBDetected;
   bool                waveCDetected;

   bool                complexCorrection;
   bool                waveXDetected;

   double              waveConfidence;

   ENUM_LAYER_STATE    elliottState;


   //=================================================================
   // CAMADA 7: MARKET REGIME
   //=================================================================

   ENUM_REGIME         regime;

   double              regimeScore;
   double              trendStrength;
   double              rangeStrength;

   double              expansionScore;
   double              contractionScore;

   // Compatibilidade com MarketDecisionEngine / VolatilityEngine.
   bool                volatilityExpanding;
   bool                volatilityContracting;

   ENUM_LAYER_STATE    regimeState;


   //=================================================================
   // CAMADA 7.1: VOLATILITY ENGINE
   //=================================================================

   // Valores brutos e derivados produzidos pelo VolatilityEngine.

   double              volatilityValue;
   double              volatilityPercent;
   double              volatilityRatio;

   double              volatilityATR;
   double              volatilityATRPercent;

   double              volatilityExpansionScore;
   double              volatilityContractionScore;

   ENUM_LAYER_STATE    volatilityState;


   //=================================================================
   // CAMADA 8: MULTI-TIMEFRAME
   //=================================================================

   bool                timeframeAligned;

   // Magnitude only; alignedBullish/BearishTFs supply direction.
   double              timeframeScore;

   double              m1Score;
   double              m5Score;
   double              m15Score;
   double              m30Score;

   double              h1Score;
   double              h4Score;
   double              d1Score;
   double              w1Score;
   double              mn1Score;

   int                 alignedBullishTFs;
   int                 alignedBearishTFs;
   int                 neutralTFCount;

   ENUM_LAYER_STATE    timeframeState;
   bool                mtfConflict;
   bool                higherTFConflict;
   double              mtfAlignmentScore;
   ENUM_ASTRA_MTF_STATE mtfCanonicalState;
   ENUM_TRAFFIC_DIRECTION mtfCanonicalDirection;


   //=================================================================
   // CAMADA 9: AI / PREDICTION
   //=================================================================

   // Magnitude only; no directional field is currently exported.
   double              structureAIScore;
   double              structureAIConfidence;

   // Magnitude only; probabilities are contextual until a direction is exported.
   double              predictionScore;

   double              aiProbabilityBuy;
   double              aiProbabilitySell;
   double              aiDeepProbabilityBuy;
   double              aiDeepProbabilitySell;
   bool                aiDeepAvailable;
   double              aiConsensusScore;
   // Telemetry only; native volatilityScore remains the active volatility evidence.
   double              aiVolatilityScore;

   double              probabilityBuy;
   double              probabilitySell;

   // Signed directional adjustment derived from AI consensus: -100..100.
   double              confidenceAdjustment;
   // Reserved until a model contract defines price units and horizon.
   double              expectedMove;

   double              volatilityScore;
   double              predictionConfidence;

   ENUM_LAYER_STATE    aiState;


   //=================================================================
   // CAMADA 9.1: MOMENTUM
   //=================================================================

   double              rsi;

   double              momentumValue;
   // Signed directional score; momentumBullish/momentumBearish are corroboration.
   double              momentumScore;

   double              momentumAcceleration;
   double              momentumAccelerationScore;

   int                 momentumDivergence;

   bool                momentumBullish;
   bool                momentumBearish;

   bool                overbought;
   bool                oversold;

   ENUM_LAYER_STATE    momentumState;


   //=================================================================
   // CAMADA 9.2: PATTERN RECOGNITION
   //=================================================================

   // Signed directional score; bullish/bearishPatternScore are components.
   double              patternScore;

   double              bullishPatternScore;
   double              bearishPatternScore;

   string              primaryPattern;

   bool                bullishPatternDetected;
   bool                bearishPatternDetected;

   bool                dojiDetected;
   bool                hammerDetected;
   bool                invertedHammerDetected;
   bool                shootingStarDetected;
   bool                hangingManDetected;

   bool                bullishEngulfingDetected;
   bool                bearishEngulfingDetected;

   bool                bullishPinBarDetected;
   bool                bearishPinBarDetected;

   bool                insideBarDetected;
   bool                bullishInsideBreakDetected;
   bool                bearishInsideBreakDetected;

   bool                threeWhiteSoldiersDetected;
   bool                threeBlackCrowsDetected;

   bool                morningStarDetected;
   bool                eveningStarDetected;

   ENUM_LAYER_STATE    patternState;


   //=================================================================
   // CAMADA 9.3: VOLUME PROFILE
   //=================================================================

   bool                volumeProfileEnabled;

   // Both are signed directional scores (pressure is their primary direction).
   double              volumeProfileScore;
   double              volumePressure;
   // Canonical directional volume family score used by Decision + Evidence.
   double              volumeDirectionalScore;

   double              volumeImbalance;
   double              volumeConcentration;

   double              volumePOC;
   double              volumeVAL;
   double              volumeVAH;

   double              volumeHVN;
   double              volumeLVN;

   double              volumeInstitutional;
   double              volumeAbsorption;

   // Contratos alternativos usados pelo VolumeProfileEngine.
   double              pointOfControl;
   double              valueAreaHigh;
   double              valueAreaLow;

   double              bullishVolumePressure;
   double              bearishVolumePressure;

   double              nearestHighVolumeNode;
   double              nearestLowVolumeNode;

   bool                priceAbovePOC;
   bool                priceBelowPOC;

   bool                insideValueArea;
   bool                aboveValueArea;
   bool                belowValueArea;

   ENUM_LAYER_STATE    volumeProfileState;


   //=================================================================
   // CAMADA 9.4: TRAFFIC LIGHT
   //=================================================================

   ENUM_TRAFFIC_LIGHT      trafficLight;

   ENUM_TRAFFIC_DIRECTION  trafficDirection;

   ENUM_TRAFFIC_LIGHT      trafficD1;
   ENUM_TRAFFIC_LIGHT      trafficH4;
   ENUM_TRAFFIC_LIGHT      trafficH1;
   ENUM_TRAFFIC_LIGHT      trafficM15;
   ENUM_TRAFFIC_LIGHT      trafficM5;

   double              trafficLightScore;

   double              trafficBullishScore;
   double              trafficBearishScore;

   bool                trafficTrendAligned;
   bool                trafficMomentumAligned;
   bool                trafficMTFAligned;

   ENUM_LAYER_STATE    trafficLightState;


   //=================================================================
   // CAMADA 9.5: TECHNICAL INTELLIGENCE
   //=================================================================

   // Magnitude only; no directional field is currently exported.
   double              technicalIntelligenceScore;

   ENUM_LAYER_STATE    technicalIntelligenceState;


   //=================================================================
   // CAMADA 9.6: ON-CHAIN / QUANT (ADITIVO)
   //=================================================================

   bool                onChainEnabled;
   bool                onChainValid;
   bool                onChainReady;

   string              onChainAsset;
   string              onChainStatus;
   string              onChainSource;
   string              onChainError;

   long                onChainMempoolTransactions;
   long                onChainUnconfirmedTransactions;
   ulong               onChainLatestBlockHeight;

   double              onChainBtcPrice;
   double              onChainNetworkHashRate;
   double              onChainNetworkDifficulty;
   double              onChainExchangeNetflow;
   double              onChainRealizedValue;
   double              onChainMarketCap;

   bool                quantEnabled;
   bool                quantValid;
   bool                quantReady;

   double              quantCorrelation30D;
   double              quantR2;
   double              quantSlope;
   double              quantZScore;
   double              quantPercentile;
   double              quantVelocity;
   double              quantAcceleration;
   double              quantDivergence;
   double              quantLaggedCorrelation;
   double              quantConfidence;

   string              quantError;

   bool                btcQuantDataValid;
   bool                btcReturnValid;
   double              btcReturn;
   double              btcMomentumFast;
   double              btcMomentumSlow;
   double              btcAcceleration;
   double              btcVolatility20;
   double              btcVolatility60;
   double              btcVolatilityRatio;
   double              btcZScore;
   bool                btcZScoreValid;
   string              btcZScoreState;
   int                 btcZScoreWindow;
   double              btcZScoreMean;
   double              btcZScoreStdDev;
   double              btcPercentile;
   bool                btcPercentileValid;
   int                 btcHistorySize;
   string              btcQuantError;
   bool                btcXauCorrelationValid;
   double              btcXauCorrelation30;
   int                 btcXauHistorySize;
   string              btcXauError;
   bool                btcXauLaggedCorrelationValid;
   double              btcXauCorrLag1;
   double              btcXauCorrLag2;
   double              btcXauCorrLag3;
   double              btcXauCorrLag5;
   int                 btcXauBestLag;
   double              btcXauBestLagCorrelation;
   bool                btcXauDivergenceValid;
   string              btcXauDivergence;
   double              btcXauDivergenceBtcReturn;
   double              btcXauDivergenceXauReturn;
   double              btcXauDivergenceBtcThreshold;
   double              btcXauDivergenceXauThreshold;
   bool                btcRegimeValid;
   string              btcRegime;
   bool                btcQuantScoreValid;
   double              btcMomentumContribution;
   double              btcZScoreContribution;
   double              btcAccelerationContribution;
   double              btcPercentileContribution;
   double              btcCorrelationContribution;
   double              btcDivergenceContribution;
   double              btcQuantScore;
   bool                btcModifierActive;
   double              btcConfidenceModifier;
   bool                btcModifierApplied;

   BitcoinPriceContext btcPrice;


   //=================================================================
   // CAMADA 9.7: MEMPOOL
   //=================================================================
   //
   // Dados externos do Astra Mempool Pressure.
   //
   // IMPORTANTE:
   //   O Mempool nesta etapa é SOMENTE DADO DE ANÁLISE.
   //   Não autoriza, bloqueia ou executa ordens diretamente.
   //
   // Contrato:
   //   mempoolPressureIndex = 0..100
   //   mempoolAnomalyScore  = score de anomalia
   //   mempoolZScore        = z-score
   //   mempoolPercentile    = percentil
   //   mempoolMomentum      = momentum da pressão
   //   mempoolAcceleration  = aceleração da pressão
   //
   bool                mempoolEnabled;
   bool                mempoolValid;
   bool                mempoolConnected;
   bool                mempoolStale;
   bool                mempoolAnalysisReady;
   // FIELD_PRESENT/FIELD_MISSING; zero is valid only when present.
   bool                mempoolPercentileAvailable;

   double              mempoolPressureIndex;
   double              mempoolAnomalyScore;
   double              mempoolZScore;
   double              mempoolPercentile;
   double              mempoolMomentum;
   double              mempoolAcceleration;

   int                 mempoolAgeSeconds;

   // API state is retained for trace; mempoolState is normalized internally.
   string              mempoolApiState;
   string              mempoolState;
   string              mempoolTimestampUTC;
   string              mempoolError;

   ENUM_LAYER_STATE    mempoolStateLayer;


   //=================================================================
   // CAMADA 10: CONFLUENCE
   //=================================================================

   double              confluenceScore;

   double              buyScore;
   double              sellScore;

   double              bullishConfluence;
   double              bearishConfluence;

   int                 bullishFactors;
   int                 bearishFactors;

   // Evidence quality metrics.
   // These are intentionally separate from raw Bull/Bear strength.
   double              evidenceStrength;
   double              evidenceCoverage;
   double              evidenceAgreement;
   double              evidenceQuality;
   double              evidenceEligibleWeight;
   double              evidenceActiveWeight;
   double              evidenceAlignedWeight;
   double              evidenceOpposingWeight;

   // Core vs confirmation diagnostics. Confirmation signals are not treated
   // as independent evidence families.
   double              decisionCoreBullScore;
   double              decisionCoreBearScore;
   double              confirmationBullScore;
   double              confirmationBearScore;

   ENUM_LAYER_STATE    confluenceState;


   //=================================================================
   // CAMADA 11: DECISION
   //=================================================================

   ENUM_DECISION       decision;

   double              finalConfidence;

   double              consensusScore;

   string              decisionReason;
   string              decisionExplanation;

   bool                decisionApproved;

   ENUM_OPPORTUNITY_GRADE opportunityGrade;

   bool                directionConflict;
   ENUM_BIAS           decisionBias;

   //=================================================================
   // CAMADA 12: RISK
   //=================================================================

   double              entryPrice;
   double              stopLoss;
   double              takeProfit;

   double              referenceEntryPrice;
   double              executionPrice;

   double              stopDistancePoints;
   double              takeProfitDistance;

   double              riskPercent;
   double              riskAmount;

   double              riskReward;
   double              lotSize;

   double              maxAllowedRisk;

   double              accountEquity;
   double              accountBalance;

   double              marginRequired;
   double              maxAllowedMargin;
   double              marginSafetyBuffer;

   ENUM_RISK_LEVEL     riskLevel;

   bool                riskApproved;

   // Aggregate exposure gate (account-wide positions for Astra Magic).
   bool                aggregateExposureApproved;
   double              aggregateCurrentRiskMoney;
   double              aggregateCurrentRiskPercent;
   double              aggregateProposedRiskMoney;
   double              aggregateRiskMoney;
   double              aggregateRiskPercent;
   double              maxAggregateRiskPercent;
   double              maxAggregateRiskMoney;


   //=================================================================
   // CAMADA 13: EXECUTION
   //=================================================================

   ulong               magicNumber;

   int                 slippage;

   string              orderComment;

   datetime            expiration;

   bool                executionAllowed;

   bool                tradeValidationPassed;

   string              executionRejection;
   string              executionMessage;

   bool                orderSent;
   bool                executionConfirmed;

   ulong               openedTicket;
   long                resultRetcode;


   //=================================================================
   // CONTROLES GLOBAIS
   //=================================================================

   bool                globalTradingAllowed;
   string              globalTradingBlockReason;

   bool                globalBankAuthorized;
   string              globalBankBlockReason;

   double              globalAccountEquity;
   double              globalAccountBalance;
   double              globalDailyNetProfit;
   double              globalPeakEquity;
   double              globalDrawdownPercent;
   double              globalExposureMoney;
   double              globalExposurePercent;
   int                 globalConsecutiveLosses;


   //=================================================================
   // POSITION MANAGER
   //=================================================================

   bool                breakEvenApplied;
   bool                trailingActive;
   bool                partialClosed;

   double              currentPositionPrice;
   double              currentPositionProfit;
   double              currentPositionSL;
   double              currentPositionTP;


   //=================================================================
   // VALIDATION
   //=================================================================

   bool                isValid;

   ENUM_ASTRA_BLOCK_REASON blockReason;

   string              blockDescription;

   bool                spreadValid;
   bool                sessionValid;
   bool                marketOpen;
   bool                symbolValid;
   bool                tradingAllowed;
   bool                marginValid;

   bool                contextValid;
   bool                analysisComplete;

   int                 barsAvailable;

   string              validationMessage;


   //=================================================================
   // PIPELINE TRACE
   //=================================================================

   string              pipelineStage;
   string              rejectStage;
   string              rejectReason;


   //=================================================================
   // CONSTRUCTOR
   //=================================================================

   AnalysisContext()
   {
      m_cycleCounter = 0;
      Reset();
   }


   //=================================================================
   // RESET
   //=================================================================

   void Reset()
   {
      //==============================================================
      // HISTÓRICO CENTRAL
      //==============================================================

      ArrayResize(
         marketBars,
         0
      );

      ArrayResize(
         mtfD1,
         0
      );

      ArrayResize(
         mtfH4,
         0
      );

      ArrayResize(
         mtfH1,
         0
      );

      ArrayResize(
         mtfM15,
         0
      );

      ArrayResize(
         mtfM5,
         0
      );

      mtfDataReady = false;

      ZeroMemory(
         currentBar
      );

      ZeroMemory(
         previousBar
      );

      ZeroMemory(
         olderBar
      );

      marketDataBarCount  = 0;
      marketBarsCount     = 0;
      marketDataReady     = false;
      marketHistoryReady  = false;
      barsAvailable       = 0;


      //==============================================================
      // MARKET DATA
      //==============================================================

      symbol              = _Symbol;
      primaryTF           = PERIOD_CURRENT;

      barTime             = 0;
      analysisStartTime   = 0;
      analysisEndTime     = 0;

      cycleId             = m_cycleCounter;
      contextVersion      = 6;

      bid                 = 0.0;
      ask                 = 0.0;
      price               = 0.0;

      point               = 0.0;
      digits              = 0;

      tickSize            = 0.0;
      tickValue           = 0.0;

      spreadPoints        = 0.0;

      volume              = 0;
      tickVolume          = 0;

      atr                 = 0.0;
      volatility          = 0.0;
      marketDataSource    = "";
      syntheticMarketBarsCount = 0;

      high                = 0.0;
      low                 = 0.0;
      open                = 0.0;
      close               = 0.0;

      dataQuality         = ASTRA_DATA_UNKNOWN;


      //==============================================================
      // MARKET STRUCTURE
      //==============================================================

      structuralBias      = BIAS_NEUTRAL;

      bos                 = false;
      choch               = false;

      higherHigh          = false;
      higherLow           = false;
      lowerHigh           = false;
      lowerLow            = false;

      structuralScore     = 0.0;

      lastSwingHighPrice  = 0.0;
      lastSwingHighTime   = 0;

      lastSwingLowPrice   = 0.0;
      lastSwingLowTime    = 0;

      structureState      = LAYER_NEUTRAL;

      nearestSupport      = 0.0;
      nearestResistance   = 0.0;
      distanceToSupport   = 0.0;
      distanceToResistance = 0.0;
      supportStrength     = 0.0;
      resistanceStrength  = 0.0;
      priceLocation       = PRICE_LOCATION_UNKNOWN;
      bullishBreakoutConfirmed = false;
      bearishBreakoutConfirmed = false;
      volumeConfirmsTrend = false;
      volumeDivergesFromTrend = false;
      knowledgeScore      = 0.0;


      //==============================================================
      // LIQUIDITY
      //==============================================================

      liquiditySweep      = false;
      liquidityGrab       = false;

      buySideLiquidityTaken  = false;
      sellSideLiquidityTaken = false;

      liquidityScore      = 0.0;

      nearestLiquidityHigh = 0.0;
      nearestLiquidityLow  = 0.0;

      orderBlockValid     = false;
      fvgPresent          = false;

      liquidityState      = LAYER_NEUTRAL;


      //==============================================================
      // SMART MONEY
      //==============================================================

      orderBlock          = false;
      breakerBlock        = false;
      mitigation          = false;

      fairValueGap        = false;
      bullishFVG          = false;
      bearishFVG          = false;

      fvgValid            = false;

      bullishFVGHigh      = 0.0;
      bullishFVGLow       = 0.0;

      bearishFVGHigh      = 0.0;
      bearishFVGLow       = 0.0;

      fvgScore            = 0.0;
      fvgState            = LAYER_NEUTRAL;

      smartMoneyScore     = 0.0;

      orderBlockStrength  = 0.0;
      breakerStrength     = 0.0;

      absorptionScore     = 0.0;
      institutionalFlowScore = 0.0;

      smartMoneyState     = LAYER_NEUTRAL;


      //==============================================================
      // WYCKOFF
      //==============================================================

      wyckoffPhase        = WYCKOFF_NONE;

      wyckoffScore        = 0.0;
      accumulationScore   = 0.0;
      distributionScore   = 0.0;

      springDetected      = false;
      upthrustDetected    = false;
      sosDetected         = false;
      sowDetected         = false;

      wyckoffState        = LAYER_NEUTRAL;


      //==============================================================
      // ELLIOTT
      //==============================================================

      elliottWave         = ELLIOTT_NONE;

      elliottDegree       = 0;
      elliottScore        = 0.0;

      waveBDetected       = false;
      waveCDetected       = false;

      complexCorrection   = false;
      waveXDetected       = false;

      waveConfidence      = 0.0;

      elliottState        = LAYER_NEUTRAL;


      //==============================================================
      // MARKET REGIME
      //==============================================================

      regime              = REGIME_RANGE;

      regimeScore         = 0.0;

      trendStrength       = 0.0;
      rangeStrength       = 0.0;

      expansionScore      = 0.0;
      contractionScore    = 0.0;

      volatilityExpanding = false;
      volatilityContracting = false;

      regimeState         = LAYER_NEUTRAL;


      //==============================================================
      // VOLATILITY ENGINE
      //==============================================================

      volatilityValue             = 0.0;
      volatilityPercent           = 0.0;
      volatilityRatio             = 0.0;

      volatilityATR               = 0.0;
      volatilityATRPercent        = 0.0;

      volatilityExpansionScore    = 0.0;
      volatilityContractionScore  = 0.0;

      volatilityState             = LAYER_NEUTRAL;


      //==============================================================
      // MULTI TIMEFRAME
      //==============================================================

      timeframeAligned    = false;
      timeframeScore      = 0.0;

      m1Score             = 0.0;
      m5Score             = 0.0;
      m15Score            = 0.0;
      m30Score            = 0.0;

      h1Score             = 0.0;
      h4Score             = 0.0;
      d1Score             = 0.0;
      w1Score             = 0.0;
      mn1Score            = 0.0;

      alignedBullishTFs   = 0;
      alignedBearishTFs   = 0;
      neutralTFCount      = 0;

      timeframeState      = LAYER_NEUTRAL;

      mtfConflict         = false;
      higherTFConflict    = false;
      mtfAlignmentScore   = 0.0;
      mtfCanonicalState   = ASTRA_MTF_NEUTRAL;
      mtfCanonicalDirection = TRAFFIC_NONE;


      //==============================================================
      // AI / PREDICTION
      //==============================================================

      structureAIScore        = 0.0;
      structureAIConfidence   = 0.0;

      predictionScore         = 0.0;

      aiProbabilityBuy       = 0.50;
      aiProbabilitySell      = 0.50;
      aiDeepProbabilityBuy   = 0.0;
      aiDeepProbabilitySell  = 0.0;
      aiDeepAvailable        = false;
      aiConsensusScore       = 0.0;
      aiVolatilityScore      = 0.0;

      probabilityBuy          = 0.50;
      probabilitySell         = 0.50;

      confidenceAdjustment    = 0.0;
      expectedMove            = 0.0;

      volatilityScore         = 0.0;
      predictionConfidence    = 0.0;

      aiState                 = LAYER_NEUTRAL;


      //==============================================================
      // MOMENTUM
      //==============================================================

      rsi                     = 50.0;

      momentumValue           = 0.0;
      momentumScore           = 0.0;

      momentumAcceleration    = 0.0;
      momentumAccelerationScore = 0.0;

      momentumDivergence      = 0;

      momentumBullish         = false;
      momentumBearish         = false;

      overbought              = false;
      oversold                = false;

      momentumState           = LAYER_NEUTRAL;


      //==============================================================
      // PATTERN RECOGNITION
      //==============================================================

      patternScore                 = 0.0;

      bullishPatternScore          = 0.0;
      bearishPatternScore          = 0.0;

      primaryPattern               = "";

      bullishPatternDetected       = false;
      bearishPatternDetected       = false;

      dojiDetected                 = false;
      hammerDetected               = false;
      invertedHammerDetected       = false;
      shootingStarDetected         = false;
      hangingManDetected           = false;

      bullishEngulfingDetected     = false;
      bearishEngulfingDetected     = false;

      bullishPinBarDetected        = false;
      bearishPinBarDetected        = false;

      insideBarDetected            = false;
      bullishInsideBreakDetected   = false;
      bearishInsideBreakDetected   = false;

      threeWhiteSoldiersDetected   = false;
      threeBlackCrowsDetected      = false;

      morningStarDetected          = false;
      eveningStarDetected          = false;

      patternState                 = LAYER_NEUTRAL;


      //==============================================================
      // VOLUME PROFILE
      //==============================================================

      volumeProfileEnabled     = true;

      volumeProfileScore       = 0.0;
      volumePressure           = 0.0;
      volumeDirectionalScore   = 0.0;

      volumeImbalance          = 0.0;
      volumeConcentration      = 0.0;

      volumePOC                = 0.0;
      volumeVAL                = 0.0;
      volumeVAH                = 0.0;

      volumeHVN                = 0.0;
      volumeLVN                = 0.0;

      volumeInstitutional      = 0.0;
      volumeAbsorption         = 0.0;

      pointOfControl           = 0.0;
      valueAreaHigh            = 0.0;
      valueAreaLow             = 0.0;

      bullishVolumePressure    = 0.0;
      bearishVolumePressure    = 0.0;

      nearestHighVolumeNode    = 0.0;
      nearestLowVolumeNode     = 0.0;

      priceAbovePOC            = false;
      priceBelowPOC            = false;

      insideValueArea          = false;
      aboveValueArea           = false;
      belowValueArea           = false;

      volumeProfileState       = LAYER_NEUTRAL;


      //==============================================================
      // TRAFFIC LIGHT
      //==============================================================

      trafficLight             = TRAFFIC_YELLOW;
      trafficDirection         = TRAFFIC_NONE;

      trafficD1                = TRAFFIC_YELLOW;
      trafficH4                = TRAFFIC_YELLOW;
      trafficH1                = TRAFFIC_YELLOW;
      trafficM15               = TRAFFIC_YELLOW;
      trafficM5                = TRAFFIC_YELLOW;

      trafficLightScore        = 0.0;

      trafficBullishScore      = 0.0;
      trafficBearishScore      = 0.0;

      trafficTrendAligned      = false;
      trafficMomentumAligned   = false;
      trafficMTFAligned        = false;

      trafficLightState        = LAYER_NEUTRAL;


      //==============================================================
      // TECHNICAL INTELLIGENCE
      //==============================================================

      technicalIntelligenceScore =
         0.0;

      technicalIntelligenceState =
         LAYER_NEUTRAL;


      //==============================================================
      // ON-CHAIN / QUANT CONTEXT (ADITIVO, NÃO BLOQUEANTE)
      //==============================================================

      onChainEnabled =
         false;

      onChainValid =
         false;

      onChainReady =
         false;

      onChainAsset =
         "BTC";

      onChainStatus =
         "DISABLED";

      onChainSource =
         "";

      onChainError =
         "";

      onChainMempoolTransactions =
         0;
            btcXauCorrelationValid =
               false;
            btcXauCorrelation30 =
               0.0;
            btcXauHistorySize =
               0;
            btcXauError =
               "";

            btcXauLaggedCorrelationValid = false;
            btcXauCorrLag1 = 0.0;
            btcXauCorrLag2 = 0.0;
            btcXauCorrLag3 = 0.0;
            btcXauCorrLag5 = 0.0;
            btcXauBestLag = 0;
            btcXauBestLagCorrelation = 0.0;
            btcXauDivergenceValid = false;
            btcXauDivergence = "INVALID";
            btcXauDivergenceBtcReturn = 0.0;
            btcXauDivergenceXauReturn = 0.0;
            btcXauDivergenceBtcThreshold = 0.0;
            btcXauDivergenceXauThreshold = 0.0;
            btcRegimeValid = false;
            btcRegime = "UNAVAILABLE";
            btcQuantScoreValid = false;
            btcMomentumContribution = 0.0;
            btcZScoreContribution = 0.0;
            btcAccelerationContribution = 0.0;
            btcPercentileContribution = 0.0;
            btcCorrelationContribution = 0.0;
            btcDivergenceContribution = 0.0;
            btcQuantScore = 0.0;
            btcModifierActive = false;
            btcConfidenceModifier = 0.0;
            btcModifierApplied = false;

      onChainUnconfirmedTransactions =
         0;

      onChainLatestBlockHeight =
         0;

      onChainBtcPrice =
         0.0;

      onChainNetworkHashRate =
         0.0;

      onChainNetworkDifficulty =
         0.0;

      onChainExchangeNetflow =
         0.0;

      onChainRealizedValue =
         0.0;

      onChainMarketCap =
         0.0;

      quantEnabled =
         false;

      quantValid =
         false;

      quantReady =
         false;

      quantCorrelation30D =
         0.0;

      quantR2 =
         0.0;

      quantSlope =
         0.0;

      quantZScore =
         0.0;

      quantPercentile =
         0.0;

      quantVelocity =
         0.0;

      quantAcceleration =
         0.0;

      quantDivergence =
         0.0;

      quantLaggedCorrelation =
         0.0;

      quantConfidence =
         0.0;

      quantError =
         "";

      btcQuantDataValid =
         false;

      btcReturnValid =
         false;

      btcReturn =
         0.0;

      btcMomentumFast =
         0.0;

      btcMomentumSlow =
         0.0;

      btcAcceleration =
         0.0;

      btcVolatility20 =
         0.0;

      btcVolatility60 =
         0.0;

      btcVolatilityRatio =
         0.0;

      btcZScore =
         0.0;

      btcZScoreValid =
         false;

      btcZScoreState =
         "INVALID";

      btcZScoreWindow =
         20;

      btcZScoreMean =
         0.0;

      btcZScoreStdDev =
         0.0;

      btcPercentile =
         0.0;

      btcPercentileValid =
         false;

      btcHistorySize =
         0;

      btcQuantError =
         "";

      btcPrice.Reset();


      //==============================================================
      // MEMPOOL
      //==============================================================

      mempoolEnabled =
         false;

      mempoolValid =
         false;

      mempoolConnected =
         false;

      mempoolStale =
         true;

      mempoolAnalysisReady =
         false;

      mempoolPercentileAvailable =
         false;

      mempoolPressureIndex =
         0.0;

      mempoolAnomalyScore =
         0.0;

      mempoolZScore =
         0.0;

      mempoolPercentile =
         0.0;

      mempoolMomentum =
         0.0;

      mempoolAcceleration =
         0.0;

      mempoolAgeSeconds =
         -1;

      mempoolState =
         "UNAVAILABLE";

      mempoolApiState =
         "UNAVAILABLE";

      mempoolTimestampUTC =
         "";

      mempoolError =
         "";

      mempoolStateLayer =
         LAYER_INVALID;


      //==============================================================
      // CONFLUENCE
      //==============================================================

      confluenceScore       = 0.0;

      buyScore              = 0.0;
      sellScore             = 0.0;

      bullishConfluence     = 0.0;
      bearishConfluence     = 0.0;

      bullishFactors        = 0;
      bearishFactors        = 0;

      evidenceStrength          = 0.0;
      evidenceCoverage         = 0.0;
      evidenceAgreement        = 0.0;
      evidenceQuality          = 0.0;
      evidenceEligibleWeight   = 0.0;
      evidenceActiveWeight     = 0.0;
      evidenceAlignedWeight    = 0.0;
      evidenceOpposingWeight   = 0.0;

      decisionCoreBullScore     = 0.0;
      decisionCoreBearScore     = 0.0;
      confirmationBullScore     = 0.0;
      confirmationBearScore     = 0.0;

      confluenceState       = LAYER_NEUTRAL;


      //==============================================================
      // DECISION
      //==============================================================

      decision              = DECISION_NONE;

      finalConfidence       = 0.0;

      consensusScore        = 0.0;

      decisionReason        = "";
      decisionExplanation   = "";

      decisionApproved      = false;

      opportunityGrade     = GRADE_NO_TRADE;

      directionConflict     = false;
      decisionBias          = BIAS_NEUTRAL;


      //==============================================================
      // RISK
      //==============================================================

      entryPrice             = 0.0;
      stopLoss               = 0.0;
      takeProfit             = 0.0;

      referenceEntryPrice    = 0.0;
      executionPrice         = 0.0;

      stopDistancePoints     = 0.0;
      takeProfitDistance     = 0.0;

      riskPercent            = 0.0;
      riskAmount             = 0.0;

      riskReward             = 0.0;
      lotSize                = 0.0;

      maxAllowedRisk         = 0.0;

      accountEquity          = 0.0;
      accountBalance         = 0.0;

      marginRequired         = 0.0;
      maxAllowedMargin       = 0.0;

      marginSafetyBuffer     =
         ASTRA_DEFAULT_MARGIN_BUFFER;

      riskLevel              = RISK_LOW;

      riskApproved           = false;

      aggregateExposureApproved = false;
      aggregateCurrentRiskMoney = 0.0;
      aggregateCurrentRiskPercent = 0.0;
      aggregateProposedRiskMoney = 0.0;
      aggregateRiskMoney = 0.0;
      aggregateRiskPercent = 0.0;
      maxAggregateRiskPercent = 0.0;
      maxAggregateRiskMoney = 0.0;


      //==============================================================
      // EXECUTION
      //==============================================================

      magicNumber            = ASTRA_DEFAULT_MAGIC;
      slippage               = ASTRA_DEFAULT_SLIPPAGE;

      orderComment           = "ASTRA";

      expiration             = 0;

      executionAllowed       = false;
      tradeValidationPassed  = false;

      executionRejection     = "";
      executionMessage       = "";

      orderSent              = false;
      executionConfirmed     = false;

      openedTicket            = 0;
      resultRetcode           = 0;


      //==============================================================
      // CONTROLES GLOBAIS
      //==============================================================

      globalTradingAllowed   = false;
      globalTradingBlockReason = "";

      globalBankAuthorized   = false;
      globalBankBlockReason  = "";

      globalAccountEquity    = 0.0;
      globalAccountBalance   = 0.0;
      globalDailyNetProfit   = 0.0;
      globalPeakEquity       = 0.0;
      globalDrawdownPercent  = 0.0;
      globalExposureMoney    = 0.0;
      globalExposurePercent  = 0.0;
      globalConsecutiveLosses = 0;


      //==============================================================
      // POSITION MANAGER
      //==============================================================

      breakEvenApplied       = false;
      trailingActive         = false;
      partialClosed          = false;

      currentPositionPrice   = 0.0;
      currentPositionProfit  = 0.0;
      currentPositionSL     = 0.0;
      currentPositionTP     = 0.0;


      //==============================================================
      // VALIDATION
      //==============================================================

      isValid                 = false;

      blockReason             = ASTRA_BLOCK_NO_DECISION;
      blockDescription        = "";

      spreadValid             = false;
      sessionValid            = false;
      marketOpen              = false;
      symbolValid             = false;
      tradingAllowed          = false;
      marginValid             = false;

      contextValid            = false;
      analysisComplete        = false;

      barsAvailable           = 0;

      validationMessage       = "";


      //==============================================================
      // PIPELINE TRACE
      //==============================================================

      pipelineStage           = "";
      rejectStage             = "";
      rejectReason            = "";
   }


   //=================================================================
   // BEGIN CYCLE
   //=================================================================

   void BeginCycle(
      const string _symbol,
      const ENUM_TIMEFRAMES _tf
   )
   {
      m_cycleCounter++;

      Reset();

      symbol =
         _symbol;

      primaryTF =
         _tf;

      cycleId =
         m_cycleCounter;

      analysisStartTime =
         TimeCurrent();

      contextValid =
         false;

      analysisComplete =
         false;

      pipelineStage =
         "ANALYSIS";

      rejectStage =
         "";

      rejectReason =
         "";

      validationMessage =
         "";
   }


   //=================================================================
   // END CYCLE
   //=================================================================

   void EndCycle()
   {
      analysisEndTime =
         TimeCurrent();

      analysisComplete =
         true;
   }


   //=================================================================
   // MARKET BAR COUNT
   //=================================================================

   int GetMarketBarCount() const
   {
      return ArraySize(
         marketBars
      );
   }


   //=================================================================
   // MARKET DATA AVAILABLE
   //=================================================================

   bool HasMarketDataBars() const
   {
      return (
         marketDataReady &&
         marketDataBarCount >= 3 &&
         marketBarsCount >= 3 &&
         ArraySize(marketBars) >= 3
      );
   }


   //=================================================================
   // MARKET HISTORY
   //=================================================================

   bool HasMarketHistory() const
   {
      return (
         marketHistoryReady &&
         marketBarsCount > 0 &&
         ArraySize(marketBars) > 0
      );
   }


   //=================================================================
   // GET MARKET BAR
   //=================================================================

   bool GetMarketBar(
      const int shift,
      MqlRates &bar
   ) const
   {
      ZeroMemory(
         bar
      );

      if(shift < 0)
         return false;

      const int count =
         ArraySize(
            marketBars
         );

      if(shift >= count)
         return false;

      bar =
         marketBars[shift];

      return true;
   }


   //=================================================================
   // CLAMP SCORE
   //=================================================================

   double ClampScore(
      const double value
   )
   {
      if(value < -100.0)
         return -100.0;

      if(value > 100.0)
         return 100.0;

      return value;
   }


   //=================================================================
   // CLAMP CONFIDENCE
   //=================================================================

   double ClampConfidence(
      const double value
   )
   {
      if(value < 0.0)
         return 0.0;

      if(value > 1.0)
         return 1.0;

      return value;
   }


   //=================================================================
   // STRUCTURAL VALIDATION
   //=================================================================

   bool Validate()
   {
      validationMessage =
         "";


      //==============================================================
      // SYMBOL
      //==============================================================

      if(symbol == "")
      {
         contextValid =
            false;

         dataQuality =
            ASTRA_DATA_INVALID;

         validationMessage =
            "Symbol invalido.";

         return false;
      }


      //==============================================================
      // TIMEFRAME
      //==============================================================

      if(primaryTF == PERIOD_CURRENT)
      {
         contextValid =
            false;

         validationMessage =
            "Timeframe invalido.";

         return false;
      }

      if(
         !IsValidNumericValue(bid) ||
         !IsValidNumericValue(ask) ||
         !IsValidNumericValue(price) ||
         !IsValidNumericValue(point) ||
         !IsValidNumericValue(tickSize) ||
         !IsValidNumericValue(tickValue) ||
         !IsValidNumericValue(spreadPoints) ||
         !IsValidNumericValue(atr) ||
         !IsValidNumericValue(volatility) ||
         !IsValidNumericValue(open) ||
         !IsValidNumericValue(high) ||
         !IsValidNumericValue(low) ||
         !IsValidNumericValue(close)
      )
      {
         contextValid =
            false;

         dataQuality =
            ASTRA_DATA_INVALID;

         validationMessage =
            "Valor numerico nao finito ou EMPTY_VALUE.";

         return false;
      }

      if(
         !IsValidNumericValue(structuralScore) ||
         !IsValidNumericValue(knowledgeScore) ||
         !IsValidNumericValue(liquidityScore) ||
         !IsValidNumericValue(fvgScore) ||
         !IsValidNumericValue(smartMoneyScore) ||
         !IsValidNumericValue(orderBlockStrength) ||
         !IsValidNumericValue(absorptionScore) ||
         !IsValidNumericValue(institutionalFlowScore) ||
         !IsValidNumericValue(wyckoffScore) ||
         !IsValidNumericValue(accumulationScore) ||
         !IsValidNumericValue(distributionScore) ||
         !IsValidNumericValue(trendStrength) ||
         !IsValidNumericValue(volatilityScore) ||
         !IsValidNumericValue(momentumScore) ||
         !IsValidNumericValue(momentumValue) ||
         !IsValidNumericValue(momentumAcceleration) ||
         !IsValidNumericValue(momentumAccelerationScore) ||
         !IsValidNumericValue(patternScore) ||
         !IsValidNumericValue(volumeDirectionalScore) ||
         !IsValidNumericValue(trafficLightScore) ||
         !IsValidNumericValue(trafficBullishScore) ||
         !IsValidNumericValue(trafficBearishScore) ||
         !IsValidNumericValue(aiProbabilityBuy) ||
         !IsValidNumericValue(aiProbabilitySell) ||
         !IsValidNumericValue(aiConsensusScore) ||
         !IsValidNumericValue(btcQuantScore) ||
         !IsValidNumericValue(mempoolPressureIndex) ||
         !IsValidNumericValue(mempoolAnomalyScore) ||
         !IsValidNumericValue(mempoolZScore) ||
         !IsValidNumericValue(mempoolPercentile) ||
         !IsValidNumericValue(mempoolMomentum) ||
         !IsValidNumericValue(mempoolAcceleration) ||
         !IsValidNumericValue(buyScore) ||
         !IsValidNumericValue(sellScore) ||
         !IsValidNumericValue(consensusScore) ||
         !IsValidNumericValue(confluenceScore) ||
         !IsValidNumericValue(finalConfidence) ||
         !IsValidNumericValue(probabilityBuy) ||
         !IsValidNumericValue(probabilitySell)
      )
      {
         contextValid =
            false;

         dataQuality =
            ASTRA_DATA_INVALID;

         validationMessage =
            "Evidencia numerica nao finita ou EMPTY_VALUE.";

         return false;
      }


      //==============================================================
      // MARKET DATA
      //==============================================================

      if(
         price <= 0.0 &&
         close <= 0.0
      )
      {
         contextValid =
            false;

         dataQuality =
            ASTRA_DATA_INVALID;

         validationMessage =
            "Preco invalido.";

         return false;
      }

      if(
         !marketDataReady ||
         !marketHistoryReady ||
         ArraySize(marketBars) < 3 ||
         !ValidateRateArray(marketBars)
      )
      {
         contextValid =
            false;

         dataQuality =
            ASTRA_DATA_INVALID;

         validationMessage =
            "Historico de mercado invalido ou incompleto.";

         return false;
      }

      if(
         !ValidateRateArray(mtfD1) ||
         !ValidateRateArray(mtfH4) ||
         !ValidateRateArray(mtfH1) ||
         !ValidateRateArray(mtfM15) ||
         !ValidateRateArray(mtfM5)
      )
      {
         contextValid =
            false;

         dataQuality =
            ASTRA_DATA_INVALID;

         validationMessage =
            "Historico multi-timeframe contem dados invalidos.";

         return false;
      }


      //==============================================================
      // HISTORY COUNT
      //==============================================================

      marketBarsCount =
         ArraySize(
            marketBars
         );

      marketDataBarCount =
         marketBarsCount;

      barsAvailable =
         marketBarsCount;


      //==============================================================
      // INVALID DATA
      //==============================================================

      if(
         dataQuality ==
         ASTRA_DATA_INVALID
      )
      {
         contextValid =
            false;

         if(validationMessage == "")
         {
            validationMessage =
               "Market Data marcado como invalido.";
         }

         return false;
      }


      //==============================================================
      // VALID
      //==============================================================

      contextValid =
         true;

      return true;
   }

   bool IsValidNumericValue(
      const double value
   ) const
   {
      return (
         MathIsValidNumber(value) &&
         value != EMPTY_VALUE
      );
   }

   bool IsValidMarketBar(
      const MqlRates &bar
   ) const
   {
      if(bar.time <= 0)
         return false;

      if(
         !IsValidNumericValue(bar.open) ||
         !IsValidNumericValue(bar.high) ||
         !IsValidNumericValue(bar.low) ||
         !IsValidNumericValue(bar.close)
      )
      {
         return false;
      }

      if(
         bar.open <= 0.0 ||
         bar.high <= 0.0 ||
         bar.low <= 0.0 ||
         bar.close <= 0.0 ||
         bar.high < bar.low ||
         bar.high < bar.open ||
         bar.high < bar.close ||
         bar.low > bar.open ||
         bar.low > bar.close
      )
      {
         return false;
      }

      return true;
   }

   bool ValidateRateArray(
      const MqlRates &rates[]
   ) const
   {
      for(int i = 0; i < ArraySize(rates); i++)
      {
         if(!IsValidMarketBar(rates[i]))
            return false;
      }

      return true;
   }


   //=================================================================
   // DECISION STRING
   //=================================================================

   string DecisionToString() const
   {
      if(decision == DECISION_BUY)
         return "BUY";

      if(decision == DECISION_SELL)
         return "SELL";

      return "NONE";
   }


   //=================================================================
   // REGIME STRING
   //=================================================================

   string RegimeToString() const
   {
      switch(regime)
      {
         case REGIME_EXPANSION:
            return "EXPANSION";

         case REGIME_CONTRACTION:
            return "CONTRACTION";

         case REGIME_RANGE:
            return "RANGE";

         case REGIME_TRANSITION:
            return "TRANSITION";
      }

      return "UNKNOWN";
   }


   //=================================================================
   // GRADE STRING
   //=================================================================

   string GradeToString() const
   {
      switch(opportunityGrade)
      {
         case GRADE_A_PLUS:
            return "A+";

         case GRADE_A:
            return "A";

         case GRADE_B:
            return "B";

         case GRADE_C:
            return "C";

         case GRADE_NO_TRADE:
            return "NO_TRADE";
      }

      return "?";
   }


   //=================================================================
   // RISK LEVEL STRING
   //=================================================================

   string RiskLevelToString() const
   {
      switch(riskLevel)
      {
         case RISK_LOW:
            return "LOW";

         case RISK_MEDIUM:
            return "MEDIUM";

         case RISK_HIGH:
            return "HIGH";

         case RISK_EXTREME:
            return "EXTREME";
      }

      return "?";
   }


   //=================================================================
   // LAYER STATE STRING
   //=================================================================

   string LayerStateToString(
      ENUM_LAYER_STATE state
   ) const
   {
      if(state == LAYER_VALID)
         return "VALID";

      if(state == LAYER_INVALID)
         return "INVALID";

      return "NEUTRAL";
   }


   //=================================================================
   // DEBUG STRING
   //=================================================================

   string ToString() const
   {
      return StringFormat(
         "[AstraContext][Cycle=%I64u] "
         "Symbol=%s | TF=%s | "
         "Bias=%s | "
         "Decision=%s | "
         "Grade=%s | "
         "Conf=%.3f | "
         "Buy=%.2f | "
         "Sell=%.2f | "
         "Consensus=%.2f | "
         "Confluence=%.2f | "
         "EvidenceStrength=%.3f | "
         "EvidenceCoverage=%.3f | "
         "EvidenceAgreement=%.3f | "
         "EvidenceQuality=%.3f | "
         "RiskApproved=%s | "
         "TradeValidated=%s | "
         "ExecAllowed=%s | "
         "ExecConfirmed=%s | "
         "Stage=%s | "
         "RejectStage=%s | "
         "RejectReason=%s",
         cycleId,
         symbol,
         EnumToString(primaryTF),
         EnumToString(structuralBias),
         DecisionToString(),
         GradeToString(),
         finalConfidence,
         buyScore,
         sellScore,
         consensusScore,
         confluenceScore,
         evidenceStrength,
         evidenceCoverage,
         evidenceAgreement,
         evidenceQuality,
         riskApproved ? "true" : "false",
         tradeValidationPassed ? "true" : "false",
         executionAllowed ? "true" : "false",
         executionConfirmed ? "true" : "false",
         pipelineStage,
         rejectStage,
         rejectReason
      );
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_ANALYSISCONTEXT_MQH
