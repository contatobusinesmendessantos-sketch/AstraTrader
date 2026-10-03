//+------------------------------------------------------------------+
//| MesaDeSinaisEngine.mqh                                           |
//| Observer-only strategy evidence for AstraTrader                 |
//+------------------------------------------------------------------+
#ifndef ASTRA_MESA_DE_SINAIS_ENGINE_MQH
#define ASTRA_MESA_DE_SINAIS_ENGINE_MQH

#property strict

#include <AstraTrader\Analysis\AnalysisContext.mqh>
#include <AstraTrader\Strategies\MesaDeSinaisTypes.mqh>

#define ASTRA_MESA_EMA_FAST       9
#define ASTRA_MESA_EMA_MID        21
#define ASTRA_MESA_EMA_SLOW       50
#define ASTRA_MESA_EMA_TREND      200
#define ASTRA_MESA_MACD_FAST      12
#define ASTRA_MESA_MACD_SLOW      26
#define ASTRA_MESA_MACD_SIGNAL    9
#define ASTRA_MESA_RSI_PERIOD     14
#define ASTRA_MESA_VOL_LOOKBACK   50
#define ASTRA_MESA_VOL_MULT       1.10
#define ASTRA_MESA_MOM_PERIOD     10
#define ASTRA_MESA_STOP_MULT      1.50
#define ASTRA_MESA_TAKE_MULT      1.50
#define ASTRA_MESA_REQUIRED_BARS  240

class MesaDeSinaisEngine
{
private:

   int RequiredHistoryBars() const
   {
      return ASTRA_MESA_REQUIRED_BARS;
   }

   double CalculateEMA(
      const MqlRates &rates[],
      const int period,
      const int shift
   ) const
   {
      const int size = ArraySize(rates);
      if(period <= 0 || shift < 0 || size - shift < period)
         return 0.0;

      double seed = 0.0;
      int count = 0;
      double ema = 0.0;
      const double alpha = 2.0 / (period + 1.0);

      for(int index = size - 1; index >= shift; index--)
      {
         const double closePrice = rates[index].close;
         count++;

         if(count <= period)
         {
            seed += closePrice;
            if(count == period)
               ema = seed / period;
         }
         else
         {
            ema = (closePrice - ema) * alpha + ema;
         }
      }

      return count >= period ? ema : 0.0;
   }

   double CalculateMACD(
      const MqlRates &rates[],
      const int shift
   ) const
   {
      return
         CalculateEMA(rates, ASTRA_MESA_MACD_FAST, shift) -
         CalculateEMA(rates, ASTRA_MESA_MACD_SLOW, shift);
   }

   double CalculateMACDSignal(
      const MqlRates &rates[],
      const int shift
   ) const
   {
      const int size = ArraySize(rates);
      if(size - shift < ASTRA_MESA_MACD_SLOW + ASTRA_MESA_MACD_SIGNAL)
         return 0.0;

      double seed = 0.0;
      double signal = 0.0;
      int count = 0;
      const double alpha = 2.0 / (ASTRA_MESA_MACD_SIGNAL + 1.0);

      for(int index = size - 1; index >= shift; index--)
      {
         const double macd = CalculateMACD(rates, index);
         count++;

         if(count <= ASTRA_MESA_MACD_SIGNAL)
         {
            seed += macd;
            if(count == ASTRA_MESA_MACD_SIGNAL)
               signal = seed / ASTRA_MESA_MACD_SIGNAL;
         }
         else
         {
            signal = (macd - signal) * alpha + signal;
         }
      }

      return count >= ASTRA_MESA_MACD_SIGNAL ? signal : 0.0;
   }

