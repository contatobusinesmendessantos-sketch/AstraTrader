//+------------------------------------------------------------------+
//| MesaDeSinaisTypes.mqh                                            |
//| Astra Trader AI                                                  |
//|                                                                  |
//| Contrato do Mesa de Sinais em OBSERVER MODE.                    |
//|                                                                  |
//| Transporta somente evidência estratégica, sem alterar o pipeline |
//| de decisão, risco ou execução.                                   |
//+------------------------------------------------------------------+
#ifndef ASTRA_MESA_DE_SINAIS_TYPES_MQH
#define ASTRA_MESA_DE_SINAIS_TYPES_MQH

#property strict

struct MesaSignal
{
   bool valid;

   int direction; // +1 BUY, -1 SELL, 0 NEUTRAL
   int coreScore; // +4 bullish / -4 bearish / 0 neutral

   bool emaFastMidAligned;
   bool emaMidSlowAligned;
   bool macdPositive;
   bool macdImproving;

   bool upTrend;
   bool downTrend;
   bool volatilityOK;

   int buyScore;
   int sellScore;

   bool trend200Aligned;
   bool rsiFilterPassed;
   bool volatilityFilterPassed;
   bool momentumFilterPassed;

   double emaFast;
   double emaMid;
   double emaSlow;
   double emaTrend;

   double macdMain;
   double macdSignal;
   double macdHistogram;
   double macdHistogramPrevious;

   double rsi;

   double atr;
   double atrAverage;
   double volatilityRatio;

   double momentum;

   double suggestedEntry;
   double suggestedStop;
   double suggestedTake;

   string state;
   string reason;

   void Reset()
   {
      valid = false;
      direction = 0;
      coreScore = 0;

      emaFastMidAligned = false;
      emaMidSlowAligned = false;
      macdPositive = false;
      macdImproving = false;

      upTrend = false;
      downTrend = false;
      volatilityOK = false;

      buyScore = 0;
      sellScore = 0;

      trend200Aligned = false;
      rsiFilterPassed = false;
      volatilityFilterPassed = false;
      momentumFilterPassed = false;

      emaFast = 0.0;
      emaMid = 0.0;
      emaSlow = 0.0;
      emaTrend = 0.0;

      macdMain = 0.0;
      macdSignal = 0.0;
      macdHistogram = 0.0;
      macdHistogramPrevious = 0.0;

      rsi = 50.0;

      atr = 0.0;
      atrAverage = 0.0;
      volatilityRatio = 0.0;

      momentum = 0.0;

      suggestedEntry = 0.0;
      suggestedStop = 0.0;
      suggestedTake = 0.0;

      state = "";
      reason = "";
   }
};

struct MesaReferenceSnapshot
{
   bool available;
   string symbol;
   string timeframe;
   datetime barTime;
   datetime tickTime;
   int currentShift;

   double emaFast;
   double emaMid;
   double emaSlow;
   double emaTrend;
   double macdMain;
   double macdSignal;
   double macdHistogram;
   double macdHistogramPrevious;
   double rsi;
   double atr;
   double atrAverage;
   double volatilityRatio;
   bool volatilityOK;
   double momentum;
   int buyScore;
   int sellScore;
   bool upTrend;
   bool downTrend;
   int direction;
   double entry;
   double stop;
   double take;

   void Reset()
   {
      available = false;
      symbol = "";
      timeframe = "";
      barTime = 0;
      tickTime = 0;
      currentShift = 0;
      emaFast = 0.0;
      emaMid = 0.0;
      emaSlow = 0.0;
      emaTrend = 0.0;
      macdMain = 0.0;
      macdSignal = 0.0;
      macdHistogram = 0.0;
      macdHistogramPrevious = 0.0;
      rsi = 50.0;
      atr = 0.0;
      atrAverage = 0.0;
      volatilityRatio = 0.0;
      volatilityOK = false;
      momentum = 0.0;
      buyScore = 0;
      sellScore = 0;
      upTrend = false;
      downTrend = false;
      direction = 0;
      entry = 0.0;
      stop = 0.0;
      take = 0.0;
   }
};

#endif // ASTRA_MESA_DE_SINAIS_TYPES_MQH
