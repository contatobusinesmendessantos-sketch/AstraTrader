//+------------------------------------------------------------------+
//| MarketRegimeEngine.mqh                                           |
//| Astra Trader AI                                                  |
//+------------------------------------------------------------------+
#ifndef ASTRA_MARKETREGIMEENGINE_MQH
#define ASTRA_MARKETREGIMEENGINE_MQH

#property strict

#include <AstraTrader\Analysis\AnalysisContext.mqh>

class MarketRegimeEngine
{
private:

   double m_minTrendScore;
   double m_minExpansionScore;
   double m_minRangeScore;


   double Clamp100(
      const double value
   ) const
   {
      if(value < 0.0)
         return 0.0;

      if(value > 100.0)
         return 100.0;

      return value;
   }


   double Absolute(
      const double value
   ) const
   {
      return MathAbs(value);
   }


   double CalculateTrendStrength(
      const AnalysisContext &context
   ) const
   {
      double score = 0.0;

      score +=
         Absolute(
            context.structuralScore
         ) * 0.35;

      // Estrutura bullish
      if(
         context.structuralBias == BIAS_BULLISH
      )
      {
         if(context.higherHigh)
            score += 20.0;

         if(context.higherLow)
            score += 20.0;
      }

      // Estrutura bearish
      if(
         context.structuralBias == BIAS_BEARISH
      )
      {
         if(context.lowerHigh)
            score += 20.0;

         if(context.lowerLow)
            score += 20.0;
      }

      if(context.bos)
         score += 15.0;

      if(context.choch)
         score += 5.0;

      return Clamp100(score);
   }


   double CalculateRangeStrength(
      const AnalysisContext &context
   ) const
   {
      double score = 0.0;

      if(!context.bos)
         score += 25.0;

      if(!context.choch)
         score += 10.0;

      int bullishStructure = 0;
      int bearishStructure = 0;

      if(context.higherHigh)
         bullishStructure++;

      if(context.higherLow)
         bullishStructure++;

      if(context.lowerHigh)
         bearishStructure++;

      if(context.lowerLow)
         bearishStructure++;

      if(
         bullishStructure > 0 &&
         bearishStructure > 0
      )
      {
         score += 25.0;
      }

      if(
         bullishStructure == 0 &&
         bearishStructure == 0
      )
      {
         score += 25.0;
      }

      if(context.structuralBias == BIAS_NEUTRAL)
         score += 20.0;

      if(context.volatilityContracting)
         score += 10.0;

      return Clamp100(score);
   }


   double CalculateExpansionScore(
      const AnalysisContext &context
   ) const
   {
      double score = 0.0;

      if(context.bos)
         score += 30.0;

      if(context.choch)
         score += 10.0;

      // Usa o score normalizado da VolatilityEngine.
      if(context.volatilityScore > 0.0)
      {
         score +=
            Clamp100(
               context.volatilityScore
            ) * 0.30;
      }

      if(context.volatilityExpanding)
         score += 20.0;

      if(
         context.structuralBias != BIAS_NEUTRAL
      )
      {
         score +=
            Clamp100(
               Absolute(
                  context.structuralScore
               )
            ) * 0.10;
      }

      if(
         context.higherHigh &&
         context.higherLow &&
         context.structuralBias == BIAS_BULLISH
      )
         score += 5.0;

      if(
         context.lowerHigh &&
         context.lowerLow &&
         context.structuralBias == BIAS_BEARISH
      )
         score += 5.0;

      return Clamp100(score);
   }


   double CalculateContractionScore(
      const AnalysisContext &context
   ) const
   {
      double score = 0.0;

      if(!context.bos)
         score += 20.0;

      if(!context.choch)
         score += 10.0;

      if(context.volatilityContracting)
      {
         score += 35.0;
      }
      else
      if(context.volatilityScore < 0.0)
      {
         score +=
            Clamp100(
               MathAbs(context.volatilityScore)
            ) * 0.25;
      }

      double structural =
         Absolute(
            context.structuralScore
         );

      if(structural < 30.0)
         score += 25.0;
      else
      if(structural < 50.0)
         score += 15.0;

      if(context.rangeStrength >= 50.0)
         score += 10.0;

      return Clamp100(score);
   }