   double CalculateRSI(
      const MqlRates &rates[],
      const int shift
   ) const
   {
      const int size = ArraySize(rates);
      if(size - shift <= ASTRA_MESA_RSI_PERIOD)
         return 50.0;

      double gainSum = 0.0;
      double lossSum = 0.0;
      double averageGain = 0.0;
      double averageLoss = 0.0;
      int count = 0;

      for(int index = size - 2; index >= shift; index--)
      {
         const double delta = rates[index].close - rates[index + 1].close;
         const double gain = delta > 0.0 ? delta : 0.0;
         const double loss = delta < 0.0 ? -delta : 0.0;
         count++;

         if(count <= ASTRA_MESA_RSI_PERIOD)
         {
            gainSum += gain;
            lossSum += loss;
            if(count == ASTRA_MESA_RSI_PERIOD)
            {
               averageGain = gainSum / ASTRA_MESA_RSI_PERIOD;
               averageLoss = lossSum / ASTRA_MESA_RSI_PERIOD;
            }
         }
         else
         {
            averageGain =
               (averageGain * (ASTRA_MESA_RSI_PERIOD - 1) + gain) /
               ASTRA_MESA_RSI_PERIOD;
            averageLoss =
               (averageLoss * (ASTRA_MESA_RSI_PERIOD - 1) + loss) /
               ASTRA_MESA_RSI_PERIOD;
         }
      }

      if(count < ASTRA_MESA_RSI_PERIOD)
         return 50.0;

      if(averageLoss <= 0.0)
         return averageGain > 0.0 ? 100.0 : 50.0;

      return 100.0 - 100.0 /
         (1.0 + averageGain / averageLoss);
   }

   double TrueRange(
      const MqlRates &rates[],
      const int index
   ) const
   {
      const double range = rates[index].high - rates[index].low;
      if(index + 1 >= ArraySize(rates))
         return range;

      return MathMax(
         range,
         MathMax(
            MathAbs(rates[index].high - rates[index + 1].close),
            MathAbs(rates[index].low - rates[index + 1].close)
         )
      );
   }

   double CalculateATR(
      const MqlRates &rates[],
      const int period,
      const int shift
   ) const
   {
      const int size = ArraySize(rates);
      if(period <= 0 || shift < 0 || size - shift < period)
         return 0.0;

      double seed = 0.0;
      double atr = 0.0;
      int count = 0;

      for(int index = size - 1; index >= shift; index--)
      {
         const double trueRange = TrueRange(rates, index);
         count++;

         if(count <= period)
         {
            seed += trueRange;
            if(count == period)
               atr = seed / period;
         }
         else
         {
            atr = (atr * (period - 1) + trueRange) / period;
         }
      }

      return count >= period ? atr : 0.0;
   }

   double CalculateATRAverage(
      const MqlRates &rates[]
   ) const
   {
      double sum = 0.0;
      for(int shift = 1; shift <= ASTRA_MESA_VOL_LOOKBACK; shift++)
         sum += CalculateATR(rates, ASTRA_MESA_RSI_PERIOD, shift);

      return sum / ASTRA_MESA_VOL_LOOKBACK;
   }

   double CalculateMomentum(
      const MqlRates &rates[]
   ) const
   {
      return
         rates[0].close -
         rates[ASTRA_MESA_MOM_PERIOD].close;
   }

   bool ParseBool(const string value) const
   {
      return value == "true" || value == "TRUE" || value == "1";
   }

