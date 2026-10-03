//+------------------------------------------------------------------+
//| ElliottWaveEngine.mqh                                            |
//| Astra Trader AI                                                  |
//|                                                                  |
//| ESTÁGIO: ELLIOTT WAVE ANALYSIS                                   |
//|                                                                  |
//| CONTRATO TEMPORAL:                                               |
//|   [0] = atual                                                     |
//|   [1+] = candles fechados                                        |
//|                                                                  |
//| Toda inferência estrutural utiliza somente [1+].                 |
//+------------------------------------------------------------------+
#ifndef ASTRA_ELLIOTTWAVEENGINE_MQH
#define ASTRA_ELLIOTTWAVEENGINE_MQH

#include <AstraTrader\Analysis\AnalysisContext.mqh>


//+------------------------------------------------------------------+
//| ElliottWaveEngine                                                |
//+------------------------------------------------------------------+
class ElliottWaveEngine
{
private:

   double m_minConfidence;
   double m_strongConfidence;
   double m_extremeConfidence;

   bool   m_operational;
   string m_status;


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


   //=================================================================
   // CANDLE UTILITIES
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


   int CandleDirection(
      const MqlRates &bar
   ) const
   {
      if(bar.close > bar.open)
         return 1;

      if(bar.close < bar.open)
         return -1;

      return 0;
   }


   bool IsBullish(
      const MqlRates &bar
   ) const
   {
      return (
         bar.close >
         bar.open
      );
   }


   bool IsBearish(
      const MqlRates &bar
   ) const
   {
      return (
         bar.close <
         bar.open
      );
   }


   //=================================================================
   // HISTÓRICO FECHADO
   //=================================================================

   int GetClosedBarCount(
      const AnalysisContext &ctx
   ) const
   {
      const int total =
         ctx.GetMarketBarCount();

      if(total <= 1)
         return 0;

      return total - 1;
   }


   bool HasEnoughHistory(
      const AnalysisContext &ctx
   ) const
   {
      if(!ctx.marketHistoryReady)
         return false;

      return (
         GetClosedBarCount(ctx) >= 5
      );
   }


   //=================================================================
   // CONTAGEM BULLISH
   //
   // offset:
   //   1 = último fechado
   //=================================================================

   int CountBullish(
      const AnalysisContext &ctx,
      const int count
   ) const
   {
      const int closedCount =
         GetClosedBarCount(ctx);

      if(closedCount <= 0)
         return 0;

      const int limit =
         MathMin(
            count,
            closedCount
         );

      int bullish =
         0;

      for(int i = 1; i <= limit; i++)
      {
         if(
            IsBullish(
               ctx.marketBars[i]
            )
         )
         {
            bullish++;
         }
      }

      return bullish;
   }


   //=================================================================
   // CONTAGEM BEARISH
   //=================================================================

   int CountBearish(
      const AnalysisContext &ctx,
      const int count
   ) const
   {
      const int closedCount =
         GetClosedBarCount(ctx);

      if(closedCount <= 0)
         return 0;

      const int limit =
         MathMin(
            count,
            closedCount
         );

      int bearish =
         0;

      for(int i = 1; i <= limit; i++)
      {
         if(
            IsBearish(
               ctx.marketBars[i]
            )
         )
         {
            bearish++;
         }
      }

      return bearish;
   }


   //=================================================================
   // MUDANÇAS DE DIREÇÃO
   //=================================================================

   int CountDirectionChanges(
      const AnalysisContext &ctx,
      const int count
   ) const
   {
      const int closedCount =
         GetClosedBarCount(ctx);

      const int limit =
         MathMin(
            count,
            closedCount
         );

      if(limit < 2)
         return 0;


      int changes =
         0;

      int previousDirection =
         CandleDirection(
            ctx.marketBars[limit]
         );


      for(int i = limit - 1; i >= 1; i--)
      {
         const int currentDirection =
            CandleDirection(
               ctx.marketBars[i]
            );

         if(currentDirection == 0)
            continue;

         if(
            previousDirection != 0 &&
            currentDirection != previousDirection
         )
         {
            changes++;
         }

         previousDirection =
            currentDirection;
      }

      return changes;
   }


   //=================================================================
   // BODY/RANGE
   //=================================================================

