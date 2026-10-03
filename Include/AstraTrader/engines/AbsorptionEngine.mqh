//+------------------------------------------------------------------+
//| AbsorptionEngine.mqh                                             |
//| Astra Trader AI                                                  |
//|                                                                  |
//| ESTÁGIO: ABSORPTION / INSTITUTIONAL FLOW                        |
//|                                                                  |
//| CONTRATO TEMPORAL:                                               |
//|   [0] = atual                                                     |
//|   [1] = último fechado                                           |
//|   [2+] = fechados anteriores                                     |
//|                                                                  |
//| Toda análise de absorção utiliza somente candles fechados.        |
//+------------------------------------------------------------------+
#ifndef ASTRA_ABSORPTIONENGINE_MQH
#define ASTRA_ABSORPTIONENGINE_MQH

#property strict

#include <AstraTrader\Analysis\AnalysisContext.mqh>


#define ASTRA_ABS_MIN_BODY_RATIO       0.15
#define ASTRA_ABS_MAX_BODY_RATIO       0.45
#define ASTRA_ABS_MIN_REJECTION_RATIO  0.30

#define ASTRA_ABS_STRONG_VOLUME_RATIO  1.20
#define ASTRA_ABS_EXTREME_VOLUME_RATIO 1.50

#define ASTRA_ABS_MIN_SCORE            50.0
#define ASTRA_ABS_STRONG_SCORE         65.0
#define ASTRA_ABS_EXTREME_SCORE        80.0


//+------------------------------------------------------------------+
//| AbsorptionEngine                                                 |
//+------------------------------------------------------------------+
class AbsorptionEngine
{
private:

   string m_status;
   bool   m_operational;

   double m_absorptionScore;
   double m_institutionalFlowScore;

   double m_bullishAbsorptionScore;
   double m_bearishAbsorptionScore;

   double m_volumePressure;
   double m_bullishPressure;
   double m_bearishPressure;

   bool   m_bullishAbsorption;
   bool   m_bearishAbsorption;


   //=================================================================
   // CLAMP
   //=================================================================

   double Clamp(
      const double value,
      const double minimum,
      const double maximum
   ) const
   {
      if(value < minimum)
         return minimum;

      if(value > maximum)
         return maximum;

      return value;
   }


   double ClampScore(
      const double value
   ) const
   {
      return Clamp(
         value,
         -100.0,
         100.0
      );
   }


   //=================================================================
   // CANDLE
   //=================================================================

   double CandleBody(
      const MqlRates &bar
   ) const
   {
      return MathAbs(
         bar.close -
         bar.open
      );
   }


   double CandleRange(
      const MqlRates &bar
   ) const
   {
      return MathMax(
         0.0,
         bar.high -
         bar.low
      );
   }


   double BodyRatio(
      const MqlRates &bar
   ) const
   {
      const double range =
         CandleRange(bar);

      if(range <= 0.0)
         return 0.0;

      return Clamp(
         CandleBody(bar) / range,
         0.0,
         1.0
      );
   }


   double UpperWick(
      const MqlRates &bar
   ) const
   {
      return MathMax(
         0.0,
         bar.high -
         MathMax(
            bar.open,
            bar.close
         )
      );
   }


   double LowerWick(
      const MqlRates &bar
   ) const
   {
      return MathMax(
         0.0,
         MathMin(
            bar.open,
            bar.close
         ) -
         bar.low
      );
   }


   double UpperWickRatio(
      const MqlRates &bar
   ) const
   {
      const double range =
         CandleRange(bar);

      if(range <= 0.0)
         return 0.0;

      return Clamp(
         UpperWick(bar) / range,
         0.0,
         1.0
      );
   }


   double LowerWickRatio(
      const MqlRates &bar
   ) const
   {
      const double range =
         CandleRange(bar);

      if(range <= 0.0)
         return 0.0;

      return Clamp(
         LowerWick(bar) / range,
         0.0,
         1.0
      );
   }


   double CloseLocation(
      const MqlRates &bar
   ) const
   {
      const double range =
         CandleRange(bar);

      if(range <= 0.0)
         return 0.5;

      return Clamp(
         (
            bar.close -
            bar.low
         ) / range,
         0.0,
         1.0
      );
   }