   bool LoadReference(
      const AnalysisContext &context,
      MesaReferenceSnapshot &reference
   ) const
   {
      reference.Reset();

      const int handle = FileOpen(
         "MesaDeSinais_live_reference.csv",
         FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ,
         ','
      );

      if(handle == INVALID_HANDLE)
         return false;

      while(!FileIsEnding(handle))
      {
         const string source = FileReadString(handle);
         if(source == "")
            break;

         const string functionName = FileReadString(handle);
         const string sourceMode = FileReadString(handle);
         const string symbol = FileReadString(handle);
         const string timeframe = FileReadString(handle);
         const string barTimeText = FileReadString(handle);
         const string shiftText = FileReadString(handle);
         const string emaFastText = FileReadString(handle);
         const string emaMidText = FileReadString(handle);
         const string emaSlowText = FileReadString(handle);
         const string emaTrendText = FileReadString(handle);
         const string macdMainText = FileReadString(handle);
         const string macdSignalText = FileReadString(handle);
         const string macdHistogramText = FileReadString(handle);
         const string macdPreviousText = FileReadString(handle);
         const string rsiText = FileReadString(handle);
         const string atrText = FileReadString(handle);
         const string atrAverageText = FileReadString(handle);
         const string volatilityRatioText = FileReadString(handle);
         const string volatilityOKText = FileReadString(handle);
         const string momentumText = FileReadString(handle);
         const string buyScoreText = FileReadString(handle);
         const string sellScoreText = FileReadString(handle);
         const string upTrendText = FileReadString(handle);
         const string downTrendText = FileReadString(handle);
         const string directionText = FileReadString(handle);
         const string entryText = FileReadString(handle);
         const string stopText = FileReadString(handle);
         const string takeText = FileReadString(handle);
         const string tickTimeText = FileReadString(handle);

         if(source == "Source")
            continue;

         if(
            source != "MesaDeSinais_3.mq5" ||
            functionName != "ComputeRow()" ||
            sourceMode != "LIVE"
         )
         {
            continue;
         }

         const datetime barTime = StringToTime(barTimeText);
         if(
            symbol != context.symbol ||
            timeframe != EnumToString(context.primaryTF) ||
            barTime != context.marketBars[0].time
         )
         {
            continue;
         }

         reference.available = true;
         reference.symbol = symbol;
         reference.timeframe = timeframe;
         reference.barTime = barTime;
         reference.tickTime = StringToTime(tickTimeText);
         reference.currentShift = (int)StringToInteger(shiftText);
         reference.emaFast = StringToDouble(emaFastText);
         reference.emaMid = StringToDouble(emaMidText);
         reference.emaSlow = StringToDouble(emaSlowText);
         reference.emaTrend = StringToDouble(emaTrendText);
         reference.macdMain = StringToDouble(macdMainText);
         reference.macdSignal = StringToDouble(macdSignalText);
         reference.macdHistogram = StringToDouble(macdHistogramText);
         reference.macdHistogramPrevious = StringToDouble(macdPreviousText);
         reference.rsi = StringToDouble(rsiText);
         reference.atr = StringToDouble(atrText);
         reference.atrAverage = StringToDouble(atrAverageText);
         reference.volatilityRatio = StringToDouble(volatilityRatioText);
         reference.volatilityOK = ParseBool(volatilityOKText);
         reference.momentum = StringToDouble(momentumText);
         reference.buyScore = (int)StringToInteger(buyScoreText);
         reference.sellScore = (int)StringToInteger(sellScoreText);
         reference.upTrend = ParseBool(upTrendText);
         reference.downTrend = ParseBool(downTrendText);
         reference.direction = (int)StringToInteger(directionText);
         reference.entry = StringToDouble(entryText);
         reference.stop = StringToDouble(stopText);
         reference.take = StringToDouble(takeText);
      }

      FileClose(handle);
      return reference.available;
   }

   void LogNumericComparison(
      const string field,
      const double reference,
      const double value,
      const double tolerance
   ) const
   {
      const double absDiff = MathAbs(reference - value);
      const double relativeDiff =
         reference != 0.0 ? absDiff / MathAbs(reference) : absDiff;
      string result = "DECISION_RELEVANT_DIFF";

      if(absDiff == 0.0)
         result = "NUMERIC_MATCH";
      else
      if(absDiff <= tolerance)
         result = "SMALL_NUMERIC_DIFF";

      PrintFormat(
         "[MESA_COMPARE] Field=%s | Reference=%.10f | NewEngine=%.10f | "
         "AbsDiff=%.10f | RelativeDiff=%.10f | Tolerance=%.10f | Classification=%s",
         field,
         reference,
         value,
         absDiff,
         relativeDiff,
         tolerance,
         result
      );
   }

   void LogSnapshotComparison(
      const string field,
      const double reference,
      const double value,
      const double tolerance,
      const datetime referenceTickTime,
      const datetime newTickTime
   ) const
   {
      const double absDiff = MathAbs(reference - value);
      const double relativeDiff =
         reference != 0.0 ? absDiff / MathAbs(reference) : absDiff;
      string result = "SNAPSHOT_DEPENDENT";

      if(referenceTickTime == newTickTime)
      {
         if(absDiff == 0.0)
            result = "NUMERIC_MATCH";
         else
         if(absDiff <= tolerance)
            result = "SMALL_NUMERIC_DIFF";
         else
            result = "DECISION_RELEVANT_DIFF";
      }

      PrintFormat(
         "[MESA_COMPARE] Field=%s | Reference=%.10f | NewEngine=%.10f | "
         "AbsDiff=%.10f | RelativeDiff=%.10f | Tolerance=%.10f | "
         "ReferenceTickTime=%I64d | NewTickTime=%I64d | Classification=%s",
         field,
         reference,
         value,
         absDiff,
         relativeDiff,
         tolerance,
         referenceTickTime,
         newTickTime,
         result
      );
   }

