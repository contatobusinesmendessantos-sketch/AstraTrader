//+------------------------------------------------------------------+
//| InstitutionalIntelligence.mqh                                   |
//| Astra Trader AI                                                  |
//|                                                                  |
//| Camada de Inteligência Institucional                             |
//|                                                                  |
//| Responsabilidades:                                               |
//| - Avaliar fluxo institucional                                    |
//| - Combinar Smart Money, Liquidity, Wyckoff e Structure           |
//| - Identificar contexto institucional bullish/bearish             |
//| - Gerar score institucional                                      |
//| - Não executa ordens                                             |
//| - Não define lote                                                 |
//| - Não define SL/TP                                                |
//| - Não substitui o RiskManagementEngine                            |
//+------------------------------------------------------------------+
#ifndef ASTRA_INSTITUTIONALINTELLIGENCE_MQH
#define ASTRA_INSTITUTIONALINTELLIGENCE_MQH

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>

class InstitutionalIntelligence
{
private:

   double m_score;
   double m_confidence;

   ENUM_BIAS m_bias;

   bool m_institutionalActivity;
   bool m_accumulation;
   bool m_distribution;

   string m_reason;

   //===============================================================
   // CLAMP
   //===============================================================
   double Clamp(const double value,
                const double minValue,
                const double maxValue)
   {
      return MathMax(minValue, MathMin(maxValue, value));
   }

   //===============================================================
   // NORMALIZA SCORE
   //===============================================================
   double NormalizeScore(const double value)
   {
      return Clamp(value, -100.0, 100.0);
   }

   //===============================================================
   // CALCULA PRESSAO INSTITUCIONAL
   //===============================================================
   double CalculateInstitutionalPressure(
      const AnalysisContext &ctx)
   {
      double score = 0.0;

      //--- Market Structure
      if(ctx.structuralBias == BIAS_BULLISH)
         score += 15.0;
      else if(ctx.structuralBias == BIAS_BEARISH)
         score -= 15.0;

      if(ctx.bos)
      {
         if(ctx.structuralBias == BIAS_BULLISH)
            score += 8.0;
         else if(ctx.structuralBias == BIAS_BEARISH)
            score -= 8.0;
      }

      if(ctx.choch)
      {
         if(ctx.structuralBias == BIAS_BULLISH)
            score += 5.0;
         else if(ctx.structuralBias == BIAS_BEARISH)
            score -= 5.0;
      }

      //--- Liquidity
      if(ctx.liquiditySweep)
         score += 12.0;

      if(ctx.liquidityGrab)
         score -= 12.0;

      if(ctx.buySideLiquidityTaken)
         score -= 4.0;

      if(ctx.sellSideLiquidityTaken)
         score += 4.0;

      //--- Smart Money
      if(ctx.orderBlock)
      {
         if(ctx.bullishFVG)
            score += 8.0;
         else if(ctx.bearishFVG)
            score -= 8.0;
      }

      if(ctx.breakerBlock)
      {
         if(ctx.structuralBias == BIAS_BULLISH)
            score += 5.0;
         else if(ctx.structuralBias == BIAS_BEARISH)
            score -= 5.0;
      }

      score += Clamp(ctx.smartMoneyScore * 0.15,
                     -15.0,
                      15.0);

      score += Clamp(ctx.institutionalFlowScore * 0.20,
                     -10.0,
                      10.0);

      score += Clamp(ctx.absorptionScore * 0.10,
                     -5.0,
                      5.0);

      //--- Wyckoff
      switch(ctx.wyckoffPhase)
      {
         case WYCKOFF_ACCUMULATION:
            score += 10.0;
            break;

         case WYCKOFF_SOS:
            score += 15.0;
            break;

         case WYCKOFF_DISTRIBUTION:
            score -= 10.0;
            break;

         case WYCKOFF_SOW:
            score -= 15.0;
            break;

         default:
            break;
      }

      score += Clamp(ctx.wyckoffScore * 0.10,
                     -10.0,
                      10.0);

      //--- Elliott
      if(ctx.elliottWave == ELLIOTT_IMPULSE_3 ||
         ctx.elliottWave == ELLIOTT_IMPULSE_5)
      {
         if(ctx.structuralBias == BIAS_BULLISH)
            score += 5.0;
         else if(ctx.structuralBias == BIAS_BEARISH)
            score -= 5.0;
      }

      if(ctx.waveBDetected)
      {
         if(ctx.structuralBias == BIAS_BULLISH)
            score += 2.0;
         else if(ctx.structuralBias == BIAS_BEARISH)
            score -= 2.0;
      }

      if(ctx.waveCDetected)
      {
         if(ctx.structuralBias == BIAS_BULLISH)
            score += 3.0;
         else if(ctx.structuralBias == BIAS_BEARISH)
            score -= 3.0;
      }

      //--- Regime
      if(ctx.regime == REGIME_EXPANSION)
      {
         if(score > 0.0)
            score += 5.0;
         else if(score < 0.0)
            score -= 5.0;
      }

      if(ctx.regime == REGIME_CONTRACTION)
         score *= 0.75;

      if(ctx.regime == REGIME_RANGE)
         score *= 0.85;

      if(ctx.regime == REGIME_TRANSITION)
         score *= 0.65;

      return NormalizeScore(score);
   }