   //=================================================================
   // VOLUME
   //=================================================================

   double GetBarVolume(
      const MqlRates &bar
   ) const
   {
      if(bar.real_volume > 0)
         return (double)bar.real_volume;

      if(bar.tick_volume > 0)
         return (double)bar.tick_volume;

      return 0.0;
   }


   //=================================================================
   // VOLUME RATIO
   //
   // currentClosedBar = marketBars[1]
   // baseline         = marketBars[2+]
   //=================================================================

   double CalculateVolumeRatio(
      const AnalysisContext &ctx
   ) const
   {
      const int count =
         ctx.GetMarketBarCount();

      if(count < 3)
         return 0.0;


      const double currentVolume =
         GetBarVolume(
            ctx.marketBars[1]
         );

      if(currentVolume <= 0.0)
         return 0.0;


      double sum =
         0.0;

      int validBars =
         0;


      const int maxBars =
         MathMin(
            count - 2,
            20
         );


      for(int i = 2; i < 2 + maxBars; i++)
      {
         const double volume =
            GetBarVolume(
               ctx.marketBars[i]
            );

         if(volume <= 0.0)
            continue;

         sum +=
            volume;

         validBars++;
      }


      if(validBars <= 0)
         return 0.0;


      const double averageVolume =
         sum /
         (double)validBars;


      if(averageVolume <= 0.0)
         return 0.0;


      return (
         currentVolume /
         averageVolume
      );
   }


   //=================================================================
   // PRESSÃO DA VELA
   //=================================================================

   double CalculateCandlePressure(
      const MqlRates &bar
   ) const
   {
      const double location =
         CloseLocation(
            bar
         );

      return ClampScore(
         (
            location -
            0.50
         ) * 200.0
      );
   }


   //=================================================================
   // PRESSÃO DE VOLUME
   //=================================================================

   double CalculateVolumePressure(
      const MqlRates &bar,
      const double volumeRatio
   ) const
   {
      const double candlePressure =
         CalculateCandlePressure(
            bar
         );

      if(volumeRatio <= 0.0)
      {
         return ClampScore(
            candlePressure * 0.50
         );
      }


      const double volumeFactor =
         Clamp(
            volumeRatio,
            0.0,
            2.0
         ) / 2.0;


      return ClampScore(
         candlePressure *
         (
            0.50 +
            volumeFactor
         )
      );
   }


   //=================================================================
   // BULLISH ABSORPTION
   //=================================================================