   void LogBoolComparison(
      const string field,
      const bool reference,
      const bool value
   ) const
   {
      PrintFormat(
         "[MESA_COMPARE] Field=%s | Reference=%s | NewEngine=%s | "
         "Tolerance=EXACT | Classification=%s",
         field,
         reference ? "true" : "false",
         value ? "true" : "false",
         reference == value ? "NUMERIC_MATCH" : "FILTER_CHANGE"
      );
   }

   string DirectionName(const int direction) const
   {
      if(direction > 0)
         return "BUY";

      if(direction < 0)
         return "SELL";

      return "NEUTRAL";
   }

   int TrendDirection(
      const bool upTrend,
      const bool downTrend
   ) const
   {
      if(upTrend && !downTrend)
         return 1;

      if(downTrend && !upTrend)
         return -1;

      return 0;
   }

   void LogDirectionComparison(
      const int reference,
      const int value
   ) const
   {
      PrintFormat(
         "[MESA_COMPARE] Field=Direction | OriginalDirection=%s | "
         "NewDirection=%s | Classification=%s",
         DirectionName(reference),
         DirectionName(value),
         reference == value
            ? "MATCH"
            : reference > 0
               ? value < 0 ? "BUY_TO_SELL" : "BUY_TO_NEUTRAL"
               : reference < 0
                  ? value > 0 ? "SELL_TO_BUY" : "SELL_TO_NEUTRAL"
                  : value > 0 ? "NEUTRAL_TO_BUY" : "NEUTRAL_TO_SELL"
      );
   }

   void CompareReference(
      const AnalysisContext &context,
      const MesaReferenceSnapshot &reference,
      const MesaSignal &signal
   ) const
   {
      const double priceTolerance = context.point;
      const double ratioTolerance = 0.000001;
      const double rsiTolerance = 0.01;

      LogNumericComparison("EMA9", reference.emaFast, signal.emaFast, priceTolerance);
      LogNumericComparison("EMA21", reference.emaMid, signal.emaMid, priceTolerance);
      LogNumericComparison("EMA50", reference.emaSlow, signal.emaSlow, priceTolerance);
      LogNumericComparison("EMA200", reference.emaTrend, signal.emaTrend, priceTolerance);
      LogNumericComparison("MACDMain", reference.macdMain, signal.macdMain, priceTolerance);
      LogNumericComparison("MACDSignal", reference.macdSignal, signal.macdSignal, priceTolerance);
      LogNumericComparison("MACDHistogram", reference.macdHistogram, signal.macdHistogram, priceTolerance);
      LogNumericComparison("MACDHistogramPrevious", reference.macdHistogramPrevious, signal.macdHistogramPrevious, priceTolerance);
      LogNumericComparison("RSI", reference.rsi, signal.rsi, rsiTolerance);
      LogNumericComparison("ATR", reference.atr, signal.atr, priceTolerance);
      LogNumericComparison("ATR_Average", reference.atrAverage, signal.atrAverage, priceTolerance);
      LogNumericComparison("VolatilityRatio", reference.volatilityRatio, signal.volatilityRatio, ratioTolerance);
      LogNumericComparison("Momentum", reference.momentum, signal.momentum, priceTolerance);
      LogSnapshotComparison(
         "Entry",
         reference.entry,
         signal.suggestedEntry,
         priceTolerance,
         reference.tickTime,
         context.analysisStartTime
      );
      LogSnapshotComparison(
         "Stop",
         reference.stop,
         signal.suggestedStop,
         priceTolerance,
         reference.tickTime,
         context.analysisStartTime
      );
      LogSnapshotComparison(
         "Take",
         reference.take,
         signal.suggestedTake,
         priceTolerance,
         reference.tickTime,
         context.analysisStartTime
      );

      LogBoolComparison("VolatilityOK", reference.volatilityOK, signal.volatilityOK);
      LogBoolComparison("UpTrend", reference.upTrend, signal.upTrend);
      LogBoolComparison("DownTrend", reference.downTrend, signal.downTrend);
      LogBoolComparison("EMA9_gt_EMA21", reference.emaFast > reference.emaMid, signal.emaFastMidAligned);
      LogBoolComparison("EMA21_gt_EMA50", reference.emaMid > reference.emaSlow, signal.emaMidSlowAligned);
      LogBoolComparison("MACDPositive", reference.macdHistogram > 0.0, signal.macdPositive);
      LogBoolComparison("MACDImproving", reference.macdHistogram > reference.macdHistogramPrevious, signal.macdImproving);
      const int referenceTrendDirection =
         TrendDirection(reference.upTrend, reference.downTrend);
      const int signalTrendDirection =
         TrendDirection(signal.upTrend, signal.downTrend);

      const bool referenceRsiBuy = reference.rsi < 75.0;
      const bool signalRsiBuy = signal.rsi < 75.0;
      const bool referenceRsiSell = reference.rsi > 25.0;
      const bool signalRsiSell = signal.rsi > 25.0;

      const bool referenceMomentumBuy = reference.momentum > 0.0;
      const bool signalMomentumBuy = signal.momentum > 0.0;
      const bool referenceMomentumSell = reference.momentum < 0.0;
      const bool signalMomentumSell = signal.momentum < 0.0;

      LogDirectionComparison(
         referenceTrendDirection,
         signalTrendDirection
      );
      LogBoolComparison("RSI_BUY_PARITY", referenceRsiBuy, signalRsiBuy);
      LogBoolComparison("RSI_SELL_PARITY", referenceRsiSell, signalRsiSell);
      LogBoolComparison("VOLATILITY_PARITY", reference.volatilityOK, signal.volatilityOK);
      LogBoolComparison("MOMENTUM_BUY_PARITY", referenceMomentumBuy, signalMomentumBuy);
      LogBoolComparison("MOMENTUM_SELL_PARITY", referenceMomentumSell, signalMomentumSell);
      PrintFormat(
         "[MESA_COMPARE] Field=CORE_DIRECTION_PARITY | OriginalCoreBuy=%s | "
         "OriginalCoreSell=%s | NewCoreBuy=%s | NewCoreSell=%s | CoreParity=%s",
         reference.buyScore == 4 ? "true" : "false",
         reference.sellScore == 4 ? "true" : "false",
         signal.buyScore == 4 ? "true" : "false",
         signal.sellScore == 4 ? "true" : "false",
         (reference.buyScore == 4) == (signal.buyScore == 4) &&
         (reference.sellScore == 4) == (signal.sellScore == 4)
            ? "PASS"
            : "FAIL"
      );
      const bool referenceBuy =
         reference.buyScore == 4 &&
         reference.upTrend &&
         reference.rsi < 75.0 &&
         reference.volatilityOK &&
         reference.momentum > 0.0;
      const bool newBuy =
         signal.buyScore == 4 &&
         signal.upTrend &&
         signal.rsi < 75.0 &&
         signal.volatilityOK &&
         signal.momentum > 0.0;
      const bool referenceSell =
         reference.sellScore == 4 &&
         reference.downTrend &&
         reference.rsi > 25.0 &&
         reference.volatilityOK &&
         reference.momentum < 0.0;
      const bool newSell =
         signal.sellScore == 4 &&
         signal.downTrend &&
         signal.rsi > 25.0 &&
         signal.volatilityOK &&
         signal.momentum < 0.0;
      LogBoolComparison("BUY_CONDITION", referenceBuy, newBuy);
      LogBoolComparison("SELL_CONDITION", referenceSell, newSell);
      LogDirectionComparison(reference.direction, signal.direction);
   }

