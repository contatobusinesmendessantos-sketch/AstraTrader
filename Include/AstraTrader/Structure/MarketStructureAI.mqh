//+------------------------------------------------------------------+
//| MarketStructureAI.mqh                                            |
//| Astra Trader AI                                                  |
//|                                                                  |
//| ESTÁGIO 5 - VALIDAÇÃO HEURÍSTICA DA ESTRUTURA                   |
//|                                                                  |
//| Responsabilidades:                                               |
//| - validar qualidade estrutural                                   |
//| - validar BOS / CHOCH já produzidos                              |
//| - avaliar qualidade dos candles                                  |
//| - avaliar consistência estrutural                                |
//| - produzir confiança estrutural                                  |
//|                                                                  |
//| REGRAS:                                                          |
//| - NÃO executa CopyRates()                                        |
//| - NÃO executa SymbolSelect()                                     |
//| - consome exclusivamente AnalysisContext                         |
//| - NÃO cria BUY/SELL                                               |
//| - NÃO calcula risco                                               |
//| - NÃO executa ordens                                             |
//+------------------------------------------------------------------+
#ifndef ASTRA_MARKETSTRUCTUREAI_MQH
#define ASTRA_MARKETSTRUCTUREAI_MQH

#property strict

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>


//==================================================================
// CONFIGURAÇÃO
//==================================================================

#define ASTRA_MSA_MIN_CONFIDENCE       50.0
#define ASTRA_MSA_STRONG_CONFIDENCE    70.0
#define ASTRA_MSA_VERY_STRONG          85.0


//+------------------------------------------------------------------+
//| MarketStructureAI                                                |
//+------------------------------------------------------------------+
class MarketStructureAI
{
private:

   bool   m_operational;
   string m_status;

   double m_confidence;
   double m_qualityScore;

   bool   m_validated;
   bool   m_strongStructure;


   //===============================================================
   // CLAMP
   //===============================================================

   double Clamp(
      const double value
   ) const
   {
      if(value < 0.0)
         return 0.0;

      if(value > 100.0)
         return 100.0;

      return value;
   }


   //===============================================================
   // RESET
   //===============================================================

   void ResetInternal()
   {
      m_confidence =
         0.0;

      m_qualityScore =
         0.0;

      m_validated =
         false;

      m_strongStructure =
         false;

      m_status =
         "RESET";
   }


   //===============================================================
   // CANDLE BODY
   //===============================================================

   double CandleBody(
      const MqlRates &candle
   ) const
   {
      return MathAbs(
         candle.close -
         candle.open
      );
   }


   //===============================================================
   // CANDLE RANGE
   //===============================================================

   double CandleRange(
      const MqlRates &candle
   ) const
   {
      double range =
         candle.high -
         candle.low;

      if(range <= 0.0)
         return 0.0;

      return range;
   }


   //===============================================================
   // BODY/RANGE RATIO
   //===============================================================

   double BodyRatio(
      const MqlRates &candle
   ) const
   {
      double range =
         CandleRange(
            candle
         );

      if(range <= 0.0)
         return 0.0;

      return Clamp(
         (
            CandleBody(candle) /
            range
         ) * 100.0
      );
   }


   //===============================================================
   // VALIDA UMA BARRA
   //===============================================================

   bool IsValidBar(
      const MqlRates &bar
   ) const
   {
      if(bar.time <= 0)
         return false;

      if(bar.open <= 0.0)
         return false;

      if(bar.high <= 0.0)
         return false;

      if(bar.low <= 0.0)
         return false;

      if(bar.close <= 0.0)
         return false;

      if(bar.high < bar.low)
         return false;

      if(bar.high < bar.open)
         return false;

      if(bar.high < bar.close)
         return false;

      if(bar.low > bar.open)
         return false;

      if(bar.low > bar.close)
         return false;

      return true;
   }


   //===============================================================
   // QUALIDADE DOS CANDLES
   //
   // Utiliza exclusivamente:
   //
   // context.marketBars[]
   //===============================================================