   ENUM_REGIME DetermineRegime(
      const AnalysisContext &context,
      const double trendStrength,
      const double rangeStrength,
      const double expansionScore,
      const double contractionScore
   ) const
   {
      //==============================================================
      // EXPANSION
      //==============================================================

      if(
         expansionScore >= m_minExpansionScore &&
         context.volatilityExpanding &&
         context.structuralBias != BIAS_NEUTRAL
      )
      {
         return REGIME_EXPANSION;
      }

      if(
         expansionScore >= 75.0 &&
         context.bos
      )
      {
         return REGIME_EXPANSION;
      }


      //==============================================================
      // TRANSITION
      //==============================================================

      if(context.choch)
         return REGIME_TRANSITION;


      //==============================================================
      // CONTRACTION
      //==============================================================

      if(
         contractionScore >= m_minExpansionScore &&
         context.volatilityContracting
      )
      {
         return REGIME_CONTRACTION;
      }


      //==============================================================
      // RANGE
      //==============================================================

      if(
         rangeStrength >= m_minRangeScore &&
         rangeStrength >= trendStrength &&
         rangeStrength >= expansionScore
      )
      {
         return REGIME_RANGE;
      }


      //==============================================================
      // TREND / EXPANSION SECUNDÁRIA
      //==============================================================

      if(
         trendStrength >= m_minTrendScore &&
         trendStrength > rangeStrength
      )
      {
         return REGIME_EXPANSION;
      }


      //==============================================================
      // FALLBACK
      //==============================================================

      return REGIME_RANGE;
   }


   ENUM_LAYER_STATE DetermineLayerState(
      const AnalysisContext &context,
      const ENUM_REGIME regimeValue,
      const double regimeScore
   ) const
   {
      if(context.symbol == "")
         return LAYER_INVALID;

      if(!context.contextValid)
         return LAYER_INVALID;

      if(regimeValue < REGIME_EXPANSION ||
         regimeValue > REGIME_TRANSITION)
         return LAYER_INVALID;

      if(regimeScore < 25.0)
         return LAYER_NEUTRAL;

      return LAYER_VALID;
   }


   double CalculateRegimeScore(
      const ENUM_REGIME regimeValue,
      const double trendStrength,
      const double rangeStrength,
      const double expansionScore,
      const double contractionScore
   ) const
   {
      switch(regimeValue)
      {
         case REGIME_EXPANSION:
            return Clamp100(
               MathMax(
                  trendStrength,
                  expansionScore
               )
            );

         case REGIME_CONTRACTION:
            return Clamp100(
               contractionScore
            );

         case REGIME_RANGE:
            return Clamp100(
               rangeStrength
            );

         case REGIME_TRANSITION:
         {
            double transitionScore =
               (
                  trendStrength +
                  expansionScore +
                  contractionScore
               ) / 3.0;

            if(transitionScore < 30.0)
               transitionScore = 30.0;

            return Clamp100(
               transitionScore
            );
         }
      }

      return 0.0;
   }


   void ResetLayer(
      AnalysisContext &context
   ) const
   {
      context.regime =
         REGIME_RANGE;

      context.regimeScore =
         0.0;

      context.trendStrength =
         0.0;

      context.rangeStrength =
         0.0;

      context.expansionScore =
         0.0;

      context.contractionScore =
         0.0;

      context.regimeState =
         LAYER_NEUTRAL;
   }


public:

   MarketRegimeEngine()
   {
      m_minTrendScore     = 60.0;
      m_minExpansionScore = 60.0;
      m_minRangeScore     = 60.0;
   }


   void SetMinTrendScore(
      const double value
   )
   {
      if(value < 0.0)
         return;

      m_minTrendScore =
         Clamp100(value);
   }


   void SetMinExpansionScore(
      const double value
   )
   {
      if(value < 0.0)
         return;

      m_minExpansionScore =
         Clamp100(value);
   }


   void SetMinRangeScore(
      const double value
   )
   {
      if(value < 0.0)
         return;

      m_minRangeScore =
         Clamp100(value);
   }


   double GetMinTrendScore() const
   {
      return m_minTrendScore;
   }


   double GetMinExpansionScore() const
   {
      return m_minExpansionScore;
   }


   double GetMinRangeScore() const
   {
      return m_minRangeScore;
   }