   void LogTelemetry(
      const AnalysisContext &context,
      const MesaSignal &signal,
      const bool referenceAvailable
   ) const
   {
      PrintFormat(
         "[MESA_NEW] Cycle=%I64u | Symbol=%s | Timeframe=%s | BarTime=%I64d | CurrentShift=0 | "
         "Valid=%s | Direction=%d | CoreScore=%d | EMA9=%.10f | EMA21=%.10f | "
         "EMA50=%.10f | EMA200=%.10f | MACDMain=%.10f | MACDSignal=%.10f | "
         "MACDHistogram=%.10f | MACDHistogramPrevious=%.10f | RSI=%.5f | ATR=%.10f | "
         "ATR_Average=%.10f | VolatilityRatio=%.10f | VolatilityOK=%s | Momentum=%.10f | "
         "BuyScore=%d | SellScore=%d | UpTrend=%s | DownTrend=%s | Entry=%.10f | "
         "Stop=%.10f | Take=%.10f | State=%s | Reason=%s",
         context.cycleId,
         context.symbol,
         EnumToString(context.primaryTF),
         context.marketBars[0].time,
         signal.valid ? "true" : "false",
         signal.direction,
         signal.coreScore,
         signal.emaFast,
         signal.emaMid,
         signal.emaSlow,
         signal.emaTrend,
         signal.macdMain,
         signal.macdSignal,
         signal.macdHistogram,
         signal.macdHistogramPrevious,
         signal.rsi,
         signal.atr,
         signal.atrAverage,
         signal.volatilityRatio,
         signal.volatilityOK ? "true" : "false",
         signal.momentum,
         signal.buyScore,
         signal.sellScore,
         signal.upTrend ? "true" : "false",
         signal.downTrend ? "true" : "false",
         signal.suggestedEntry,
         signal.suggestedStop,
         signal.suggestedTake,
         signal.state,
         signal.reason
      );

      PrintFormat(
         "[MESA_REFERENCE_STATUS] Symbol=%s | TF=%s | BarTime=%I64d | "
         "REFERENCE_AVAILABLE=%s | COMPARE_STATUS=%s",
         context.symbol,
         EnumToString(context.primaryTF),
         context.marketBars[0].time,
         referenceAvailable ? "YES" : "NO",
         referenceAvailable ? "ACTIVE" : "BLOCKED"
      );
   }