   //===============================================================
   // CALCULA CONFIANCA
   //===============================================================
   double CalculateConfidence(
      const AnalysisContext &ctx,
      const double score)
   {
      double confidence = MathAbs(score) / 100.0;

      //--- qualidade estrutural
      if(ctx.structureState == LAYER_VALID)
         confidence += 0.08;

      //--- Smart Money
      if(ctx.smartMoneyState == LAYER_VALID)
         confidence += 0.08;

      //--- Liquidity
      if(ctx.liquidityState == LAYER_VALID)
         confidence += 0.06;

      //--- Wyckoff
      if(ctx.wyckoffState == LAYER_VALID)
         confidence += 0.06;

      //--- Elliott
      if(ctx.elliottState == LAYER_VALID)
         confidence += 0.05;

      //--- Multi timeframe
      if(ctx.timeframeAligned)
         confidence += 0.10;

      //--- Confluence
      if(ctx.confluenceState == LAYER_VALID)
         confidence += 0.10;

      //--- Dados inválidos reduzem confiança
      if(ctx.dataQuality == ASTRA_DATA_INVALID)
         confidence = 0.0;

      return Clamp(confidence, 0.0, 1.0);
   }

   //===============================================================
   // DETERMINA BIAS
   //===============================================================
   ENUM_BIAS CalculateBias(const double score)
   {
      if(score >= 20.0)
         return BIAS_BULLISH;

      if(score <= -20.0)
         return BIAS_BEARISH;

      return BIAS_NEUTRAL;
   }

   //===============================================================
   // DETECTA ATIVIDADE INSTITUCIONAL
   //===============================================================
   bool DetectInstitutionalActivity(
      const AnalysisContext &ctx)
   {
      int factors = 0;

      if(ctx.orderBlock)
         factors++;

      if(ctx.breakerBlock)
         factors++;

      if(ctx.liquiditySweep)
         factors++;

      if(ctx.liquidityGrab)
         factors++;

      if(ctx.springDetected)
         factors++;

      if(ctx.upthrustDetected)
         factors++;

      if(ctx.sosDetected)
         factors++;

      if(ctx.sowDetected)
         factors++;

      if(ctx.absorptionScore > 20.0)
         factors++;

      if(ctx.institutionalFlowScore > 20.0 ||
         ctx.institutionalFlowScore < -20.0)
         factors++;

      return (factors >= 2);
   }

