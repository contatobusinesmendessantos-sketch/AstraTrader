//+------------------------------------------------------------------+
//| WyckoffEngine.mqh                                                |
//| Astra Trader AI                                                  |
//+------------------------------------------------------------------+
#ifndef ASTRA_WYCKOFFENGINE_MQH
#define ASTRA_WYCKOFFENGINE_MQH

#include <AstraTrader\Analysis\AnalysisContext.mqh>

class WyckoffEngine
{
private:

   double m_minValidScore;
   double m_strongScore;
   double m_extremeScore;

   double Clamp(
      const double value,
      const double minimum,
      const double maximum
   ) const
   {
      return MathMax(
         minimum,
         MathMin(
            maximum,
            value
         )
      );
   }


   bool HasVolume(
      const AnalysisContext &ctx
   ) const
   {
      if(ctx.volume > 0)
         return true;

      if(ctx.tickVolume > 0)
         return true;

      return false;
   }


   double CalculateRange(
      const AnalysisContext &ctx
   ) const
   {
      double range =
         ctx.high -
         ctx.low;

      if(range > 0.0)
         return range;

      if(ctx.currentBar.time > 0)
      {
         range =
            ctx.currentBar.high -
            ctx.currentBar.low;

         if(range > 0.0)
            return range;
      }

      if(ctx.atr > 0.0)
         return ctx.atr;

      if(ctx.point > 0.0)
         return ctx.point;

      return 0.0;
   }


   double CalculateBody(
      const AnalysisContext &ctx
   ) const
   {
      double body =
         MathAbs(
            ctx.close -
            ctx.open
         );

      if(body > 0.0)
         return body;

      if(ctx.currentBar.time > 0)
      {
         return MathAbs(
            ctx.currentBar.close -
            ctx.currentBar.open
         );
      }

      return 0.0;
   }


   bool IsBullishCandle(
      const AnalysisContext &ctx
   ) const
   {
      if(ctx.close > ctx.open)
         return true;

      if(
         ctx.currentBar.time > 0 &&
         ctx.currentBar.close > ctx.currentBar.open
      )
         return true;

      return false;
   }


   bool IsBearishCandle(
      const AnalysisContext &ctx
   ) const
   {
      if(ctx.close < ctx.open)
         return true;

      if(
         ctx.currentBar.time > 0 &&
         ctx.currentBar.close < ctx.currentBar.open
      )
         return true;

      return false;
   }


   bool HasValidPriceData(
      const AnalysisContext &ctx
   ) const
   {
      if(ctx.symbol == "")
         return false;

      double referencePrice =
         ctx.price;

      if(referencePrice <= 0.0)
         referencePrice = ctx.close;

      if(
         referencePrice <= 0.0 &&
         ctx.currentBar.time > 0
      )
         referencePrice =
            ctx.currentBar.close;

      if(referencePrice <= 0.0)
         return false;

      double high = ctx.high;
      double low  = ctx.low;

      if(
         (high <= 0.0 || low <= 0.0) &&
         ctx.currentBar.time > 0
      )
      {
         high = ctx.currentBar.high;
         low  = ctx.currentBar.low;
      }

      if(high <= 0.0 || low <= 0.0)
         return false;

      if(high < low)
         return false;

      return true;
   }


   //===============================================================
   // SPRING
   //
   // Requer evento de sell-side liquidity.
   //===============================================================
   double EvaluateSpring(
      const AnalysisContext &ctx,
      bool &detected
   ) const
   {
      detected = false;

      double score = 0.0;

      if(
         ctx.liquiditySweep &&
         ctx.sellSideLiquidityTaken
      )
         score += 35.0;
      else
      if(
         ctx.liquidityGrab &&
         ctx.sellSideLiquidityTaken
      )
         score += 30.0;
      else
      if(ctx.sellSideLiquidityTaken)
         score += 15.0;

      if(IsBullishCandle(ctx))
         score += 15.0;

      if(ctx.structuralBias == BIAS_BULLISH)
         score += 20.0;

      if(ctx.absorptionScore > 0.0)
      {
         score += Clamp(
            ctx.absorptionScore * 0.20,
            0.0,
            15.0
         );
      }

      if(ctx.institutionalFlowScore > 0.0)
      {
         score += Clamp(
            ctx.institutionalFlowScore * 0.10,
            0.0,
            10.0
         );
      }

      score =
         Clamp(
            score,
            0.0,
            100.0
         );

      detected =
         (
            score >= m_strongScore &&
            ctx.sellSideLiquidityTaken
         );

      return score;
   }