   void LogReference(
      const MesaReferenceSnapshot &reference
   ) const
   {
      PrintFormat(
         "[MESA_REF] Symbol=%s | Timeframe=%s | BarTime=%I64d | TickTime=%I64d | CurrentShift=%d | "
         "EMA9=%.10f | EMA21=%.10f | EMA50=%.10f | EMA200=%.10f | "
         "MACDMain=%.10f | MACDSignal=%.10f | MACDHistogram=%.10f | "
         "MACDHistogramPrevious=%.10f | RSI=%.5f | ATR=%.10f | ATR_Average=%.10f | "
         "VolatilityRatio=%.10f | VolatilityOK=%s | Momentum=%.10f | BuyScore=%d | "
         "SellScore=%d | UpTrend=%s | DownTrend=%s | Direction=%d | Entry=%.10f | "
         "Stop=%.10f | Take=%.10f",
         reference.symbol,
         reference.timeframe,
         reference.barTime,
         reference.tickTime,
         reference.currentShift,
         reference.emaFast,
         reference.emaMid,
         reference.emaSlow,
         reference.emaTrend,
         reference.macdMain,
         reference.macdSignal,
         reference.macdHistogram,
         reference.macdHistogramPrevious,
         reference.rsi,
         reference.atr,
         reference.atrAverage,
         reference.volatilityRatio,
         reference.volatilityOK ? "true" : "false",
         reference.momentum,
         reference.buyScore,
         reference.sellScore,
         reference.upTrend ? "true" : "false",
         reference.downTrend ? "true" : "false",
         reference.direction,
         reference.entry,
         reference.stop,
         reference.take
      );
   }

public:

