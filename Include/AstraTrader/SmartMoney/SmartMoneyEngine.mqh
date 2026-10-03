//+------------------------------------------------------------------+
//| SmartMoneyEngine.mqh                                             |
//| Astra Trader AI                                                  |
//|                                                                  |
//| Smart Money Analysis Engine                                      |
//|                                                                  |
//| RESPONSABILIDADES:                                               |
//| - consolidar evidências Smart Money já produzidas                |
//| - analisar liquidez, BOS, CHOCH, OB, displacement                |
//| - produzir score DIRECIONAL -100..100                            |
//| - produzir bullish/bearish score                                 |
//| - escrever resultado no AnalysisContext                           |
//|                                                                  |
//| REGRA ARQUITETURAL:                                              |
//| - NÃO utiliza CopyRates()                                        |
//| - NÃO acessa histórico externo                                   |
//| - consome exclusivamente AnalysisContext                          |
//| - NÃO decide BUY/SELL                                            |
//| - NÃO calcula risco                                              |
//| - NÃO executa ordens                                             |
//+------------------------------------------------------------------+
#ifndef ASTRA_SMART_MONEY_ENGINE_MQH
#define ASTRA_SMART_MONEY_ENGINE_MQH

#property strict

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>


class SmartMoneyEngine
{
private:

   double m_score;
   int    m_bias;

   bool   m_liquiditySweep;
   bool   m_bos;
   bool   m_choch;
   bool   m_orderBlock;
   bool   m_displacement;

   double m_bullishScore;
   double m_bearishScore;


   //=================================================================
   // CLAMP
   //=================================================================
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


   //=================================================================
   // CLAMP SCORE SIGNED
   //=================================================================
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
   // RESET
   //=================================================================
   void Reset()
   {
      m_score = 0.0;
      m_bias  = 0;

      m_liquiditySweep = false;
      m_bos             = false;
      m_choch           = false;
      m_orderBlock      = false;
      m_displacement    = false;

      m_bullishScore = 0.0;
      m_bearishScore = 0.0;
   }


   //=================================================================
   // ATUALIZA DIREÇÃO
   //=================================================================
   void UpdateDirection()
   {
      if(m_bullishScore > m_bearishScore)
      {
         m_bias  = 1;
         m_score = ClampScore(
            m_bullishScore
         );
      }
      else
      if(m_bearishScore > m_bullishScore)
      {
         m_bias  = -1;
         m_score = ClampScore(
            -m_bearishScore
         );
      }
      else
      {
         m_bias  = 0;
         m_score = 0.0;
      }
   }


   //=================================================================
   // ESCREVE CONTEXTO
   //=================================================================
   void WriteContext(
      AnalysisContext &context
   )
   {
      context.smartMoneyScore =
         m_score;

      context.institutionalFlowScore =
         ClampScore(
            context.institutionalFlowScore
         );

      if(
         MathAbs(m_score) >= 20.0 ||
         m_liquiditySweep ||
         m_bos ||
         m_choch ||
         m_orderBlock ||
         m_displacement
      )
      {
         context.smartMoneyState =
            LAYER_VALID;
      }
      else
      {
         context.smartMoneyState =
            LAYER_NEUTRAL;
      }
   }


public:

   //=================================================================
   // CONSTRUCTOR
   //=================================================================
   SmartMoneyEngine()
   {
      Reset();
   }


