//+------------------------------------------------------------------+
//| MarketEvidenceEngine.mqh                                        |
//| Evidências estruturais complementares do AstraTrader             |
//+------------------------------------------------------------------+
#ifndef ASTRA_MARKETEVIDENCEENGINE_MQH
#define ASTRA_MARKETEVIDENCEENGINE_MQH

#property strict

#include <AstraTrader\Analysis\AnalysisContext.mqh>

class MarketEvidenceEngine
{
private:
   double Clamp(const double value, const double minimum, const double maximum) const
   {
      return MathMax(minimum, MathMin(maximum, value));
   }

   double AverageVolume(const AnalysisContext &context) const
   {
      const int count = MathMin(ArraySize(context.marketBars), 20);
      if(count < 3)
         return 0.0;

      double total = 0.0;
      int valid = 0;
      for(int i = 2; i < count; i++)
      {
         if(context.marketBars[i].tick_volume > 0)
         {
            total += (double)context.marketBars[i].tick_volume;
            valid++;
         }
      }
      return valid > 0 ? total / valid : 0.0;
   }

public:
   bool Analyze(AnalysisContext &context)
   {
      context.nearestSupport = 0.0;
      context.nearestResistance = 0.0;
      context.distanceToSupport = 0.0;
      context.distanceToResistance = 0.0;
      context.supportStrength = 0.0;
      context.resistanceStrength = 0.0;
      context.priceLocation = PRICE_LOCATION_UNKNOWN;
      context.bullishBreakoutConfirmed = false;
      context.bearishBreakoutConfirmed = false;
      context.volumeConfirmsTrend = false;
      context.volumeDivergesFromTrend = false;
      context.knowledgeScore = 0.0;
      context.mtfConflict = false;
      context.higherTFConflict = false;
      context.mtfAlignmentScore = 0.0;

      // Support/resistance, location and MTF conflict/alignment fields
      // are trace/context only and are not direct gates. A confirmed
      // breakout is separately converted to knowledgeScore, which the
      // decision engine consumes as directional evidence.

      if(!context.marketDataReady || ArraySize(context.marketBars) < 3)
         return false;

      MqlRates closed = context.marketBars[1];
      const double price = closed.close;
      const double support = context.lastSwingLowPrice;
      const double resistance = context.lastSwingHighPrice;
      const double range = MathMax(context.atr, closed.high - closed.low);
      const double proximity = MathMax(range * 0.50, context.point * 10.0);

      context.nearestSupport = support;
      context.nearestResistance = resistance;
      if(support > 0.0)
         context.distanceToSupport = MathMax(0.0, price - support);
      if(resistance > 0.0)
         context.distanceToResistance = MathMax(0.0, resistance - price);

      if(resistance > 0.0 && closed.close > resistance)
      {
         context.bullishBreakoutConfirmed = true;
         context.priceLocation = PRICE_LOCATION_BREAKING_RESISTANCE;
      }
      else if(support > 0.0 && closed.close < support)
      {
         context.bearishBreakoutConfirmed = true;
         context.priceLocation = PRICE_LOCATION_BREAKING_SUPPORT;
      }
      else if(support > 0.0 && context.distanceToSupport <= proximity)
         context.priceLocation = PRICE_LOCATION_NEAR_SUPPORT;
      else if(resistance > 0.0 && context.distanceToResistance <= proximity)
         context.priceLocation = PRICE_LOCATION_NEAR_RESISTANCE;
      else
         context.priceLocation = PRICE_LOCATION_MID_RANGE;

      context.supportStrength = support > 0.0 ? 1.0 : 0.0;
      context.resistanceStrength = resistance > 0.0 ? 1.0 : 0.0;

      const double averageVolume = AverageVolume(context);
      const double currentVolume = (double)closed.tick_volume;
      const bool expandingVolume = averageVolume > 0.0 && currentVolume >= averageVolume * 1.10;
      const bool bullishCandle = closed.close > closed.open;
      const bool bearishCandle = closed.close < closed.open;

      if(expandingVolume && context.structuralBias == BIAS_BULLISH && bullishCandle)
         context.volumeConfirmsTrend = true;
      else if(expandingVolume && context.structuralBias == BIAS_BEARISH && bearishCandle)
         context.volumeConfirmsTrend = true;
      else if(expandingVolume &&
              ((context.structuralBias == BIAS_BULLISH && bearishCandle) ||
               (context.structuralBias == BIAS_BEARISH && bullishCandle)))
         context.volumeDivergesFromTrend = true;

      if(context.bullishBreakoutConfirmed)
         context.knowledgeScore += context.volumeConfirmsTrend ? 18.0 : 10.0;
      if(context.bearishBreakoutConfirmed)
         context.knowledgeScore -= context.volumeConfirmsTrend ? 18.0 : 10.0;
      if(context.volumeConfirmsTrend && context.structuralBias == BIAS_BULLISH)
         context.knowledgeScore += 8.0;
      if(context.volumeConfirmsTrend && context.structuralBias == BIAS_BEARISH)
         context.knowledgeScore -= 8.0;
      if(context.volumeDivergesFromTrend)
         context.knowledgeScore *= 0.50;

      const int bullishTFs = context.alignedBullishTFs;
      const int bearishTFs = context.alignedBearishTFs;
      context.mtfConflict = bullishTFs > 0 && bearishTFs > 0;
      context.higherTFConflict =
         ((context.d1Score > 0.0 || context.h4Score > 0.0) && context.h1Score < 0.0) ||
         ((context.d1Score < 0.0 || context.h4Score < 0.0) && context.h1Score > 0.0);

      const int totalTFs = bullishTFs + bearishTFs + context.neutralTFCount;
      if(totalTFs > 0)
         context.mtfAlignmentScore = Clamp(
            (double)MathMax(bullishTFs, bearishTFs) / totalTFs,
            0.0,
            1.0
         );

      PrintFormat(
         "[MARKET_EVIDENCE][Cycle=%I64u] "
         "Support=%.8f | Resistance=%.8f | Location=%s | "
         "BullishBreakout=%s | BearishBreakout=%s | "
         "VolumeConfirms=%s | VolumeDiverges=%s | KnowledgeScore=%.2f | "
         "D1=%.2f | H4=%.2f | H1=%.2f | M15=%.2f | M5=%.2f | "
         "BullishTFs=%d | BearishTFs=%d | NeutralTFs=%d | "
         "MTFConflict=%s | HigherTFConflict=%s | MTFAlignment=%.3f",
         context.cycleId,
         context.nearestSupport,
         context.nearestResistance,
         EnumToString(context.priceLocation),
         context.bullishBreakoutConfirmed ? "true" : "false",
         context.bearishBreakoutConfirmed ? "true" : "false",
         context.volumeConfirmsTrend ? "true" : "false",
         context.volumeDivergesFromTrend ? "true" : "false",
         context.knowledgeScore,
         context.d1Score,
         context.h4Score,
         context.h1Score,
         context.m15Score,
         context.m5Score,
         bullishTFs,
         bearishTFs,
         context.neutralTFCount,
         context.mtfConflict ? "true" : "false",
         context.higherTFConflict ? "true" : "false",
         context.mtfAlignmentScore
      );

      return true;
   }
};

#endif