   double CalculateBodyRatio(
      const AnalysisContext &ctx,
      const int count
   ) const
   {
      const int closedCount =
         GetClosedBarCount(ctx);

      const int limit =
         MathMin(
            count,
            closedCount
         );

      if(limit <= 0)
         return 0.0;


      double bodySum =
         0.0;

      double rangeSum =
         0.0;


      for(int i = 1; i <= limit; i++)
      {
         bodySum +=
            CandleBody(
               ctx.marketBars[i]
            );

         rangeSum +=
            CandleRange(
               ctx.marketBars[i]
            );
      }


      if(rangeSum <= 0.0)
         return 0.0;


      return Clamp(
         bodySum / rangeSum,
         0.0,
         1.0
      );
   }


   //=================================================================
   // RANGE HISTÓRICO FECHADO
   //=================================================================

   bool GetHistoricalRange(
      const AnalysisContext &ctx,
      const int count,
      double &highest,
      double &lowest
   ) const
   {
      const int closedCount =
         GetClosedBarCount(ctx);

      const int limit =
         MathMin(
            count,
            closedCount
         );

      if(limit <= 0)
         return false;


      highest =
         ctx.marketBars[1].high;

      lowest =
         ctx.marketBars[1].low;


      for(int i = 2; i <= limit; i++)
      {
         if(
            ctx.marketBars[i].high >
            highest
         )
         {
            highest =
               ctx.marketBars[i].high;
         }

         if(
            ctx.marketBars[i].low <
            lowest
         )
         {
            lowest =
               ctx.marketBars[i].low;
         }
      }


      if(
         highest <= 0.0 ||
         lowest <= 0.0 ||
         highest < lowest
      )
      {
         return false;
      }

      return true;
   }


   //=================================================================
   // POSIÇÃO DO PREÇO
   //=================================================================

   double PricePosition(
      const AnalysisContext &ctx,
      const int count
   ) const
   {
      double highest =
         0.0;

      double lowest =
         0.0;


      if(!GetHistoricalRange(
            ctx,
            count,
            highest,
            lowest
         ))
      {
         return 0.5;
      }


      const double range =
         highest -
         lowest;

      if(range <= 0.0)
         return 0.5;


      const double price =
         ctx.marketBars[1].close;


      return Clamp(
         (
            price -
            lowest
         ) / range,
         0.0,
         1.0
      );
   }


   //=================================================================
   // IMPULSO
   //=================================================================