   //=================================================================
   // ANALYZE
   //
   // Consome o AnalysisContext já enriquecido pelas engines anteriores.
   //=================================================================
   bool Analyze(
      AnalysisContext &context
   )
   {
      Reset();


      //==============================================================
      // VALIDA CONTEXTO
      //==============================================================

      if(context.symbol == "")
      {
         context.smartMoneyState =
            LAYER_INVALID;

         return false;
      }


      if(!context.contextValid)
      {
         context.smartMoneyState =
            LAYER_INVALID;

         return false;
      }


      //==============================================================
      // HISTÓRICO CENTRAL
      //==============================================================

      if(!context.marketHistoryReady ||
         context.marketBarsCount < 3 ||
         ArraySize(context.marketBars) < 3)
      {
         context.smartMoneyState =
            LAYER_INVALID;

         return false;
      }


      //==============================================================
      // EVIDÊNCIAS
      //==============================================================

      m_liquiditySweep =
         context.liquiditySweep;

      m_bos =
         context.bos;

      m_choch =
         context.choch;

      m_orderBlock =
         context.orderBlock &&
         context.orderBlockValid;


      //==============================================================
      // DISPLACEMENT
      //
      // Inferência simples utilizando o contexto disponível.
      //==============================================================

      m_displacement =
         (
            context.volatilityExpanding &&
            MathAbs(context.structuralScore) >= 50.0
         );


      //==============================================================
      // BASE DIRECIONAL
      //==============================================================

      double bullish = 0.0;
      double bearish = 0.0;


      //==============================================================
      // LIQUIDEZ
      //==============================================================

      if(context.sellSideLiquidityTaken)
      {
         bullish += 15.0;
      }

      if(context.buySideLiquidityTaken)
      {
         bearish += 15.0;
      }


      if(context.liquiditySweep)
      {
         if(context.sellSideLiquidityTaken)
            bullish += 15.0;

         if(context.buySideLiquidityTaken)
            bearish += 15.0;
      }


      //==============================================================
      // BOS
      //==============================================================

      if(context.bos)
      {
         if(context.structuralBias == BIAS_BULLISH)
            bullish += 20.0;
         else
         if(context.structuralBias == BIAS_BEARISH)
            bearish += 20.0;
      }


      //==============================================================
      // CHOCH
      //==============================================================

      if(context.choch)
      {
         if(context.structuralBias == BIAS_BULLISH)
            bullish += 12.0;
         else
         if(context.structuralBias == BIAS_BEARISH)
            bearish += 12.0;
      }


      //==============================================================
      // ORDER BLOCK
      //==============================================================

      if(m_orderBlock)
      {
         if(context.structuralBias == BIAS_BULLISH)
            bullish +=
               Clamp(
                  context.orderBlockStrength * 0.20,
                  0.0,
                  15.0
               );

         else
         if(context.structuralBias == BIAS_BEARISH)
            bearish +=
               Clamp(
                  context.orderBlockStrength * 0.20,
                  0.0,
                  15.0
               );
      }


      //==============================================================
      // FVG
      //==============================================================

      if(context.fairValueGap)
      {
         if(context.bullishFVG)
            bullish += 10.0;

         if(context.bearishFVG)
            bearish += 10.0;
      }


      //==============================================================
      // MITIGATION
      //==============================================================

      if(context.mitigation)
      {
         if(context.structuralBias == BIAS_BULLISH)
            bullish += 5.0;
         else
         if(context.structuralBias == BIAS_BEARISH)
            bearish += 5.0;
      }


      //==============================================================
      // SMART MONEY / INSTITUTIONAL FLOW
      //==============================================================

      if(context.institutionalFlowScore > 0.0)
      {
         bullish +=
            Clamp(
               context.institutionalFlowScore * 0.15,
               0.0,
               15.0
            );
      }
      else
      if(context.institutionalFlowScore < 0.0)
      {
         bearish +=
            Clamp(
               MathAbs(context.institutionalFlowScore) * 0.15,
               0.0,
               15.0
            );
      }


      //==============================================================
      // ABSORPTION
      //==============================================================

      if(context.absorptionScore > 0.0)
      {
         bullish +=
            Clamp(
               context.absorptionScore * 0.15,
               0.0,
               10.0
            );
      }
      else
      if(context.absorptionScore < 0.0)
      {
         bearish +=
            Clamp(
               MathAbs(context.absorptionScore) * 0.15,
               0.0,
               10.0
            );
      }


      //==============================================================
      // DISPLACEMENT
      //==============================================================

      if(m_displacement)
      {
         if(context.structuralBias == BIAS_BULLISH)
            bullish += 10.0;
         else
         if(context.structuralBias == BIAS_BEARISH)
            bearish += 10.0;
      }


      //==============================================================
      // EVIDÊNCIAS DE ENTRADA EXTERNAS
      //==============================================================

      if(context.smartMoneyScore > 0.0)
      {
         bullish +=
            Clamp(
               context.smartMoneyScore * 0.25,
               0.0,
               15.0
            );
      }
      else
      if(context.smartMoneyScore < 0.0)
      {
         bearish +=
            Clamp(
               MathAbs(context.smartMoneyScore) * 0.25,
               0.0,
               15.0
            );
      }


      //==============================================================
      // CLAMP
      //==============================================================

      m_bullishScore =
         Clamp(
            bullish,
            0.0,
            100.0
         );

      m_bearishScore =
         Clamp(
            bearish,
            0.0,
            100.0
         );


      //==============================================================
      // DIREÇÃO FINAL DO MOTOR
      //==============================================================

      UpdateDirection();


      //==============================================================
      // CONTEXTO
      //==============================================================

      WriteContext(
         context
      );


      return true;
   }


