//+------------------------------------------------------------------+
//| MultiTimeframeEngine.mqh                                         |
//| Astra Trader AI                                                  |
//|                                                                  |
//| CAMADA 8 - MULTI TIMEFRAME                                       |
//|                                                                  |
//| Responsabilidade:                                                |
//| - Avaliar alinhamento multi-timeframe                            |
//| - Utilizar exclusivamente informações disponíveis no             |
//|   AnalysisContext                                                 |
//| - Não executar CopyRates()                                       |
//| - Não acessar diretamente o histórico do MT5                    |
//| - Não executar ordens                                             |
//| - Não calcular risco                                              |
//| - Não alterar outras camadas do contexto                         |
//|                                                                  |
//| IMPORTANTE:                                                       |
//| O AnalysisContext atual possui um único conjunto de marketBars.  |
//| Portanto esta implementação não inventa dados de outros         |
//| timeframes. Quando não houver informação específica disponível,  |
//| o timeframe permanece NEUTRO.                                     |
//+------------------------------------------------------------------+
#ifndef ASTRA_MULTITIMEFRAMEENGINE_MQH
#define ASTRA_MULTITIMEFRAMEENGINE_MQH

#property strict

#include <AstraTrader\Analysis\AnalysisContext.mqh>


//+------------------------------------------------------------------+
//| MultiTimeframeEngine                                             |
//+------------------------------------------------------------------+
class MultiTimeframeEngine
  {
private:

   //=================================================================
   // CONFIGURAÇÃO
   //=================================================================

   double m_minAlignmentScore;
   double m_strongAlignmentScore;


   //=================================================================
   // CLAMP SCORE
   //
   // Mantém score dentro do contrato padrão do AnalysisContext.
   //=================================================================

   double ClampScore(
      const double value
   ) const
     {
      if(value > 100.0)
         return 100.0;

      if(value < -100.0)
         return -100.0;

      return value;
     }


   //=================================================================
   // CLAMP POSITIVO
   //=================================================================

   double ClampPositive(
      const double value
   ) const
     {
      if(value < 0.0)
         return 0.0;

      if(value > 100.0)
         return 100.0;

      return value;
     }


   //=================================================================
   // VALIDA CONTEXTO
   //=================================================================

   bool ValidateContext(
      const AnalysisContext &context
   ) const
     {
      if(context.symbol == "")
         return false;

      if(!context.contextValid)
         return false;

      if(context.point <= 0.0)
         return false;

      if(context.primaryTF == PERIOD_CURRENT)
         return false;

      return true;
     }


   //=================================================================
   // NORMALIZA BIAS PARA SCORE
   //
   // Retorna:
   //
   // +100 = bullish
   //    0 = neutral
   // -100 = bearish
   //=================================================================

   double BiasToScore(
      const ENUM_BIAS bias
   ) const
     {
      if(bias == BIAS_BULLISH)
         return 100.0;

      if(bias == BIAS_BEARISH)
         return -100.0;

      return 0.0;
     }


   //=================================================================
   // SCORE DA ESTRUTURA ATUAL
   //
   // Utiliza somente informações já produzidas pelas engines
   // anteriores.
   //=================================================================

   double CalculateBaseStructureScore(
      const AnalysisContext &context
   ) const
     {
      double score = 0.0;

      //==============================================================
      // BIAS ESTRUTURAL
      //==============================================================

      score += BiasToScore(
         context.structuralBias
      ) * 0.55;


      //==============================================================
      // ESTRUTURA
      //==============================================================

      if(context.higherHigh)
         score += 15.0;

      if(context.higherLow)
         score += 10.0;

      if(context.lowerHigh)
         score -= 10.0;

      if(context.lowerLow)
         score -= 15.0;


      //==============================================================
      // BOS
      //==============================================================

      if(context.bos)
        {
         if(context.structuralBias == BIAS_BULLISH)
            score += 10.0;
         else
         if(context.structuralBias == BIAS_BEARISH)
            score -= 10.0;
        }


      //==============================================================
      // CHOCH
      //
      // CHOCH representa mudança estrutural.
      // Não recebe direção artificial.
      //================================================================

      if(context.choch)
         score *= 0.80;


      //==============================================================
      // ELLIOTT
      //
      // Elliott é utilizado apenas como confirmação adicional.
      //================================================================

      if(context.elliottScore != 0.0)
         score += context.elliottScore * 0.15;


      //==============================================================
      // REGIME
      //
      // Regime não define direção sozinho.
      // Apenas aumenta/reduz a confiança estrutural.
      //================================================================

      if(context.regime == REGIME_EXPANSION)
         score *= 1.10;
      else
      if(context.regime == REGIME_CONTRACTION)
         score *= 0.90;
      else
      if(context.regime == REGIME_TRANSITION)
         score *= 0.75;


      return ClampScore(score);
     }


   //=================================================================
   // CALCULA SCORE DO TIMEFRAME PRINCIPAL
   //=================================================================

   double CalculatePrimaryTFScore(
      const AnalysisContext &context
   ) const
     {
      double score =
         CalculateBaseStructureScore(context);

      return ClampScore(score);
     }


   //=================================================================
   // CALCULA SCORE DE TIMEFRAME NÃO DISPONÍVEL
   //
   // Não inventamos informação.
   // O timeframe não analisado permanece neutro.
   //=================================================================

   double CalculateUnavailableTFScore() const
     {
      return 0.0;
     }


   //=================================================================
   // CALCULA SCORE AGREGADO
   //=================================================================

   double CalculateAggregateScore(
      const AnalysisContext &context
   ) const
     {
      double scores[9];

      scores[0] = context.m1Score;
      scores[1] = context.m5Score;
      scores[2] = context.m15Score;
      scores[3] = context.m30Score;
      scores[4] = context.h1Score;
      scores[5] = context.h4Score;
      scores[6] = context.d1Score;
      scores[7] = context.w1Score;
      scores[8] = context.mn1Score;

      double weightedSum = 0.0;
      double weightSum    = 0.0;

      // Pesos levemente maiores para timeframes intermediários
      // e principais, sem criar dados inexistentes.

      double weights[9];

      weights[0] = 0.50;
      weights[1] = 0.60;
      weights[2] = 0.80;
      weights[3] = 0.90;
      weights[4] = 1.20;
      weights[5] = 1.30;
      weights[6] = 1.10;
      weights[7] = 0.90;
      weights[8] = 0.70;


      for(int i = 0; i < 9; i++)
        {
         // Somente scores efetivamente disponíveis participam
         // da média ponderada.
         if(scores[i] == 0.0)
            continue;

         weightedSum += scores[i] * weights[i];
         weightSum   += weights[i];
        }


      if(weightSum <= 0.0)
         return 0.0;


      // O agregado é magnitude; a direção é exposta pelos contadores
      // alignedBullishTFs/alignedBearishTFs.
      return MathMin(
         100.0,
         MathAbs(
            weightedSum / weightSum
         )
      );
     }


   //=================================================================
   // ATUALIZA CONTAGEM DE ALINHAMENTO
   //=================================================================

   void CalculateAlignmentCounts(
      AnalysisContext &context
   ) const
     {
      context.alignedBullishTFs = 0;
      context.alignedBearishTFs = 0;
      context.neutralTFCount    = 0;


      double scores[9];

      scores[0] = context.m1Score;
      scores[1] = context.m5Score;
      scores[2] = context.m15Score;
      scores[3] = context.m30Score;
      scores[4] = context.h1Score;
      scores[5] = context.h4Score;
      scores[6] = context.d1Score;
      scores[7] = context.w1Score;
      scores[8] = context.mn1Score;


      for(int i = 0; i < 9; i++)
        {
         if(scores[i] > m_minAlignmentScore)
            context.alignedBullishTFs++;
         else
         if(scores[i] < -m_minAlignmentScore)
            context.alignedBearishTFs++;
         else
            context.neutralTFCount++;
        }
     }


   //=================================================================
   // CALCULA ALINHAMENTO
   //=================================================================

   bool CalculateAlignment(
      const AnalysisContext &context
   ) const
     {
      int bullish =
         context.alignedBullishTFs;

      int bearish =
         context.alignedBearishTFs;


      // Nenhum alinhamento significativo.
      if(bullish == 0 &&
         bearish == 0)
         return false;


      // Ambos os lados dominantes simultaneamente.
      if(bullish > 0 &&
         bearish > 0)
        {
         int difference =
            MathAbs(
               bullish - bearish
            );

         if(difference <= 1)
            return false;
        }


      int dominant =
         MathMax(
            bullish,
            bearish
         );


      // Exige pelo menos dois timeframes confirmando
      // a mesma direção.
      if(dominant < 2)
         return false;


      return true;
     }


   //=================================================================
   // DEFINE ESTADO DA CAMADA
   //=================================================================

   void CalculateState(
      AnalysisContext &context
   ) const
     {
      double absoluteScore =
         MathAbs(
            context.timeframeScore
         );


      if(context.timeframeScore == 0.0)
        {
         context.timeframeState =
            LAYER_NEUTRAL;

         return;
        }


      if(absoluteScore < m_minAlignmentScore)
        {
         context.timeframeState =
            LAYER_NEUTRAL;

         return;
        }


      if(context.timeframeAligned)
        {
         context.timeframeState =
            LAYER_VALID;

         return;
        }


      context.timeframeState =
         LAYER_NEUTRAL;
     }


   //=================================================================
   // RESET SOMENTE DA CAMADA 8
   //=================================================================

   void ResetLayer(
      AnalysisContext &context
   ) const
     {
      context.timeframeAligned = false;

      context.timeframeScore = 0.0;

      context.m1Score  = 0.0;
      context.m5Score  = 0.0;
      context.m15Score = 0.0;
      context.m30Score = 0.0;

      context.h1Score = 0.0;
      context.h4Score = 0.0;

      context.d1Score  = 0.0;
      context.w1Score  = 0.0;
      context.mn1Score = 0.0;

      context.alignedBullishTFs = 0;
      context.alignedBearishTFs = 0;
      context.neutralTFCount    = 0;

      context.timeframeState =
         LAYER_NEUTRAL;
     }


public:

   //=================================================================
   // CONSTRUTOR
   //=================================================================

   MultiTimeframeEngine()
     {
      m_minAlignmentScore    = 25.0;
      m_strongAlignmentScore = 60.0;
     }


   //=================================================================
   // CONSTRUTOR CONFIGURÁVEL
   //=================================================================

   MultiTimeframeEngine(
      const double minimumAlignmentScore,
      const double strongAlignmentScore
   )
     {
      m_minAlignmentScore =
         minimumAlignmentScore;

      m_strongAlignmentScore =
         strongAlignmentScore;


      if(m_minAlignmentScore < 0.0)
         m_minAlignmentScore = 25.0;

      if(m_minAlignmentScore > 100.0)
         m_minAlignmentScore = 100.0;


      if(m_strongAlignmentScore < m_minAlignmentScore)
         m_strongAlignmentScore =
            MathMin(
               100.0,
               m_minAlignmentScore + 25.0
            );

      if(m_strongAlignmentScore > 100.0)
         m_strongAlignmentScore = 100.0;
     }


   //=================================================================
   // SET MIN ALIGNMENT SCORE
   //=================================================================

   void SetMinimumAlignmentScore(
      const double score
   )
     {
      if(score < 0.0 ||
         score > 100.0)
         return;

      m_minAlignmentScore = score;


      if(m_strongAlignmentScore <
         m_minAlignmentScore)
        {
         m_strongAlignmentScore =
            MathMin(
               100.0,
               m_minAlignmentScore + 25.0
            );
        }
     }


   //=================================================================
   // GET MIN ALIGNMENT SCORE
   //=================================================================

   double GetMinimumAlignmentScore() const
     {
      return m_minAlignmentScore;
     }


   //=================================================================
   // SET STRONG ALIGNMENT SCORE
   //=================================================================

   void SetStrongAlignmentScore(
      const double score
   )
     {
      if(score < m_minAlignmentScore)
         return;

      if(score > 100.0)
         return;

      m_strongAlignmentScore = score;
     }


   //=================================================================
   // GET STRONG ALIGNMENT SCORE
   //=================================================================

   double GetStrongAlignmentScore() const
     {
      return m_strongAlignmentScore;
     }


   //=================================================================
   // PROCESS
   //
   // Função principal da engine.
   //=================================================================

   bool Process(
      AnalysisContext &context
   )
     {
      //==============================================================
      // RESET APENAS DA CAMADA MULTI-TIMEFRAME
      //==============================================================

      ResetLayer(context);


      //==============================================================
      // VALIDAR CONTEXTO
      //==============================================================

      if(!ValidateContext(context))
        {
         context.timeframeState =
            LAYER_INVALID;

         return false;
        }


      //==============================================================
      // IMPORTANTE
      //
      // O contexto atual não possui nove históricos independentes.
      //
      // Portanto somente o timeframe efetivamente representado
      // pelo contexto recebe análise.
      //
      // Os demais permanecem neutros.
      //==============================================================

      double primaryScore =
         CalculatePrimaryTFScore(context);


      //==============================================================
      // DISTRIBUI SCORE PARA O TIMEFRAME PRINCIPAL
      //==============================================================

      switch(context.primaryTF)
        {
         case PERIOD_M1:
            context.m1Score = primaryScore;
            break;

         case PERIOD_M5:
            context.m5Score = primaryScore;
            break;

         case PERIOD_M15:
            context.m15Score = primaryScore;
            break;

         case PERIOD_M30:
            context.m30Score = primaryScore;
            break;

         case PERIOD_H1:
            context.h1Score = primaryScore;
            break;

         case PERIOD_H4:
            context.h4Score = primaryScore;
            break;

         case PERIOD_D1:
            context.d1Score = primaryScore;
            break;

         case PERIOD_W1:
            context.w1Score = primaryScore;
            break;

         case PERIOD_MN1:
            context.mn1Score = primaryScore;
            break;

         default:
            break;
        }


      //==============================================================
      // CONTAGEM
      //==============================================================

      CalculateAlignmentCounts(context);


      //==============================================================
      // SCORE AGREGADO
      //==============================================================

      context.timeframeScore =
         CalculateAggregateScore(context);


      //==============================================================
      // ALINHAMENTO
      //
      // Como a implementação atual possui apenas um timeframe real,
      // não classificamos automaticamente como "aligned".
      //
      // Isso evita uma falsa confirmação multi-timeframe.
      //==============================================================

      context.timeframeAligned =
         CalculateAlignment(context);


      //==============================================================
      // ESTADO
      //==============================================================

      CalculateState(context);


      //==============================================================
      // VALIDAÇÃO FINAL
      //==============================================================

      if(context.timeframeState ==
         LAYER_INVALID)
         return false;


      return true;
     }


   //=================================================================
   // UPDATE
   //=================================================================

   bool Update(
      AnalysisContext &context
   )
     {
      return Process(context);
     }


   //=================================================================
   // ANALYZE
   //=================================================================

   bool Analyze(
      AnalysisContext &context
   )
     {
      return Process(context);
     }


   //=================================================================
   // IS VALID
   //=================================================================

   bool IsValid(
      const AnalysisContext &context
   ) const
     {
      if(context.timeframeState ==
         LAYER_INVALID)
         return false;

      if(context.timeframeState ==
         LAYER_NEUTRAL)
         return false;

      return true;
     }


   //=================================================================
   // GET LAST ERROR DESCRIPTION
   //=================================================================

   string GetLastErrorDescription() const
     {
      return
         "MultiTimeframeEngine utiliza exclusivamente "
         "dados disponíveis no AnalysisContext e não executa "
         "CopyRates().";
     }
  };


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_MULTITIMEFRAMEENGINE_MQH
//+------------------------------------------------------------------+