   //===============================================================
   // UPTHRUST
   //
   // Requer evento de buy-side liquidity.
   //===============================================================
   double EvaluateUpthrust(
      const AnalysisContext &ctx,
      bool &detected
   ) const
   {
      detected = false;

      double score = 0.0;

      if(
         ctx.liquiditySweep &&
         ctx.buySideLiquidityTaken
      )
         score += 35.0;
      else
      if(
         ctx.liquidityGrab &&
         ctx.buySideLiquidityTaken
      )
         score += 30.0;
      else
      if(ctx.buySideLiquidityTaken)
         score += 15.0;

      if(IsBearishCandle(ctx))
         score += 15.0;

      if(ctx.structuralBias == BIAS_BEARISH)
         score += 20.0;

      if(ctx.absorptionScore < 0.0)
      {
         score += Clamp(
            MathAbs(ctx.absorptionScore) * 0.20,
            0.0,
            15.0
         );
      }

      if(ctx.institutionalFlowScore < 0.0)
      {
         score += Clamp(
            MathAbs(ctx.institutionalFlowScore) * 0.10,
            0.0,
            10.0
         );
      }

      score =
         Clamp(
            score,
            0.0,
            100.0
         );

      detected =
         (
            score >= m_strongScore &&
            ctx.buySideLiquidityTaken
         );

      return score;
   }