   bool Calculate(
      AnalysisContext &context,
      MesaSignal &signal
   )
   {
      signal.Reset();

      const int availableBars = MathMin(
         context.marketBarsCount,
         ArraySize(context.marketBars)
      );
      const int requiredBars = RequiredHistoryBars();
      context.barsAvailable = availableBars;

      if(availableBars < requiredBars)
      {
         signal.state = "INSUFFICIENT_HISTORY";
         signal.reason = StringFormat(
            "INSUFFICIENT_HISTORY available=%d required=%d",
            availableBars,
            requiredBars
         );
         LogTelemetry(context, signal, false);
         return false;
      }

      signal.emaFast = CalculateEMA(context.marketBars, ASTRA_MESA_EMA_FAST, 0);
      signal.emaMid = CalculateEMA(context.marketBars, ASTRA_MESA_EMA_MID, 0);
      signal.emaSlow = CalculateEMA(context.marketBars, ASTRA_MESA_EMA_SLOW, 0);
      signal.emaTrend = CalculateEMA(context.marketBars, ASTRA_MESA_EMA_TREND, 0);

      signal.emaFastMidAligned = signal.emaFast > signal.emaMid;
      signal.emaMidSlowAligned = signal.emaMid > signal.emaSlow;

      signal.macdMain = CalculateMACD(context.marketBars, 0);
      signal.macdSignal = CalculateMACDSignal(context.marketBars, 0);
      signal.macdHistogram = signal.macdMain - signal.macdSignal;
      signal.macdHistogramPrevious =
         CalculateMACD(context.marketBars, 1) -
         CalculateMACDSignal(context.marketBars, 1);
      signal.macdPositive = signal.macdHistogram > 0.0;
      signal.macdImproving =
         signal.macdHistogram > signal.macdHistogramPrevious;

      signal.rsi = CalculateRSI(context.marketBars, 0);
      signal.atr = CalculateATR(context.marketBars, ASTRA_MESA_RSI_PERIOD, 0);
      signal.atrAverage = CalculateATRAverage(context.marketBars);
      signal.volatilityRatio = signal.atrAverage > 0.0
         ? signal.atr / signal.atrAverage
         : 0.0;
      signal.momentum = CalculateMomentum(context.marketBars);

      int buyScore = 0;
      int sellScore = 0;

      if(signal.emaFast > signal.emaMid)
         buyScore++;
      else
         sellScore++;

      if(signal.emaMid > signal.emaSlow)
         buyScore++;
      else
         sellScore++;

      if(signal.macdHistogram > 0.0)
         buyScore++;
      else
         sellScore++;

      if(signal.macdHistogram > signal.macdHistogramPrevious)
         buyScore++;
      else
         sellScore++;

      const bool buyTrend = signal.emaFast > signal.emaTrend;
      const bool sellTrend = signal.emaFast < signal.emaTrend;
      const bool buyRsi = signal.rsi < 75.0;
      const bool sellRsi = signal.rsi > 25.0;
      const bool volatilityOk =
         signal.atrAverage > 0.0 &&
         signal.atr > signal.atrAverage * ASTRA_MESA_VOL_MULT;
      const bool buyMomentum = signal.momentum > 0.0;
      const bool sellMomentum = signal.momentum < 0.0;

      signal.trend200Aligned = buyTrend != sellTrend;
      signal.rsiFilterPassed = buyRsi != sellRsi;
      signal.volatilityFilterPassed = volatilityOk;
      signal.momentumFilterPassed = buyMomentum != sellMomentum;
      signal.upTrend = buyTrend;
      signal.downTrend = sellTrend;
      signal.volatilityOK = volatilityOk;
      signal.buyScore = buyScore;
      signal.sellScore = sellScore;

      if(
         buyScore == 4 &&
         buyTrend &&
         buyRsi &&
         volatilityOk &&
         buyMomentum
      )
      {
         signal.valid = true;
         signal.direction = 1;
         signal.coreScore = 4;
         signal.state = "VALID_BUY";
         signal.reason = "BUY_CORE_4_TREND_RSI_VOL_MOMENTUM";
         signal.suggestedEntry = context.ask;
         signal.suggestedStop =
            signal.suggestedEntry - signal.atr * ASTRA_MESA_STOP_MULT;
         signal.suggestedTake =
            signal.suggestedEntry + signal.atr * ASTRA_MESA_TAKE_MULT;
      }
      else if(
         sellScore == 4 &&
         sellTrend &&
         sellRsi &&
         volatilityOk &&
         sellMomentum
      )
      {
         signal.valid = true;
         signal.direction = -1;
         signal.coreScore = -4;
         signal.state = "VALID_SELL";
         signal.reason = "SELL_CORE_4_TREND_RSI_VOL_MOMENTUM";
         signal.suggestedEntry = context.bid;
         signal.suggestedStop =
            signal.suggestedEntry + signal.atr * ASTRA_MESA_STOP_MULT;
         signal.suggestedTake =
            signal.suggestedEntry - signal.atr * ASTRA_MESA_TAKE_MULT;
      }
      else
      {
         signal.state = "INVALID";
         signal.reason = "MESA_CORE_RULES_OR_FILTERS_FAILED";
      }

      MesaReferenceSnapshot reference;
      reference.Reset();

      const bool referenceAvailable =
         LoadReference(context, reference);

      if(referenceAvailable)
      {
         LogReference(reference);
         CompareReference(context, reference, signal);
         PrintFormat(
            "[MESA_REFERENCE_STATUS] Symbol=%s | TF=%s | BarTime=%I64d | REFERENCE_AVAILABLE=YES | COMPARE_STATUS=ACTIVE",
            context.symbol,
            EnumToString(context.primaryTF),
            context.marketBars[0].time
         );
      }
      else
      {
         PrintFormat(
            "[MESA_REFERENCE_STATUS] Symbol=%s | TF=%s | BarTime=%I64d | REFERENCE_AVAILABLE=NO | COMPARE_STATUS=BLOCKED",
            context.symbol,
            EnumToString(context.primaryTF),
            context.marketBars[0].time
         );
      }

      LogTelemetry(context, signal, referenceAvailable);

      return signal.valid;
   }
};

#endif
