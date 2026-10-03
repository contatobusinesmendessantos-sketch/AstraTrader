//+------------------------------------------------------------------+
//| VolatilityEngine.mqh                                             |
//| Astra Trader AI                                                  |
//|                                                                  |
//| ENGINE DE ANALISE DE VOLATILIDADE                                |
//|                                                                  |
//| Responsabilidades:                                               |
//|  - Calcular ATR                                                   |
//|  - Medir volatilidade relativa                                   |
//|  - Detectar expansão                                              |
//|  - Detectar contração                                             |
//|  - Detectar aceleração                                            |
//|  - Produzir volatilityScore                                       |
//|  - Classificar regime de volatilidade                             |
//|                                                                  |
//| CONTRATO:                                                        |
//|  - Não utiliza CopyRates()                                       |
//|  - Não acessa diretamente o histórico MT5                        |
//|  - Consome exclusivamente AnalysisContext.marketBars[]            |
//|                                                                  |
//| HISTÓRICO:                                                       |
//|  marketBars[0] = candle atual                                    |
//|  marketBars[1] = último candle fechado                           |
//|  marketBars[2+] = candles fechados anteriores                    |
//|                                                                  |
//| Para ATR e volatilidade estratégica somente candles fechados     |
//| são utilizados.                                                   |
//+------------------------------------------------------------------+
#ifndef ASTRA_VOLATILITYENGINE_MQH
#define ASTRA_VOLATILITYENGINE_MQH

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>


//+------------------------------------------------------------------+
//| VolatilityEngine                                                 |
//+------------------------------------------------------------------+
class VolatilityEngine
{
private:

   //===============================================================
   // CONFIGURAÇÃO
   //===============================================================

   int    m_atrPeriod;
   int    m_baselinePeriod;

   double m_expansionThreshold;
   double m_contractionThreshold;


   //===============================================================
   // CLAMP
   //===============================================================

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


   //===============================================================
   // TRUE RANGE
   //===============================================================

   double TrueRange(
      const MqlRates &currentBar,
      const MqlRates &previousBar
   ) const
   {
      const double range1 =
         currentBar.high -
         currentBar.low;

      const double range2 =
         MathAbs(
            currentBar.high -
            previousBar.close
         );

      const double range3 =
         MathAbs(
            currentBar.low -
            previousBar.close
         );

      return MathMax(
         range1,
         MathMax(
            range2,
            range3
         )
      );
   }


   //===============================================================
   // ATR
   //
   // Utiliza exclusivamente candles fechados:
   //
   // shift 1 -> última barra fechada
   // shift 2 -> barra fechada anterior
   // ...
   //===============================================================

   double CalculateATR(
      const AnalysisContext &ctx,
      const int period
   ) const
   {
      if(period <= 0)
         return 0.0;

      const int count =
         ctx.GetMarketBarCount();

      // Precisamos de:
      // period candles + 1 candle anterior para TR.
      if(count < period + 2)
         return 0.0;

      int samples =
         MathMin(
            period,
            count - 2
         );

      if(samples <= 0)
         return 0.0;

      double sum = 0.0;
      int valid = 0;

      for(
         int shift = 1;
         shift <= samples;
         shift++
      )
      {
         MqlRates currentBar;
         MqlRates previousBar;

         if(
            !ctx.GetMarketBar(
               shift,
               currentBar
            )
         )
            continue;

         if(
            !ctx.GetMarketBar(
               shift + 1,
               previousBar
            )
         )
            continue;

         const double tr =
            TrueRange(
               currentBar,
               previousBar
            );

         if(tr <= 0.0)
            continue;

         sum += tr;
         valid++;
      }

      if(valid <= 0)
         return 0.0;

      return sum / (double)valid;
   }


   //===============================================================
   // ATR A PARTIR DE UM SHIFT
   //
   // startShift >= 1
   //===============================================================

   double CalculateATRFromShift(
      const AnalysisContext &ctx,
      const int startShift,
      const int period
   ) const
   {
      if(
         startShift < 1 ||
         period <= 0
      )
         return 0.0;

      const int count =
         ctx.GetMarketBarCount();

      // Último TR precisa de startShift + period.
      if(
         count <=
         startShift + period
      )
         return 0.0;

      double sum = 0.0;
      int valid = 0;

      for(
         int shift = startShift;
         shift < startShift + period;
         shift++
      )
      {
         MqlRates currentBar;
         MqlRates previousBar;

         if(
            !ctx.GetMarketBar(
               shift,
               currentBar
            )
         )
            continue;

         if(
            !ctx.GetMarketBar(
               shift + 1,
               previousBar
            )
         )
            continue;

         const double tr =
            TrueRange(
               currentBar,
               previousBar
            );

         if(tr <= 0.0)
            continue;

         sum += tr;
         valid++;
      }

      if(valid <= 0)
         return 0.0;

      return sum / (double)valid;
   }