   double EvaluateBullishAbsorption(
      const MqlRates &bar,
      const double volumeRatio
   ) const
   {
      double score =
         0.0;


      const double bodyRatio =
         BodyRatio(bar);

      const double lowerWickRatio =
         LowerWickRatio(bar);

      const double closeLocation =
         CloseLocation(bar);


      if(volumeRatio >= ASTRA_ABS_EXTREME_VOLUME_RATIO)
         score += 30.0;
      else
      if(volumeRatio >= ASTRA_ABS_STRONG_VOLUME_RATIO)
         score += 20.0;
      else
      if(volumeRatio > 1.0)
         score += 10.0;


      if(
         bodyRatio >= ASTRA_ABS_MIN_BODY_RATIO &&
         bodyRatio <= ASTRA_ABS_MAX_BODY_RATIO
      )
      {
         score += 20.0;
      }


      if(lowerWickRatio >= 0.50)
         score += 25.0;
      else
      if(lowerWickRatio >= ASTRA_ABS_MIN_REJECTION_RATIO)
         score += 15.0;


      if(closeLocation >= 0.70)
         score += 20.0;
      else
      if(closeLocation >= 0.60)
         score += 10.0;


      if(bar.close > bar.open)
         score += 10.0;


      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   //=================================================================
   // BEARISH ABSORPTION
   //=================================================================

   double EvaluateBearishAbsorption(
      const MqlRates &bar,
      const double volumeRatio
   ) const
   {
      double score =
         0.0;


      const double bodyRatio =
         BodyRatio(bar);

      const double upperWickRatio =
         UpperWickRatio(bar);

      const double closeLocation =
         CloseLocation(bar);


      if(volumeRatio >= ASTRA_ABS_EXTREME_VOLUME_RATIO)
         score += 30.0;
      else
      if(volumeRatio >= ASTRA_ABS_STRONG_VOLUME_RATIO)
         score += 20.0;
      else
      if(volumeRatio > 1.0)
         score += 10.0;


      if(
         bodyRatio >= ASTRA_ABS_MIN_BODY_RATIO &&
         bodyRatio <= ASTRA_ABS_MAX_BODY_RATIO
      )
      {
         score += 20.0;
      }


      if(upperWickRatio >= 0.50)
         score += 25.0;
      else
      if(upperWickRatio >= ASTRA_ABS_MIN_REJECTION_RATIO)
         score += 15.0;


      if(closeLocation <= 0.30)
         score += 20.0;
      else
      if(closeLocation <= 0.40)
         score += 10.0;


      if(bar.close < bar.open)
         score += 10.0;


      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   //=================================================================
   // FLUXO INSTITUCIONAL HEURÍSTICO
   //=================================================================

   double CalculateInstitutionalFlow(
      const AnalysisContext &ctx,
      const MqlRates &bar,
      const double volumeRatio,
      const double bullishAbsorption,
      const double bearishAbsorption
   ) const
   {
      double flow =
         (
            bullishAbsorption -
            bearishAbsorption
         ) * 0.45;


      const double volumePressure =
         CalculateVolumePressure(
            bar,
            volumeRatio
         );


      flow +=
         volumePressure *
         0.35;


      if(ctx.structuralBias == BIAS_BULLISH)
         flow += 10.0;

      if(ctx.structuralBias == BIAS_BEARISH)
         flow -= 10.0;


      if(ctx.buySideLiquidityTaken)
         flow -= 5.0;

      if(ctx.sellSideLiquidityTaken)
         flow += 5.0;


      return ClampScore(
         flow
      );
   }


   //=================================================================
   // RESET
   //=================================================================

   void ResetInternal()
   {
      m_status =
         "RESET";

      m_operational =
         false;

      m_absorptionScore =
         0.0;

      m_institutionalFlowScore =
         0.0;

      m_bullishAbsorptionScore =
         0.0;

      m_bearishAbsorptionScore =
         0.0;

      m_volumePressure =
         0.0;

      m_bullishPressure =
         0.0;

      m_bearishPressure =
         0.0;

      m_bullishAbsorption =
         false;

      m_bearishAbsorption =
         false;
   }


public:

   //=================================================================
   // CONSTRUTOR
   //=================================================================

   AbsorptionEngine()
   {
      ResetInternal();

      m_operational =
         true;

      m_status =
         "INITIALIZED";
   }


   ~AbsorptionEngine()
   {
      m_operational =
         false;
   }


   //=================================================================
   // RESET
   //=================================================================

   void Reset()
   {
      ResetInternal();

      m_operational =
         true;

      m_status =
         "READY";
   }


   //=================================================================
   // STATUS
   //=================================================================

   bool IsSystemOperational() const
   {
      return m_operational;
   }


   string GetStatus() const
   {
      return m_status;
   }


   //=================================================================
   // ANALYZE
   //=================================================================

   bool Analyze(
      AnalysisContext &ctx
   )
   {
      if(!m_operational)
      {
         m_status =
            "ENGINE_NOT_OPERATIONAL";

         return false;
      }


      ResetInternal();

      m_operational =
         true;


      if(ctx.symbol == "")
      {
         m_status =
            "INVALID_SYMBOL";

         return false;
      }


      if(!ctx.HasMarketHistory())
      {
         m_status =
            "MARKET_HISTORY_NOT_READY";

         ctx.absorptionScore =
            0.0;

         ctx.institutionalFlowScore =
            0.0;

         return false;
      }


      if(ctx.GetMarketBarCount() < 3)
      {
         m_status =
            "INSUFFICIENT_HISTORY";

         ctx.absorptionScore =
            0.0;

         ctx.institutionalFlowScore =
            0.0;

         return false;
      }


      //==============================================================
      // SOMENTE ÚLTIMO CANDLE FECHADO
      //==============================================================

      MqlRates closedBar;

      if(
         !ctx.GetMarketBar(
            1,
            closedBar
         )
      )
      {
         m_status =
            "CLOSED_BAR_NOT_AVAILABLE";

         return false;
      }


      if(
         closedBar.time <= 0 ||
         closedBar.high <= 0.0 ||
         closedBar.low <= 0.0 ||
         closedBar.high < closedBar.low
      )
      {
         m_status =
            "INVALID_CLOSED_BAR";

         return false;
      }


      //==============================================================
      // VOLUME
      //==============================================================

      const double volumeRatio =
         CalculateVolumeRatio(
            ctx
         );


      //==============================================================
      // SCORES
      //==============================================================

      m_bullishAbsorptionScore =
         EvaluateBullishAbsorption(
            closedBar,
            volumeRatio
         );

      m_bearishAbsorptionScore =
         EvaluateBearishAbsorption(
            closedBar,
            volumeRatio
         );


      m_volumePressure =
         CalculateVolumePressure(
            closedBar,
            volumeRatio
         );


      m_bullishPressure =
         Clamp(
            MathMax(
               0.0,
               m_volumePressure
            ),
            0.0,
            100.0
         );

      m_bearishPressure =
         Clamp(
            MathMax(
               0.0,
               -m_volumePressure
            ),
            0.0,
            100.0
         );


      //==============================================================
      // DETECÇÃO
      //==============================================================

      m_bullishAbsorption =
         (
            m_bullishAbsorptionScore >=
            ASTRA_ABS_STRONG_SCORE
         );

      m_bearishAbsorption =
         (
            m_bearishAbsorptionScore >=
            ASTRA_ABS_STRONG_SCORE
         );


      //==============================================================
      // SCORE ASSINADO
      //==============================================================

      double absorptionScore =
         m_bullishAbsorptionScore -
         m_bearishAbsorptionScore;


      if(
         m_bullishAbsorptionScore >= ASTRA_ABS_STRONG_SCORE &&
         m_bearishAbsorptionScore >= ASTRA_ABS_STRONG_SCORE
      )
      {
         absorptionScore *=
            0.50;
      }


      m_absorptionScore =
         ClampScore(
            absorptionScore
         );


      //==============================================================
      // FLUXO INSTITUCIONAL
      //==============================================================

      m_institutionalFlowScore =
         CalculateInstitutionalFlow(
            ctx,
            closedBar,
            volumeRatio,
            m_bullishAbsorptionScore,
            m_bearishAbsorptionScore
         );


      //==============================================================
      // CONTEXTO
      //==============================================================

      ctx.absorptionScore =
         m_absorptionScore;

      ctx.institutionalFlowScore =
         m_institutionalFlowScore;


      //==============================================================
      // SMART MONEY
      //==============================================================

      if(
         MathAbs(m_absorptionScore) >=
         ASTRA_ABS_STRONG_SCORE ||
         MathAbs(m_institutionalFlowScore) >=
         ASTRA_ABS_STRONG_SCORE
      )
      {
         ctx.smartMoneyState =
            LAYER_VALID;
      }
      else
      if(ctx.smartMoneyState != LAYER_VALID)
      {
         ctx.smartMoneyState =
            LAYER_NEUTRAL;
      }


      m_status =
         "ANALYSIS_COMPLETE";

      return true;
   }


   //=================================================================
   // GETTERS
   //=================================================================

   double GetAbsorptionScore() const
   {
      return m_absorptionScore;
   }

   double GetInstitutionalFlowScore() const
   {
      return m_institutionalFlowScore;
   }

   double GetBullishAbsorptionScore() const
   {
      return m_bullishAbsorptionScore;
   }

   double GetBearishAbsorptionScore() const
   {
      return m_bearishAbsorptionScore;
   }

   double GetVolumePressure() const
   {
      return m_volumePressure;
   }

   double GetBullishPressure() const
   {
      return m_bullishPressure;
   }

   double GetBearishPressure() const
   {
      return m_bearishPressure;
   }

   bool HasBullishAbsorption() const
   {
      return m_bullishAbsorption;
   }

   bool HasBearishAbsorption() const
   {
      return m_bearishAbsorption;
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_ABSORPTIONENGINE_MQH