   //===============================================================
   // GERA INTERPRETACAO
   //===============================================================
   void BuildReason(
      const AnalysisContext &ctx)
   {
      m_reason = "";

      if(m_bias == BIAS_BULLISH)
      {
         m_reason = "Institutional bullish pressure";

         if(ctx.liquiditySweep)
            m_reason += " + liquidity sweep";

         if(ctx.orderBlock)
            m_reason += " + order block";

         if(ctx.sosDetected)
            m_reason += " + Wyckoff SOS";
      }
      else if(m_bias == BIAS_BEARISH)
      {
         m_reason = "Institutional bearish pressure";

         if(ctx.liquidityGrab)
            m_reason += " + liquidity grab";

         if(ctx.breakerBlock)
            m_reason += " + breaker block";

         if(ctx.sowDetected)
            m_reason += " + Wyckoff SOW";
      }
      else
      {
         m_reason = "Institutional flow neutral";
      }
   }

public:

   //===============================================================
   // CONSTRUCTOR
   //===============================================================
   InstitutionalIntelligence()
   {
      Reset();
   }

   //===============================================================
   // RESET
   //===============================================================
   void Reset()
   {
      m_score                 = 0.0;
      m_confidence            = 0.0;
      m_bias                  = BIAS_NEUTRAL;

      m_institutionalActivity = false;
      m_accumulation          = false;
      m_distribution          = false;

      m_reason                = "";
   }

   //===============================================================
   // ANALYZE
   //===============================================================
   bool Analyze(const AnalysisContext &ctx)
   {
      Reset();

      //--- contexto inválido
      if(!ctx.contextValid)
         return false;

      //--- dados inválidos
      if(ctx.dataQuality == ASTRA_DATA_INVALID)
         return false;

      //--- calcula pressão institucional
      m_score = CalculateInstitutionalPressure(ctx);

      //--- bias
      m_bias = CalculateBias(m_score);

      //--- confiança
      m_confidence = CalculateConfidence(ctx, m_score);

      //--- atividade institucional
      m_institutionalActivity =
         DetectInstitutionalActivity(ctx);

      //--- acumulação/distribuição
      if(ctx.wyckoffPhase == WYCKOFF_ACCUMULATION ||
         ctx.wyckoffPhase == WYCKOFF_SOS)
      {
         m_accumulation = true;
      }

      if(ctx.wyckoffPhase == WYCKOFF_DISTRIBUTION ||
         ctx.wyckoffPhase == WYCKOFF_SOW)
      {
         m_distribution = true;
      }

      //--- interpretação
      BuildReason(ctx);

      return true;
   }

   //===============================================================
   // GET SCORE
   //===============================================================
   double GetScore() const
   {
      return m_score;
   }

   //===============================================================
   // GET CONFIDENCE
   //===============================================================
   double GetConfidence() const
   {
      return m_confidence;
   }

   //===============================================================
   // GET BIAS
   //===============================================================
   ENUM_BIAS GetBias() const
   {
      return m_bias;
   }

   //===============================================================
   // INSTITUTIONAL ACTIVITY
   //===============================================================
   bool HasInstitutionalActivity() const
   {
      return m_institutionalActivity;
   }

   //===============================================================
   // ACCUMULATION
   //===============================================================
   bool IsAccumulation() const
   {
      return m_accumulation;
   }

   //===============================================================
   // DISTRIBUTION
   //===============================================================
   bool IsDistribution() const
   {
      return m_distribution;
   }

   //===============================================================
   // REASON
   //===============================================================
   string GetReason() const
   {
      return m_reason;
   }

   //===============================================================
   // DEBUG
   //===============================================================
   string ToString() const
   {
      return StringFormat(
         "[InstitutionalIntelligence] "
         "Bias=%s Score=%.2f Confidence=%.3f "
         "Activity=%s Accumulation=%s Distribution=%s "
         "Reason=%s",
         EnumToString(m_bias),
         m_score,
         m_confidence,
         m_institutionalActivity ? "true" : "false",
         m_accumulation ? "true" : "false",
         m_distribution ? "true" : "false",
         m_reason
      );
   }
};

#endif // ASTRA_INSTITUTIONALINTELLIGENCE_MQH