   //=================================================================
   // ANALYZE EVIDENCE
   //
   // Mantido para compatibilidade.
   //=================================================================
   bool AnalyzeEvidence(
      const bool liquiditySweep,
      const bool bos,
      const bool choch,
      const bool orderBlock,
      const bool displacement,
      const double bullishEvidence,
      const double bearishEvidence
   )
   {
      Reset();

      m_liquiditySweep =
         liquiditySweep;

      m_bos =
         bos;

      m_choch =
         choch;

      m_orderBlock =
         orderBlock;

      m_displacement =
         displacement;

      m_bullishScore =
         Clamp(
            bullishEvidence,
            0.0,
            100.0
         );

      m_bearishScore =
         Clamp(
            bearishEvidence,
            0.0,
            100.0
         );

      if(m_liquiditySweep)
      {
         if(m_bullishScore >= m_bearishScore)
            m_bullishScore += 10.0;
         else
            m_bearishScore += 10.0;
      }

      if(m_bos)
      {
         if(m_bullishScore >= m_bearishScore)
            m_bullishScore += 10.0;
         else
            m_bearishScore += 10.0;
      }

      if(m_choch)
      {
         if(m_bullishScore >= m_bearishScore)
            m_bullishScore += 8.0;
         else
            m_bearishScore += 8.0;
      }

      if(m_orderBlock)
      {
         if(m_bullishScore >= m_bearishScore)
            m_bullishScore += 8.0;
         else
            m_bearishScore += 8.0;
      }

      if(m_displacement)
      {
         if(m_bullishScore >= m_bearishScore)
            m_bullishScore += 10.0;
         else
            m_bearishScore += 10.0;
      }

      m_bullishScore =
         Clamp(
            m_bullishScore,
            0.0,
            100.0
         );

      m_bearishScore =
         Clamp(
            m_bearishScore,
            0.0,
            100.0
         );

      UpdateDirection();

      return true;
   }


   //=================================================================
   // LEGACY ANALYZE
   //=================================================================
   bool Analyze()
   {
      Reset();
      return true;
   }


   //=================================================================
   // GETTERS
   //=================================================================
   double GetSmartMoneyScore() const
   {
      return m_score;
   }


   int GetBias() const
   {
      return m_bias;
   }


   bool HasLiquiditySweep() const
   {
      return m_liquiditySweep;
   }


   bool HasBOS() const
   {
      return m_bos;
   }


   bool HasCHOCH() const
   {
      return m_choch;
   }


   bool HasOrderBlock() const
   {
      return m_orderBlock;
   }


   bool HasDisplacement() const
   {
      return m_displacement;
   }


   double GetBullishScore() const
   {
      return m_bullishScore;
   }


   double GetBearishScore() const
   {
      return m_bearishScore;
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_SMART_MONEY_ENGINE_MQH