   double EvaluatePriceQuality(
      const AnalysisContext &context,
      const int count
   ) const
   {
      if(count < 5)
         return 0.0;


      double averageBody =
         0.0;

      double averageRange =
         0.0;

      int bullish =
         0;

      int bearish =
         0;

      int valid =
         0;


      for(int i = 0;
          i < count;
          i++)
      {
         //==========================================================
         // CORREÇÃO MQL5:
         //
         // Não usamos referência local.
         //
         // MQL5 não aceita:
         //
         // const MqlRates &bar = ...
         //
         //==========================================================

         MqlRates bar =
            context.marketBars[i];


         if(!IsValidBar(bar))
            continue;


         double range =
            CandleRange(
               bar
            );


         if(range <= 0.0)
            continue;


         averageBody +=
            CandleBody(
               bar
            );

         averageRange +=
            range;


         if(
            bar.close >
            bar.open
         )
         {
            bullish++;
         }
         else
         if(
            bar.close <
            bar.open
         )
         {
            bearish++;
         }


         valid++;
      }


      if(valid <= 0)
         return 0.0;


      averageBody /=
         (double)valid;

      averageRange /=
         (double)valid;


      double score =
         0.0;


      //=============================================================
      // QUALIDADE DOS CANDLES
      //=============================================================

      if(averageRange > 0.0)
      {
         double ratio =
            averageBody /
            averageRange;


         if(ratio >= 0.30)
            score += 20.0;

         if(ratio >= 0.45)
            score += 10.0;

         if(ratio >= 0.60)
            score += 10.0;
      }


      //=============================================================
      // CONSISTÊNCIA DIRECIONAL
      //=============================================================

      int dominant =
         MathMax(
            bullish,
            bearish
         );


      if(
         dominant >=
         (int)MathCeil(
            (double)valid *
            0.55
         )
      )
      {
         score += 15.0;
      }


      if(
         dominant >=
         (int)MathCeil(
            (double)valid *
            0.65
         )
      )
      {
         score += 10.0;
      }


      if(
         dominant >=
         (int)MathCeil(
            (double)valid *
            0.75
         )
      )
      {
         score += 5.0;
      }


      //=============================================================
      // IMPULSO RECENTE
      //=============================================================

      if(valid >= 2)
      {
         MqlRates recentBar =
            context.marketBars[0];

         MqlRates previousBar =
            context.marketBars[1];


         double recentBody =
            CandleBody(
               recentBar
            );

         double previousBody =
            CandleBody(
               previousBar
            );


         if(previousBody > 0.0)
         {
            double impulse =
               recentBody /
               previousBody;


            if(impulse >= 1.10)
               score += 10.0;

            if(impulse >= 1.50)
               score += 10.0;
         }
      }


      return Clamp(
         score
      );
   }


   //===============================================================
   // QUALIDADE DOS SWINGS
   //
   // Não recalcula estrutura via CopyRates().
   // Usa exclusivamente o resultado da
   // MarketStructureEngine no AnalysisContext.
   //===============================================================

   double EvaluateSwingQuality(
      const AnalysisContext &context,
      const int count
   ) const
   {
      if(count < 5)
         return 0.0;


      double score =
         0.0;


      //=============================================================
      // ESTRUTURA BULLISH
      //=============================================================

      if(
         context.higherHigh &&
         context.higherLow
      )
      {
         score += 45.0;
      }
      else
      if(
         context.higherHigh ||
         context.higherLow
      )
      {
         score += 20.0;
      }


      //=============================================================
      // ESTRUTURA BEARISH
      //=============================================================

      if(
         context.lowerHigh &&
         context.lowerLow
      )
      {
         score += 45.0;
      }
      else
      if(
         context.lowerHigh ||
         context.lowerLow
      )
      {
         score += 20.0;
      }


      //=============================================================
      // BOS
      //=============================================================

      if(context.bos)
         score += 20.0;


      //=============================================================
      // CHOCH
      //=============================================================

      if(context.choch)
         score += 15.0;


      //=============================================================
      // COERÊNCIA COM BIAS
      //=============================================================

      if(
         context.structuralBias ==
         BIAS_BULLISH
      )
      {
         if(
            context.higherHigh ||
            context.higherLow
         )
         {
            score += 10.0;
         }
      }
      else
      if(
         context.structuralBias ==
         BIAS_BEARISH
      )
      {
         if(
            context.lowerHigh ||
            context.lowerLow
         )
         {
            score += 10.0;
         }
      }


      return Clamp(
         score
      );
   }


   //===============================================================
   // CONSISTÊNCIA DIRECIONAL
   //===============================================================