   bool Analyze(
      AnalysisContext &context
   )
   {
      ResetLayer(context);

      if(context.symbol == "")
      {
         context.regimeState =
            LAYER_INVALID;

         return false;
      }

      if(!context.contextValid)
      {
         context.regimeState =
            LAYER_INVALID;

         return false;
      }

      bool hasMarketData =
         context.marketDataReady &&
         context.marketDataBarCount >= 3;

      bool hasHistory =
         context.marketHistoryReady &&
         context.marketBarsCount >= 3;

      if(
         !hasMarketData &&
         !hasHistory
      )
      {
         context.regimeState =
            LAYER_INVALID;

         return false;
      }


      double trendStrength =
         CalculateTrendStrength(
            context
         );

      double rangeStrength =
         CalculateRangeStrength(
            context
         );

      double expansionScore =
         CalculateExpansionScore(
            context
         );

      double contractionScore =
         CalculateContractionScore(
            context
         );


      ENUM_REGIME detectedRegime =
         DetermineRegime(
            context,
            trendStrength,
            rangeStrength,
            expansionScore,
            contractionScore
         );


      double regimeScore =
         CalculateRegimeScore(
            detectedRegime,
            trendStrength,
            rangeStrength,
            expansionScore,
            contractionScore
         );


      context.trendStrength =
         Clamp100(
            trendStrength
         );

      context.rangeStrength =
         Clamp100(
            rangeStrength
         );

      context.expansionScore =
         Clamp100(
            expansionScore
         );

      context.contractionScore =
         Clamp100(
            contractionScore
         );

      context.regime =
         detectedRegime;

      context.regimeScore =
         Clamp100(
            regimeScore
         );


      context.regimeState =
         DetermineLayerState(
            context,
            detectedRegime,
            context.regimeScore
         );


      PrintFormat(
         "[MarketRegimeEngine] %s %s | "
         "Regime=%s | Score=%.2f | Trend=%.2f | Range=%.2f | "
         "Expansion=%.2f | Contraction=%.2f | VolScore=%.2f | "
         "VolExpanding=%s | VolContracting=%s | BOS=%s | CHOCH=%s",
         context.symbol,
         EnumToString(context.primaryTF),
         RegimeToString(detectedRegime),
         context.regimeScore,
         context.trendStrength,
         context.rangeStrength,
         context.expansionScore,
         context.contractionScore,
         context.volatilityScore,
         context.volatilityExpanding ? "true" : "false",
         context.volatilityContracting ? "true" : "false",
         context.bos ? "true" : "false",
         context.choch ? "true" : "false"
      );


      return (
         context.regimeState !=
         LAYER_INVALID
      );
   }


   bool Process(
      AnalysisContext &context
   )
   {
      return Analyze(context);
   }


   bool Update(
      AnalysisContext &context
   )
   {
      return Analyze(context);
   }


   bool IsValid(
      const AnalysisContext &context
   ) const
   {
      if(
         context.regimeState ==
         LAYER_INVALID
      )
         return false;

      if(context.regimeScore <= 0.0)
         return false;

      return true;
   }


   ENUM_REGIME GetRegime(
      const AnalysisContext &context
   ) const
   {
      return context.regime;
   }


   double GetRegimeScore(
      const AnalysisContext &context
   ) const
   {
      return context.regimeScore;
   }


   double GetTrendStrength(
      const AnalysisContext &context
   ) const
   {
      return context.trendStrength;
   }


   double GetRangeStrength(
      const AnalysisContext &context
   ) const
   {
      return context.rangeStrength;
   }


   double GetExpansionScore(
      const AnalysisContext &context
   ) const
   {
      return context.expansionScore;
   }


   double GetContractionScore(
      const AnalysisContext &context
   ) const
   {
      return context.contractionScore;
   }


   string RegimeToString(
      const ENUM_REGIME value
   ) const
   {
      switch(value)
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


   string GetStatus(
      const AnalysisContext &context
   ) const
   {
      switch(context.regimeState)
      {
         case LAYER_VALID:
            return "ANALYSIS_COMPLETE";

         case LAYER_INVALID:
            return "INVALID";

         case LAYER_NEUTRAL:
            return "NEUTRAL";
      }

      return "UNKNOWN";
   }
};

#endif // ASTRA_MARKETREGIMEENGINE_MQH