   double EvaluateImpulse(
      const AnalysisContext &ctx
   ) const
   {
      const int count =
         MathMin(
            10,
            GetClosedBarCount(ctx)
         );

      if(count < 5)
         return 0.0;


      double score =
         0.0;


      const int bullish =
         CountBullish(
            ctx,
            count
         );

      const int bearish =
         CountBearish(
            ctx,
            count
         );


      const double bodyRatio =
         CalculateBodyRatio(
            ctx,
            count
         );


      if(
         bullish >= 6 ||
         bearish >= 6
      )
      {
         score += 25.0;
      }
      else
      if(
         bullish >= 5 ||
         bearish >= 5
      )
      {
         score += 15.0;
      }


      if(bodyRatio >= 0.60)
         score += 25.0;
      else
      if(bodyRatio >= 0.45)
         score += 15.0;


      const double oldestClose =
         ctx.marketBars[count].close;

      const double newestClose =
         ctx.marketBars[1].close;


      const double totalRange =
         MathAbs(
            ctx.marketBars[1].high -
            ctx.marketBars[count].low
         );


      if(totalRange > 0.0)
      {
         const double displacement =
            MathAbs(
               newestClose -
               oldestClose
            ) /
            totalRange;


         if(displacement >= 0.60)
            score += 25.0;
         else
         if(displacement >= 0.35)
            score += 15.0;
      }


      const int changes =
         CountDirectionChanges(
            ctx,
            count
         );


      if(changes <= 2)
         score += 15.0;
      else
      if(changes == 3)
         score += 8.0;


      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   //=================================================================
   // CORREÇÃO
   //=================================================================

   double EvaluateCorrection(
      const AnalysisContext &ctx
   ) const
   {
      const int count =
         MathMin(
            10,
            GetClosedBarCount(ctx)
         );

      if(count < 5)
         return 0.0;


      double score =
         0.0;


      const int changes =
         CountDirectionChanges(
            ctx,
            count
         );


      const double bodyRatio =
         CalculateBodyRatio(
            ctx,
            count
         );


      if(changes >= 4)
         score += 30.0;
      else
      if(changes >= 3)
         score += 20.0;
      else
      if(changes >= 2)
         score += 10.0;


      if(bodyRatio < 0.35)
         score += 30.0;
      else
      if(bodyRatio < 0.45)
         score += 20.0;


      const double position =
         PricePosition(
            ctx,
            count
         );


      if(
         position > 0.20 &&
         position < 0.80
      )
      {
         score += 20.0;
      }


      const int bullish =
         CountBullish(
            ctx,
            count
         );

      const int bearish =
         CountBearish(
            ctx,
            count
         );


      if(
         MathAbs(
            bullish -
            bearish
         ) <= 3
      )
      {
         score += 20.0;
      }


      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   //=================================================================
   // WAVE 3
   //=================================================================

   double EvaluateWave3(
      const AnalysisContext &ctx
   ) const
   {
      const int count =
         MathMin(
            8,
            GetClosedBarCount(ctx)
         );

      if(count < 5)
         return 0.0;


      double score =
         0.0;


      const double bodyRatio =
         CalculateBodyRatio(
            ctx,
            count
         );


      if(bodyRatio >= 0.60)
         score += 25.0;
      else
      if(bodyRatio >= 0.45)
         score += 15.0;


      const int bullish =
         CountBullish(
            ctx,
            count
         );

      const int bearish =
         CountBearish(
            ctx,
            count
         );


      if(
         bullish >= 6 ||
         bearish >= 6
      )
      {
         score += 25.0;
      }
      else
      if(
         bullish >= 5 ||
         bearish >= 5
      )
      {
         score += 15.0;
      }


      const double firstPrice =
         ctx.marketBars[count].close;

      const double lastPrice =
         ctx.marketBars[1].close;


      const double movement =
         MathAbs(
            lastPrice -
            firstPrice
         );


      if(ctx.atr > 0.0)
      {
         const double atrMultiple =
            movement /
            ctx.atr;


         if(atrMultiple >= 2.5)
            score += 35.0;
         else
         if(atrMultiple >= 1.5)
            score += 20.0;
         else
         if(atrMultiple >= 1.0)
            score += 10.0;
      }


      if(ctx.volatilityExpanding)
         score += 10.0;


      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   //=================================================================
   // WAVE 5
   //=================================================================

   double EvaluateWave5(
      const AnalysisContext &ctx
   ) const
   {
      const int count =
         MathMin(
            6,
            GetClosedBarCount(ctx)
         );

      if(count < 5)
         return 0.0;


      double score =
         0.0;


      const double bodyRatio =
         CalculateBodyRatio(
            ctx,
            count
         );


      if(
         bodyRatio >= 0.40 &&
         bodyRatio <= 0.65
      )
      {
         score += 20.0;
      }


      if(ctx.momentumDivergence != 0)
         score += 25.0;


      if(ctx.momentumAccelerationScore < 0.0)
         score += 10.0;


      if(ctx.volatilityContracting)
         score += 15.0;


      if(
         ctx.structuralBias ==
         BIAS_BULLISH ||
         ctx.structuralBias ==
         BIAS_BEARISH
      )
      {
         score += 15.0;
      }


      if(ctx.bos)
         score += 15.0;


      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   //=================================================================
   // WAVE 1
   //=================================================================

   double EvaluateWave1(
      const AnalysisContext &ctx
   ) const
   {
      double score =
         0.0;


      if(ctx.bos)
         score += 25.0;

      if(ctx.choch)
         score += 20.0;

      if(ctx.structuralBias != BIAS_NEUTRAL)
         score += 20.0;

      if(ctx.institutionalFlowScore != 0.0)
         score += 15.0;

      if(ctx.orderBlock)
         score += 10.0;

      if(ctx.fairValueGap)
         score += 10.0;


      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   //=================================================================
   // WAVE A
   //=================================================================

   double EvaluateWaveA(
      const AnalysisContext &ctx
   ) const
   {
      double score =
         0.0;


      if(ctx.structuralBias != BIAS_NEUTRAL)
         score += 15.0;

      if(ctx.choch)
         score += 25.0;

      if(ctx.bos)
         score += 15.0;

      if(ctx.momentumDivergence != 0)
         score += 15.0;

      if(ctx.momentumAccelerationScore < 0.0)
         score += 10.0;

      if(ctx.volatilityContracting)
         score += 10.0;

      if(ctx.patternScore > 0.0)
         score += 10.0;


      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   //=================================================================
   // WAVE B
   //=================================================================

   double EvaluateWaveB(
      const AnalysisContext &ctx
   ) const
   {
      double score =
         0.0;


      const int count =
         MathMin(
            10,
            GetClosedBarCount(ctx)
         );


      const double position =
         PricePosition(
            ctx,
            count
         );


      if(
         position > 0.30 &&
         position < 0.70
      )
      {
         score += 20.0;
      }


      if(ctx.structuralBias != BIAS_NEUTRAL)
         score += 15.0;

      if(ctx.momentumDivergence != 0)
         score += 20.0;

      if(ctx.momentumAccelerationScore < 0.0)
         score += 10.0;

      if(ctx.patternScore > 0.0)
         score += 10.0;

      if(ctx.liquidityGrab)
         score += 15.0;

      if(ctx.orderBlock)
         score += 10.0;


      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   //=================================================================
   // WAVE C
   //=================================================================

   double EvaluateWaveC(
      const AnalysisContext &ctx
   ) const
   {
      double score =
         0.0;


      if(ctx.bos)
         score += 20.0;

      if(ctx.choch)
         score += 15.0;

      if(ctx.structuralBias != BIAS_NEUTRAL)
         score += 20.0;

      if(ctx.volatilityExpanding)
         score += 15.0;

      if(ctx.institutionalFlowScore != 0.0)
         score += 10.0;

      if(ctx.fairValueGap)
         score += 10.0;

      if(ctx.orderBlock)
         score += 10.0;


      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   //=================================================================
   // CORREÇÃO COMPLEXA
   //=================================================================

   double EvaluateComplexCorrection(
      const AnalysisContext &ctx
   ) const
   {
      const int count =
         MathMin(
            15,
            GetClosedBarCount(ctx)
         );

      if(count < 7)
         return 0.0;


      double score =
         0.0;


      const int changes =
         CountDirectionChanges(
            ctx,
            count
         );


      if(changes >= 5)
         score += 30.0;
      else
      if(changes >= 4)
         score += 20.0;


      const double bodyRatio =
         CalculateBodyRatio(
            ctx,
            count
         );


      if(bodyRatio < 0.40)
         score += 20.0;


      if(ctx.regime == REGIME_RANGE)
         score += 15.0;

      if(ctx.regime == REGIME_CONTRACTION)
         score += 10.0;

      if(ctx.volatilityContracting)
         score += 10.0;

      if(ctx.liquidityGrab)
         score += 10.0;

      if(ctx.choch)
         score += 5.0;


      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   //=================================================================
   // CONFIANÇA
   //=================================================================

   double CalculateConfidence(
      const double waveScore,
      const double impulseScore,
      const double correctionScore
   ) const
   {
      double confidence =
         waveScore;


      if(
         waveScore >= 60.0 &&
         (
            impulseScore >= 60.0 ||
            correctionScore >= 60.0
         )
      )
      {
         confidence +=
            5.0;
      }


      return Clamp(
         confidence,
         0.0,
         100.0
      );
   }


   //=================================================================
   // ESCREVE CONTEXTO
   //=================================================================

   void WriteContext(
      AnalysisContext &ctx,
      const ENUM_ELLIOTT_WAVE wave,
      const double score,
      const double confidence,
      const double complexScore,
      const double waveBScore,
      const double waveCScore
   ) const
   {
      ctx.elliottWave =
         wave;

      ctx.elliottScore =
         Clamp(
            score,
            0.0,
            100.0
         );

      ctx.waveConfidence =
         Clamp(
            confidence / 100.0,
            0.0,
            1.0
         );


      ctx.waveBDetected =
         (
            wave ==
            ELLIOTT_CORRECTIVE_B &&
            waveBScore >=
            m_minConfidence
         );


      ctx.waveCDetected =
         (
            wave ==
            ELLIOTT_CORRECTIVE_C &&
            waveCScore >=
            m_minConfidence
         );


      ctx.complexCorrection =
         (
            complexScore >=
            m_strongConfidence
         );


      ctx.waveXDetected =
         (
            wave ==
            ELLIOTT_WAVE_X &&
            complexScore >=
            m_strongConfidence
         );


      if(wave == ELLIOTT_NONE)
      {
         ctx.elliottState =
            LAYER_NEUTRAL;

         return;
      }


      if(score >= m_minConfidence)
      {
         ctx.elliottState =
            LAYER_VALID;
      }
      else
      {
         ctx.elliottState =
            LAYER_NEUTRAL;
      }
   }


public:

   //=================================================================
   // CONSTRUCTOR
   //=================================================================

   ElliottWaveEngine()
   {
      m_minConfidence =
         50.0;

      m_strongConfidence =
         65.0;

      m_extremeConfidence =
         80.0;

      m_operational =
         true;

      m_status =
         "INITIALIZED";
   }


   //=================================================================
   // RESET
   //=================================================================

   void Reset()
   {
      m_minConfidence =
         50.0;

      m_strongConfidence =
         65.0;

      m_extremeConfidence =
         80.0;

      m_operational =
         true;

      m_status =
         "READY";
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

         ctx.elliottState =
            LAYER_INVALID;

         return false;
      }


      //==============================================================
      // RESET CAMPOS
      //==============================================================

      ctx.elliottWave =
         ELLIOTT_NONE;

      ctx.elliottScore =
         0.0;

      ctx.waveBDetected =
         false;

      ctx.waveCDetected =
         false;

      ctx.complexCorrection =
         false;

      ctx.waveXDetected =
         false;

      ctx.waveConfidence =
         0.0;

      ctx.elliottState =
         LAYER_NEUTRAL;


      //==============================================================
      // VALIDACAO
      //==============================================================

      if(ctx.symbol == "")
      {
         ctx.elliottState =
            LAYER_INVALID;

         m_status =
            "INVALID_SYMBOL";

         return false;
      }


      if(!HasEnoughHistory(ctx))
      {
         ctx.elliottState =
            LAYER_INVALID;

         m_status =
            "INSUFFICIENT_MARKET_HISTORY";

         return false;
      }


      const int totalClosedBars =
         GetClosedBarCount(ctx);

      if(totalClosedBars < 5)
      {
         ctx.elliottState =
            LAYER_INVALID;

         m_status =
            "INSUFFICIENT_CLOSED_BARS";

         return false;
      }


      //==============================================================
      // SCORES
      //==============================================================

      const double impulseScore =
         EvaluateImpulse(ctx);

      const double correctionScore =
         EvaluateCorrection(ctx);

      const double wave1Score =
         EvaluateWave1(ctx);

      const double wave3Score =
         EvaluateWave3(ctx);

      const double wave5Score =
         EvaluateWave5(ctx);

      const double waveAScore =
         EvaluateWaveA(ctx);

      const double waveBScore =
         EvaluateWaveB(ctx);

      const double waveCScore =
         EvaluateWaveC(ctx);

      const double complexScore =
         EvaluateComplexCorrection(ctx);


      //==============================================================
      // CLASSIFICAÇÃO
      //
      // Primeiro hipóteses de maior especificidade.
      //==============================================================

      ENUM_ELLIOTT_WAVE wave =
         ELLIOTT_NONE;

      double bestScore =
         0.0;


      if(
         complexScore >= m_strongConfidence &&
         complexScore > bestScore
      )
      {
         wave =
            ELLIOTT_WAVE_X;

         bestScore =
            complexScore;
      }


      if(
         waveCScore >= m_strongConfidence &&
         waveCScore > bestScore
      )
      {
         wave =
            ELLIOTT_CORRECTIVE_C;

         bestScore =
            waveCScore;
      }


      if(
         waveBScore >= m_strongConfidence &&
         waveBScore > bestScore
      )
      {
         wave =
            ELLIOTT_CORRECTIVE_B;

         bestScore =
            waveBScore;
      }


      if(
         waveAScore >= m_strongConfidence &&
         waveAScore > bestScore
      )
      {
         wave =
            ELLIOTT_CORRECTIVE_A;

         bestScore =
            waveAScore;
      }


      if(
         wave3Score >= m_strongConfidence &&
         wave3Score > bestScore
      )
      {
         wave =
            ELLIOTT_IMPULSE_3;

         bestScore =
            wave3Score;
      }


      if(
         wave5Score >= m_strongConfidence &&
         wave5Score > bestScore
      )
      {
         wave =
            ELLIOTT_IMPULSE_5;

         bestScore =
            wave5Score;
      }


      if(
         wave1Score >= m_strongConfidence &&
         wave1Score > bestScore
      )
      {
         wave =
            ELLIOTT_IMPULSE_1;

         bestScore =
            wave1Score;
      }


      //==============================================================
      // FALLBACK
      //==============================================================

      if(wave == ELLIOTT_NONE)
      {
         bestScore =
            MathMax(
               impulseScore,
               correctionScore
            );


         if(bestScore >= m_minConfidence)
         {
            if(correctionScore > impulseScore)
            {
               if(
                  waveCScore >= waveBScore &&
                  waveCScore >= waveAScore
               )
               {
                  wave =
                     ELLIOTT_CORRECTIVE_C;
               }
               else
               if(waveBScore >= waveAScore)
               {
                  wave =
                     ELLIOTT_CORRECTIVE_B;
               }
               else
               {
                  wave =
                     ELLIOTT_CORRECTIVE_A;
               }
            }
            else
            {
               if(
                  wave3Score >= wave5Score &&
                  wave3Score >= wave1Score
               )
               {
                  wave =
                     ELLIOTT_IMPULSE_3;
               }
               else
               if(wave5Score >= wave1Score)
               {
                  wave =
                     ELLIOTT_IMPULSE_5;
               }
               else
               {
                  wave =
                     ELLIOTT_IMPULSE_1;
               }
            }
         }
      }


      //==============================================================
      // CONSISTÊNCIA
      //==============================================================

      if(
         wave == ELLIOTT_IMPULSE_1 ||
         wave == ELLIOTT_IMPULSE_3 ||
         wave == ELLIOTT_IMPULSE_5
      )
      {
         bestScore =
            MathMax(
               bestScore,
               impulseScore
            );
      }


      if(
         wave == ELLIOTT_CORRECTIVE_A ||
         wave == ELLIOTT_CORRECTIVE_B ||
         wave == ELLIOTT_CORRECTIVE_C ||
         wave == ELLIOTT_WAVE_X
      )
      {
         bestScore =
            MathMax(
               bestScore,
               correctionScore
            );
      }


      //==============================================================
      // CONFIANÇA
      //==============================================================

      const double confidence =
         CalculateConfidence(
            bestScore,
            impulseScore,
            correctionScore
         );


      //==============================================================
      // CONTEXTO
      //==============================================================

      WriteContext(
         ctx,
         wave,
         bestScore,
         confidence,
         complexScore,
         waveBScore,
         waveCScore
      );


      if(wave == ELLIOTT_NONE)
         m_status =
            "NO_CLEAR_WAVE";
      else
         m_status =
            "ANALYSIS_COMPLETE";


      return true;
   }


   //=================================================================
   // STATUS
   //=================================================================

   bool IsOperational() const
   {
      return m_operational;
   }


   string GetStatus() const
   {
      return m_status;
   }


   ENUM_ELLIOTT_WAVE GetWave(
      const AnalysisContext &ctx
   ) const
   {
      return ctx.elliottWave;
   }


   double GetScore(
      const AnalysisContext &ctx
   ) const
   {
      return ctx.elliottScore;
   }


   double GetConfidence(
      const AnalysisContext &ctx
   ) const
   {
      return ctx.waveConfidence;
   }


   bool IsWaveB(
      const AnalysisContext &ctx
   ) const
   {
      return ctx.waveBDetected;
   }


   bool IsWaveC(
      const AnalysisContext &ctx
   ) const
   {
      return ctx.waveCDetected;
   }


   bool IsComplexCorrection(
      const AnalysisContext &ctx
   ) const
   {
      return ctx.complexCorrection;
   }


   bool IsWaveX(
      const AnalysisContext &ctx
   ) const
   {
      return ctx.waveXDetected;
   }


   string WaveToString(
      const ENUM_ELLIOTT_WAVE wave
   ) const
   {
      switch(wave)
      {
         case ELLIOTT_IMPULSE_1:
            return "IMPULSE_1";

         case ELLIOTT_IMPULSE_3:
            return "IMPULSE_3";

         case ELLIOTT_IMPULSE_5:
            return "IMPULSE_5";

         case ELLIOTT_CORRECTIVE_A:
            return "CORRECTIVE_A";

         case ELLIOTT_CORRECTIVE_B:
            return "CORRECTIVE_B";

         case ELLIOTT_CORRECTIVE_C:
            return "CORRECTIVE_C";

         case ELLIOTT_WAVE_X:
            return "WAVE_X";

         case ELLIOTT_NONE:
            return "NONE";
      }

      return "UNKNOWN";
   }


   string GetWaveString(
      const AnalysisContext &ctx
   ) const
   {
      return WaveToString(
         ctx.elliottWave
      );
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_ELLIOTTWAVEENGINE_MQH