   double EvaluateConsistency(
      const AnalysisContext &context,
      const int count
   ) const
   {
      if(count < 5)
         return 0.0;


      int transitions =
         0;

      int previousDirection =
         0;


      for(int i = count - 1;
          i >= 0;
          i--)
      {
         MqlRates bar =
            context.marketBars[i];


         if(!IsValidBar(bar))
            continue;


         int direction =
            0;


         if(
            bar.close >
            bar.open
         )
         {
            direction =
               1;
         }
         else
         if(
            bar.close <
            bar.open
         )
         {
            direction =
               -1;
         }


         if(direction == 0)
            continue;


         if(
            previousDirection != 0 &&
            direction != previousDirection
         )
         {
            transitions++;
         }


         previousDirection =
            direction;
      }


      double score =
         0.0;


      if(transitions <= 2)
         score += 40.0;
      else
      if(transitions <= 4)
         score += 25.0;
      else
      if(transitions <= 6)
         score += 10.0;


      if(
         transitions >=
         count - 2
      )
      {
         score -= 20.0;
      }


      return Clamp(
         score
      );
   }


   //===============================================================
   // CONSISTÊNCIA DO BIAS
   //===============================================================

   double EvaluateBiasConsistency(
      const AnalysisContext &context
   ) const
   {
      double score =
         0.0;


      //=============================================================
      // BULLISH
      //=============================================================

      if(
         context.structuralBias ==
         BIAS_BULLISH
      )
      {
         if(
            context.higherHigh ||
            context.higherLow
         )
         {
            score += 30.0;
         }


         if(context.bos)
            score += 20.0;


         if(
            context.lowerHigh ||
            context.lowerLow
         )
         {
            score -= 20.0;
         }
      }


      //=============================================================
      // BEARISH
      //=============================================================

      if(
         context.structuralBias ==
         BIAS_BEARISH
      )
      {
         if(
            context.lowerHigh ||
            context.lowerLow
         )
         {
            score += 30.0;
         }


         if(context.bos)
            score += 20.0;


         if(
            context.higherHigh ||
            context.higherLow
         )
         {
            score -= 20.0;
         }
      }


      //=============================================================
      // NEUTRAL
      //=============================================================

      if(
         context.structuralBias ==
         BIAS_NEUTRAL
      )
      {
         if(
            !context.higherHigh &&
            !context.higherLow &&
            !context.lowerHigh &&
            !context.lowerLow
         )
         {
            score += 25.0;
         }
      }


      return Clamp(
         score
      );
   }


public:

   //===============================================================
   // CONSTRUCTOR
   //===============================================================

   MarketStructureAI()
   {
      m_operational =
         true;

      ResetInternal();

      m_status =
         "INITIALIZED";
   }


   //===============================================================
   // DESTRUCTOR
   //===============================================================

   ~MarketStructureAI()
   {
      m_operational =
         false;
   }


   //===============================================================
   // RESET
   //===============================================================

   void Reset()
   {
      ResetInternal();

      m_operational =
         true;

      m_status =
         "READY";
   }


   //===============================================================
   // STATUS
   //===============================================================

   bool IsSystemOperational() const
   {
      return m_operational;
   }


   string GetStatus() const
   {
      return m_status;
   }


   //===============================================================
   // VALIDATE
   //
   // CONTRATO:
   //
   // - Não usa CopyRates()
   // - Não usa SymbolSelect()
   // - Não acessa histórico externo
   // - Usa somente AnalysisContext
   //===============================================================