   //===============================================================
   // ATR BASELINE
   //
   // A baseline é composta por vários ATRs históricos.
   //
   // ATR atual:
   //   shift 1
   //
   // Baseline:
   //   shift 2+
   //
   // Isso impede que o candle atual contamine a referência.
   //===============================================================

   double CalculateATRBaseline(
      const AnalysisContext &ctx,
      const int atrPeriod,
      const int baselinePeriod
   ) const
   {
      if(
         atrPeriod <= 0 ||
         baselinePeriod <= 0
      )
         return 0.0;

      const int count =
         ctx.GetMarketBarCount();

      if(
         count <
         atrPeriod + baselinePeriod + 2
      )
      {
         // Mesmo com histórico menor, tentamos utilizar
         // o máximo disponível.
         if(count < atrPeriod + 3)
            return 0.0;
      }

      int maximumShift =
         count -
         atrPeriod -
         1;

      if(maximumShift < 2)
         return 0.0;

      const int samples =
         MathMin(
            baselinePeriod,
            maximumShift - 1
         );

      if(samples <= 0)
         return 0.0;

      double sum = 0.0;
      int valid = 0;

      for(
         int offset = 0;
         offset < samples;
         offset++
      )
      {
         const int startShift =
            2 + offset;

         const double atrValue =
            CalculateATRFromShift(
               ctx,
               startShift,
               atrPeriod
            );

         if(atrValue <= 0.0)
            continue;

         sum += atrValue;
         valid++;
      }

      if(valid <= 0)
         return 0.0;

      return sum / (double)valid;
   }


   //===============================================================
   // RATIO DE VOLATILIDADE
   //===============================================================

   double CalculateVolatilityRatio(
      const double currentATR,
      const double baselineATR
   ) const
   {
      if(
         currentATR <= 0.0 ||
         baselineATR <= 0.0
      )
      {
         return 1.0;
      }

      return currentATR / baselineATR;
   }


   //===============================================================
   // EXPANSÃO
   //===============================================================