   double EvaluateAccumulation(
      const AnalysisContext &ctx,
      const double springScore
   ) const
   {
      double score = 0.0;

      if(ctx.regime == REGIME_RANGE)
         score += 20.0;

      if(ctx.regime == REGIME_CONTRACTION)
         score += 10.0;

      if(ctx.structuralBias == BIAS_BULLISH)
         score += 15.0;

      if(
         ctx.sellSideLiquidityTaken &&
         (
            ctx.liquiditySweep ||
            ctx.liquidityGrab
         )
      )
         score += 15.0;

      if(ctx.absorptionScore > 0.0)
      {
         score += Clamp(
            ctx.absorptionScore * 0.20,
            0.0,
            15.0
         );
      }

      if(ctx.institutionalFlowScore > 0.0)
      {
         score += Clamp(
            ctx.institutionalFlowScore * 0.10,
            0.0,
            10.0
         );
      }

      if(
         ctx.orderBlock &&
         ctx.orderBlockValid &&
         ctx.structuralBias == BIAS_BULLISH
      )
         score += 10.0;

      if(ctx.bullishFVG)
         score += 5.0;

      score += Clamp(
         springScore * 0.20,
         0.0,
         20.0
      );

      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   double EvaluateDistribution(
      const AnalysisContext &ctx,
      const double upthrustScore
   ) const
   {
      double score = 0.0;

      if(ctx.regime == REGIME_RANGE)
         score += 20.0;

      if(ctx.regime == REGIME_CONTRACTION)
         score += 10.0;

      if(ctx.structuralBias == BIAS_BEARISH)
         score += 15.0;

      if(
         ctx.buySideLiquidityTaken &&
         (
            ctx.liquiditySweep ||
            ctx.liquidityGrab
         )
      )
         score += 15.0;

      if(ctx.absorptionScore < 0.0)
      {
         score += Clamp(
            MathAbs(ctx.absorptionScore) * 0.20,
            0.0,
            15.0
         );
      }

      if(ctx.institutionalFlowScore < 0.0)
      {
         score += Clamp(
            MathAbs(ctx.institutionalFlowScore) * 0.10,
            0.0,
            10.0
         );
      }

      if(
         ctx.orderBlock &&
         ctx.orderBlockValid &&
         ctx.structuralBias == BIAS_BEARISH
      )
         score += 10.0;

      if(ctx.bearishFVG)
         score += 5.0;

      score += Clamp(
         upthrustScore * 0.20,
         0.0,
         20.0
      );

      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   double EvaluateSOS(
      const AnalysisContext &ctx
   ) const
   {
      double score = 0.0;

      if(ctx.structuralBias == BIAS_BULLISH)
         score += 25.0;

      if(IsBullishCandle(ctx))
         score += 10.0;

      // Após absorção/varredura de sell-side,
      // uma recuperação bullish é compatível com SOS.
      if(ctx.sellSideLiquidityTaken)
         score += 10.0;

      if(ctx.institutionalFlowScore > 0.0)
      {
         score += Clamp(
            ctx.institutionalFlowScore * 0.15,
            0.0,
            15.0
         );
      }

      if(ctx.absorptionScore > 0.0)
      {
         score += Clamp(
            ctx.absorptionScore * 0.15,
            0.0,
            10.0
         );
      }

      if(
         ctx.smartMoneyScore > 0.0 &&
         ctx.structuralBias == BIAS_BULLISH
      )
      {
         score += Clamp(
            ctx.smartMoneyScore * 0.10,
            0.0,
            10.0
         );
      }

      if(HasVolume(ctx))
         score += 5.0;

      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   double EvaluateSOW(
      const AnalysisContext &ctx
   ) const
   {
      double score = 0.0;

      if(ctx.structuralBias == BIAS_BEARISH)
         score += 25.0;

      if(IsBearishCandle(ctx))
         score += 10.0;

      // Após absorção/varredura de buy-side,
      // uma reversão bearish é compatível com SOW.
      if(ctx.buySideLiquidityTaken)
         score += 10.0;

      if(ctx.institutionalFlowScore < 0.0)
      {
         score += Clamp(
            MathAbs(ctx.institutionalFlowScore) * 0.15,
            0.0,
            15.0
         );
      }

      if(ctx.absorptionScore < 0.0)
      {
         score += Clamp(
            MathAbs(ctx.absorptionScore) * 0.15,
            0.0,
            10.0
         );
      }

      if(
         ctx.smartMoneyScore > 0.0 &&
         ctx.structuralBias == BIAS_BEARISH
      )
      {
         score += Clamp(
            ctx.smartMoneyScore * 0.10,
            0.0,
            10.0
         );
      }

      if(HasVolume(ctx))
         score += 5.0;

      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   ENUM_WYCKOFF_PHASE DeterminePhase(
      const AnalysisContext &ctx,
      const double accumulationScore,
      const double distributionScore,
      const double sosScore,
      const double sowScore,
      const bool springDetected,
      const bool upthrustDetected
   ) const
   {
      if(
         sosScore >= m_strongScore &&
         ctx.structuralBias == BIAS_BULLISH
      )
         return WYCKOFF_SOS;

      if(
         sowScore >= m_strongScore &&
         ctx.structuralBias == BIAS_BEARISH
      )
         return WYCKOFF_SOW;

      if(
         springDetected &&
         accumulationScore >= distributionScore
      )
         return WYCKOFF_ACCUMULATION;

      if(
         upthrustDetected &&
         distributionScore >= accumulationScore
      )
         return WYCKOFF_DISTRIBUTION;

      if(
         accumulationScore >= m_strongScore &&
         accumulationScore > distributionScore
      )
         return WYCKOFF_ACCUMULATION;

      if(
         distributionScore >= m_strongScore &&
         distributionScore > accumulationScore
      )
         return WYCKOFF_DISTRIBUTION;

      return WYCKOFF_NONE;
   }


   double CalculateFinalScore(
      const ENUM_WYCKOFF_PHASE phase,
      const double accumulationScore,
      const double distributionScore,
      const double sosScore,
      const double sowScore
   ) const
   {
      double score = 0.0;

      switch(phase)
      {
         case WYCKOFF_ACCUMULATION:
            score = accumulationScore;
            break;

         case WYCKOFF_SOS:
            score = sosScore;
            break;

         case WYCKOFF_DISTRIBUTION:
            score = distributionScore;
            break;

         case WYCKOFF_SOW:
            score = sowScore;
            break;

         default:
            score =
               MathMax(
                  accumulationScore,
                  distributionScore
               );
            break;
      }

      return Clamp(
         score,
         0.0,
         100.0
      );
   }


public:

   WyckoffEngine()
   {
      m_minValidScore = 50.0;
      m_strongScore   = 65.0;
      m_extremeScore  = 80.0;
   }


   void Reset()
   {
      m_minValidScore = 50.0;
      m_strongScore   = 65.0;
      m_extremeScore  = 80.0;
   }


   bool Analyze(
      AnalysisContext &ctx
   )
   {
      //==============================================================
      // RESET DA PRÓPRIA CAMADA
      //==============================================================

      ctx.wyckoffPhase      = WYCKOFF_NONE;
      ctx.wyckoffScore      = 0.0;
      ctx.accumulationScore = 0.0;
      ctx.distributionScore = 0.0;

      ctx.springDetected   = false;
      ctx.upthrustDetected = false;
      ctx.sosDetected      = false;
      ctx.sowDetected      = false;

      ctx.wyckoffState =
         LAYER_NEUTRAL;


      //==============================================================
      // VALIDATE CONTEXT
      //==============================================================

      if(!ctx.Validate())
      {
         ctx.wyckoffState =
            LAYER_INVALID;

         return false;
      }


      if(!HasValidPriceData(ctx))
      {
         ctx.wyckoffState =
            LAYER_INVALID;

         return false;
      }


      double range =
         CalculateRange(ctx);

      if(range <= 0.0)
      {
         ctx.wyckoffState =
            LAYER_INVALID;

         return false;
      }


      double body =
         CalculateBody(ctx);

      bool volumePresent =
         HasVolume(ctx);


      //==============================================================
      // EVENTS
      //==============================================================

      bool spring = false;
      double springScore =
         EvaluateSpring(
            ctx,
            spring
         );

      bool upthrust = false;
      double upthrustScore =
         EvaluateUpthrust(
            ctx,
            upthrust
         );


      ctx.springDetected =
         spring;

      ctx.upthrustDetected =
         upthrust;


      //==============================================================
      // PHASE SCORES
      //==============================================================

      double accumulationScore =
         EvaluateAccumulation(
            ctx,
            springScore
         );

      double distributionScore =
         EvaluateDistribution(
            ctx,
            upthrustScore
         );

      double sosScore =
         EvaluateSOS(ctx);

      double sowScore =
         EvaluateSOW(ctx);


      //==============================================================
      // CANDLE CONFIRMATION
      //==============================================================

      double bodyRatio = 0.0;

      if(range > 0.0)
      {
         bodyRatio =
            Clamp(
               body / range,
               0.0,
               1.0
            );
      }

      if(
         bodyRatio > 0.60 &&
         IsBullishCandle(ctx)
      )
         sosScore += 5.0;

      if(
         bodyRatio > 0.60 &&
         IsBearishCandle(ctx)
      )
         sowScore += 5.0;


      //==============================================================
      // PENALTY DE AUSÊNCIA DE VOLUME
      //==============================================================

      if(!volumePresent)
      {
         accumulationScore -= 5.0;
         distributionScore -= 5.0;
         sosScore          -= 5.0;
         sowScore          -= 5.0;
      }


      accumulationScore =
         Clamp(
            accumulationScore,
            0.0,
            100.0
         );

      distributionScore =
         Clamp(
            distributionScore,
            0.0,
            100.0
         );

      sosScore =
         Clamp(
            sosScore,
            0.0,
            100.0
         );

      sowScore =
         Clamp(
            sowScore,
            0.0,
            100.0
         );


      //==============================================================
      // DETECÇÃO
      //==============================================================

      ctx.sosDetected =
         (
            sosScore >= m_strongScore &&
            ctx.structuralBias == BIAS_BULLISH
         );

      ctx.sowDetected =
         (
            sowScore >= m_strongScore &&
            ctx.structuralBias == BIAS_BEARISH
         );


      //==============================================================
      // PHASE
      //==============================================================

      ENUM_WYCKOFF_PHASE phase =
         DeterminePhase(
            ctx,
            accumulationScore,
            distributionScore,
            sosScore,
            sowScore,
            ctx.springDetected,
            ctx.upthrustDetected
         );


      double finalScore =
         CalculateFinalScore(
            phase,
            accumulationScore,
            distributionScore,
            sosScore,
            sowScore
         );


      //==============================================================
      // WRITE CONTEXT
      //==============================================================

      ctx.accumulationScore =
         accumulationScore;

      ctx.distributionScore =
         distributionScore;

      ctx.wyckoffPhase =
         phase;

      ctx.wyckoffScore =
         finalScore;


      //==============================================================
      // ESTADO
      //==============================================================

      if(
         phase != WYCKOFF_NONE &&
         finalScore >= m_minValidScore
      )
      {
         ctx.wyckoffState =
            LAYER_VALID;
      }
      else
      {
         ctx.wyckoffState =
            LAYER_NEUTRAL;
      }


      PrintFormat(
         "[WyckoffEngine] %s %s | Phase=%s | Score=%.2f | "
         "Accum=%.2f | Distrib=%.2f | SOS=%.2f | SOW=%.2f | "
         "Spring=%s | Upthrust=%s",
         ctx.symbol,
         EnumToString(ctx.primaryTF),
         PhaseToString(ctx.wyckoffPhase),
         ctx.wyckoffScore,
         ctx.accumulationScore,
         ctx.distributionScore,
         sosScore,
         sowScore,
         ctx.springDetected ? "true" : "false",
         ctx.upthrustDetected ? "true" : "false"
      );

      return true;
   }


   ENUM_WYCKOFF_PHASE GetPhase(
      const AnalysisContext &ctx
   ) const
   {
      return ctx.wyckoffPhase;
   }


   double GetScore(
      const AnalysisContext &ctx
   ) const
   {
      return ctx.wyckoffScore;
   }


   double GetAccumulationScore(
      const AnalysisContext &ctx
   ) const
   {
      return ctx.accumulationScore;
   }


   double GetDistributionScore(
      const AnalysisContext &ctx
   ) const
   {
      return ctx.distributionScore;
   }


   bool IsSpring(
      const AnalysisContext &ctx
   ) const
   {
      return ctx.springDetected;
   }


   bool IsUpthrust(
      const AnalysisContext &ctx
   ) const
   {
      return ctx.upthrustDetected;
   }


   bool IsSOS(
      const AnalysisContext &ctx
   ) const
   {
      return ctx.sosDetected;
   }


   bool IsSOW(
      const AnalysisContext &ctx
   ) const
   {
      return ctx.sowDetected;
   }


   string PhaseToString(
      const ENUM_WYCKOFF_PHASE phase
   ) const
   {
      switch(phase)
      {
         case WYCKOFF_ACCUMULATION:
            return "ACCUMULATION";

         case WYCKOFF_SOS:
            return "SOS";

         case WYCKOFF_DISTRIBUTION:
            return "DISTRIBUTION";

         case WYCKOFF_SOW:
            return "SOW";

         default:
            return "NONE";
      }
   }
};

#endif // ASTRA_WYCKOFFENGINE_MQH