   bool Validate(
      AnalysisContext &context
   )
   {
      if(!m_operational)
      {
         m_status =
            "ENGINE_NOT_OPERATIONAL";

         return false;
      }


      ResetInternal();


      //=============================================================
      // CONTEXTO
      //=============================================================

      if(!context.Validate())
      {
         m_status =
            "INVALID_CONTEXT";

         return false;
      }


      //=============================================================
      // SYMBOL
      //=============================================================

      if(context.symbol == "")
      {
         m_status =
            "INVALID_SYMBOL";

         return false;
      }


      //=============================================================
      // HISTÓRICO CENTRAL
      //=============================================================

      if(
         !context.marketHistoryReady ||
         context.marketBarsCount < 5 ||
         ArraySize(
            context.marketBars
         ) < 5
      )
      {
         m_status =
            "INSUFFICIENT_MARKET_HISTORY";

         return false;
      }


      //=============================================================
      // QUANTIDADE EFETIVA
      //=============================================================

      int count =
         MathMin(
            context.marketBarsCount,
            ArraySize(
               context.marketBars
            )
         );


      count =
         MathMin(
            count,
            20
         );


      if(count < 5)
      {
         m_status =
            "INSUFFICIENT_DATA";

         return false;
      }


      //=============================================================
      // VALIDAR HISTÓRICO
      //=============================================================

      for(int i = 0;
          i < count;
          i++)
      {
         MqlRates bar =
            context.marketBars[i];


         if(!IsValidBar(bar))
         {
            m_status =
               "INVALID_BAR_DATA";

            return false;
         }
      }


      //=============================================================
      // COMPONENTE 1
      //=============================================================

      double priceQuality =
         EvaluatePriceQuality(
            context,
            count
         );


      //=============================================================
      // COMPONENTE 2
      //=============================================================

      double swingQuality =
         EvaluateSwingQuality(
            context,
            count
         );


      //=============================================================
      // COMPONENTE 3
      //=============================================================

      double consistency =
         EvaluateConsistency(
            context,
            count
         );


      //=============================================================
      // COMPONENTE 4
      //=============================================================

      double biasConsistency =
         EvaluateBiasConsistency(
            context
         );


      //=============================================================
      // SCORE BASE
      //=============================================================

      m_qualityScore =
           priceQuality    * 0.30
         + swingQuality    * 0.35
         + consistency     * 0.15
         + biasConsistency * 0.20;


      m_qualityScore =
         Clamp(
            m_qualityScore
         );

      context.structureAIScore =
         m_qualityScore;


      //=============================================================
      // BÔNUS BOS
      //=============================================================

      if(
         context.bos &&
         context.structuralBias !=
         BIAS_NEUTRAL
      )
      {
         m_qualityScore +=
            5.0;
      }


      //=============================================================
      // BÔNUS CHOCH
      //=============================================================

      if(
         context.choch &&
         context.structuralBias !=
         BIAS_NEUTRAL
      )
      {
         m_qualityScore +=
            3.0;
      }


      m_qualityScore =
         Clamp(
            m_qualityScore
         );


      //=============================================================
      // CONFIANÇA
      //=============================================================

      m_confidence =
         m_qualityScore;


      //=============================================================
      // VALIDAÇÃO
      //=============================================================

      m_validated =
         (
            m_confidence >=
            ASTRA_MSA_MIN_CONFIDENCE
         );


      m_strongStructure =
         (
            m_confidence >=
            ASTRA_MSA_STRONG_CONFIDENCE
         );


      //=============================================================
      // STATUS
      //=============================================================

      if(
         m_confidence >=
         ASTRA_MSA_VERY_STRONG
      )
      {
         m_status =
            "VERY_STRONG_STRUCTURE";
      }
      else
      if(
         m_confidence >=
         ASTRA_MSA_STRONG_CONFIDENCE
      )
      {
         m_status =
            "STRONG_STRUCTURE";
      }
      else
      if(
         m_confidence >=
         ASTRA_MSA_MIN_CONFIDENCE
      )
      {
         m_status =
            "VALID_STRUCTURE";
      }
      else
      {
         m_status =
            "WEAK_STRUCTURE";
      }


      //=============================================================
      // LOG
      //=============================================================

      PrintFormat(
         "[MarketStructureAI] "
         "Symbol=%s | TF=%s | "
         "StructuralScore=%.2f | "
         "AIQuality=%.2f | "
         "Confidence=%.2f | "
         "Validated=%s | "
         "Strong=%s | "
         "BOS=%s | "
         "CHOCH=%s | "
         "Bias=%s",
         context.symbol,
         EnumToString(
            context.primaryTF
         ),
         context.structuralScore,
         m_qualityScore,
         m_confidence,
         m_validated
            ? "true"
            : "false",
         m_strongStructure
            ? "true"
            : "false",
         context.bos
            ? "true"
            : "false",
         context.choch
            ? "true"
            : "false",
         EnumToString(
            context.structuralBias
         )
      );


      return true;
   }


   //===============================================================
   // GETTERS
   //===============================================================

   bool IsValidated() const
   {
      return m_validated;
   }


   bool IsStrongStructure() const
   {
      return m_strongStructure;
   }


   double GetConfidence() const
   {
      return m_confidence;
   }


   double GetQualityScore() const
   {
      return m_qualityScore;
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_MARKETSTRUCTUREAI_MQH
//+------------------------------------------------------------------+