   double CalculateExpansionScore(
      const double ratio
   ) const
   {
      if(ratio <= 1.0)
         return 0.0;

      const double score =
         (ratio - 1.0) * 100.0;

      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   //===============================================================
   // CONTRAÇÃO
   //===============================================================

   double CalculateContractionScore(
      const double ratio
   ) const
   {
      if(ratio >= 1.0)
         return 0.0;

      const double score =
         (1.0 - ratio) * 100.0;

      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   //===============================================================
   // SCORE PRINCIPAL
   //
   // EXPANSÃO  -> positivo
   // CONTRAÇÃO -> negativo
   // RANGE     -> valor próximo de zero
   //===============================================================

   double CalculateVolatilityScore(
      const double ratio,
      const double expansionScore,
      const double contractionScore
   ) const
   {
      double score = 0.0;

      if(ratio > 1.0)
      {
         score =
            expansionScore;
      }
      else
      if(ratio < 1.0)
      {
         score =
            -contractionScore;
      }

      return Clamp(
         score,
         -100.0,
         100.0
      );
   }


   //===============================================================
   // ACELERAÇÃO
   //
   // Compara ATR recente com ATR imediatamente anterior.
   //===============================================================

   double CalculateVolatilityAcceleration(
      const AnalysisContext &ctx,
      const int period
   ) const
   {
      if(period <= 0)
         return 0.0;

      const int count =
         ctx.GetMarketBarCount();

      if(
         count <
         period + 4
      )
      {
         return 0.0;
      }

      const double currentATR =
         CalculateATRFromShift(
            ctx,
            1,
            period
         );

      const double previousATR =
         CalculateATRFromShift(
            ctx,
            2,
            period
         );

      if(
         currentATR <= 0.0 ||
         previousATR <= 0.0
      )
      {
         return 0.0;
      }

      return
         (
            (currentATR - previousATR) /
            previousATR
         ) * 100.0;
   }


   //===============================================================
   // NORMALIZA ACELERAÇÃO
   //===============================================================

   double NormalizeAcceleration(
      const double acceleration
   ) const
   {
      return Clamp(
         acceleration,
         -100.0,
         100.0
      );
   }


   //===============================================================
   // REGIME
   //===============================================================

   ENUM_REGIME DetermineRegime(
      const double ratio
   ) const
   {
      if(
         ratio >=
         m_expansionThreshold
      )
      {
         return REGIME_EXPANSION;
      }

      if(
         ratio <=
         m_contractionThreshold
      )
      {
         return REGIME_CONTRACTION;
      }

      return REGIME_RANGE;
   }


public:

   //===============================================================
   // CONSTRUTOR
   //===============================================================

   VolatilityEngine(
      const int atrPeriod = 14,
      const int baselinePeriod = 14,
      const double expansionThreshold = 1.25,
      const double contractionThreshold = 0.75
   )
   {
      m_atrPeriod =
         MathMax(
            1,
            atrPeriod
         );

      m_baselinePeriod =
         MathMax(
            1,
            baselinePeriod
         );

      m_expansionThreshold =
         MathMax(
            1.01,
            expansionThreshold
         );

      m_contractionThreshold =
         MathMin(
            0.99,
            contractionThreshold
         );
   }


   //===============================================================
   // ANALYZE
   //===============================================================

   bool Analyze(
      AnalysisContext &ctx
   )
   {
      //=============================================================
      // RESET DA CAMADA
      //=============================================================

      ctx.volatilityValue =
         0.0;

      ctx.volatilityScore =
         0.0;

      ctx.volatilityPercent =
         0.0;

      ctx.volatilityRatio =
         0.0;

      ctx.volatilityATR =
         0.0;

      ctx.volatilityATRPercent =
         0.0;

      ctx.volatilityExpansionScore =
         0.0;

      ctx.volatilityContractionScore =
         0.0;

      ctx.volatilityExpanding =
         false;

      ctx.volatilityContracting =
         false;


      //=============================================================
      // VALIDACAO
      //=============================================================

      if(ctx.symbol == "")
      {
         ctx.volatilityState =
            LAYER_INVALID;

         return false;
      }

      if(!ctx.HasMarketHistory())
      {
         ctx.volatilityState =
            LAYER_INVALID;

         return false;
      }

      if(ctx.point <= 0.0)
      {
         ctx.volatilityState =
            LAYER_INVALID;

         return false;
      }


      //=============================================================
      // ATR ATUAL
      //=============================================================

      const double currentATR =
         CalculateATR(
            ctx,
            m_atrPeriod
         );

      if(currentATR <= 0.0)
      {
         ctx.volatilityState =
            LAYER_INVALID;

         return false;
      }


      //=============================================================
      // ATR BASELINE
      //=============================================================

      const double baselineATR =
         CalculateATRBaseline(
            ctx,
            m_atrPeriod,
            m_baselinePeriod
         );

      if(baselineATR <= 0.0)
      {
         ctx.volatilityState =
            LAYER_INVALID;

         return false;
      }


      //=============================================================
      // ATR
      //=============================================================

      ctx.atr =
         currentATR;

      ctx.volatilityATR =
         currentATR;


      //=============================================================
      // VOLATILIDADE EM PONTOS
      //=============================================================

      ctx.volatilityValue =
         currentATR /
         ctx.point;


      //=============================================================
      // RATIO
      //=============================================================

      const double ratio =
         CalculateVolatilityRatio(
            currentATR,
            baselineATR
         );

      ctx.volatilityRatio =
         ratio;


      //=============================================================
      // PREÇO DE REFERÊNCIA
      //
      // Preferência:
      // 1. último candle fechado
      // 2. ctx.close
      // 3. ctx.price
      //=============================================================

      double referencePrice =
         0.0;

      MqlRates referenceBar;

      if(
         ctx.GetMarketBar(
            1,
            referenceBar
         )
      )
      {
         referencePrice =
            referenceBar.close;
      }

      if(referencePrice <= 0.0)
         referencePrice =
            ctx.close;

      if(referencePrice <= 0.0)
         referencePrice =
            ctx.price;


      if(referencePrice > 0.0)
      {
         ctx.volatilityPercent =
            (
               currentATR /
               referencePrice
            ) * 100.0;

         ctx.volatilityATRPercent =
            ctx.volatilityPercent;
      }


      //=============================================================
      // EXPANSÃO
      //=============================================================

      ctx.volatilityExpansionScore =
         CalculateExpansionScore(
            ratio
         );


      //=============================================================
      // CONTRAÇÃO
      //=============================================================

      ctx.volatilityContractionScore =
         CalculateContractionScore(
            ratio
         );


      //=============================================================
      // SCORE
      //=============================================================

      ctx.volatilityScore =
         CalculateVolatilityScore(
            ratio,
            ctx.volatilityExpansionScore,
            ctx.volatilityContractionScore
         );


      //=============================================================
      // FLAGS
      //=============================================================

      ctx.volatilityExpanding =
         (
            ratio >=
            m_expansionThreshold
         );

      ctx.volatilityContracting =
         (
            ratio <=
            m_contractionThreshold
         );


      //=============================================================
      // REGIME DETECTADO
      //=============================================================

      const ENUM_REGIME detectedRegime =
         DetermineRegime(
            ratio
         );


      //=============================================================
      // REGIME
      //
      // A VolatilityEngine somente substitui o regime quando a
      // volatilidade fornece evidência clara de expansão/contração.
      //
      // Em RANGE, mantém o regime já existente no contexto.
      //=============================================================

      if(
         detectedRegime ==
         REGIME_EXPANSION
      )
      {
         ctx.regime =
            REGIME_EXPANSION;
      }
      else
      if(
         detectedRegime ==
         REGIME_CONTRACTION
      )
      {
         ctx.regime =
            REGIME_CONTRACTION;
      }


      //=============================================================
      // SCORE DO REGIME
      //=============================================================

      if(
         detectedRegime ==
         REGIME_EXPANSION
      )
      {
         ctx.regimeScore =
            Clamp(
               ctx.volatilityExpansionScore,
               0.0,
               100.0
            );
      }
      else
      if(
         detectedRegime ==
         REGIME_CONTRACTION
      )
      {
         ctx.regimeScore =
            -Clamp(
               ctx.volatilityContractionScore,
               0.0,
               100.0
            );
      }
      else
      {
         // Range não deve herdar score direcional forte.
         ctx.regimeScore =
            0.0;
      }


      //=============================================================
      // ACELERAÇÃO
      //=============================================================

      const double acceleration =
         CalculateVolatilityAcceleration(
            ctx,
            m_atrPeriod
         );

      const double accelerationScore =
         NormalizeAcceleration(
            acceleration
         );


      //=============================================================
      // VOLATILIDADE COMPOSTA
      //
      // 70% estado relativo
      // 30% aceleração
      //=============================================================

      ctx.volatility =
         Clamp(
            (ctx.volatilityScore * 0.70) +
            (accelerationScore * 0.30),
            -100.0,
            100.0
         );


      //=============================================================
      // ESTADO
      //=============================================================

      ctx.volatilityState =
         LAYER_VALID;


      //=============================================================
      // DEBUG
      //=============================================================

      PrintFormat(
         "[VolatilityEngine] "
         "%s %s | "
         "ATR=%.5f | "
         "ATRPoints=%.2f | "
         "Ratio=%.3f | "
         "VolPct=%.3f | "
         "Expansion=%.2f | "
         "Contraction=%.2f | "
         "Score=%.2f | "
         "Acceleration=%.2f | "
         "Composite=%.2f | "
         "Regime=%s",
         ctx.symbol,
         EnumToString(ctx.primaryTF),
         currentATR,
         ctx.volatilityValue,
         ctx.volatilityRatio,
         ctx.volatilityPercent,
         ctx.volatilityExpansionScore,
         ctx.volatilityContractionScore,
         ctx.volatilityScore,
         acceleration,
         ctx.volatility,
         EnumToString(ctx.regime)
      );

      return true;
   }


   //===============================================================
   // SETTERS
   //===============================================================

   void SetATRPeriod(
      const int period
   )
   {
      m_atrPeriod =
         MathMax(
            1,
            period
         );
   }


   void SetBaselinePeriod(
      const int period
   )
   {
      m_baselinePeriod =
         MathMax(
            1,
            period
         );
   }


   void SetExpansionThreshold(
      const double threshold
   )
   {
      m_expansionThreshold =
         MathMax(
            1.01,
            threshold
         );
   }


   void SetContractionThreshold(
      const double threshold
   )
   {
      m_contractionThreshold =
         MathMin(
            0.99,
            threshold
         );
   }


   //===============================================================
   // GETTERS
   //===============================================================

   int GetATRPeriod() const
   {
      return m_atrPeriod;
   }


   int GetBaselinePeriod() const
   {
      return m_baselinePeriod;
   }


   double GetExpansionThreshold() const
   {
      return m_expansionThreshold;
   }


   double GetContractionThreshold() const
   {
      return m_contractionThreshold;
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_VOLATILITYENGINE_MQH
