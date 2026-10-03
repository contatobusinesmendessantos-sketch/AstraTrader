//+------------------------------------------------------------------+
//| MomentumEngine.mqh                                               |
//| Astra Trader AI                                                  |
//|                                                                  |
//| Engine responsável pela análise de momentum.                     |
//|                                                                  |
//| RESPONSABILIDADES:                                               |
//|  - Calcular RSI                                                  |
//|  - Medir momentum                                                |
//|  - Medir aceleração do momentum                                 |
//|  - Detectar sobrecompra/sobrevenda                              |
//|  - Detectar divergência básica                                  |
//|  - Produzir score direcional                                    |
//|                                                                  |
//| FONTE DE DADOS:                                                  |
//|  ctx.marketBars[]                                                |
//|                                                                  |
//| IMPORTANTE:                                                       |
//|  Esta engine NÃO utiliza CopyRates().                            |
//|  O MarketDataEngine é o único responsável pelo histórico MT5.    |
//|                                                                  |
//| NÃO é responsável por:                                           |
//|  - Decisão BUY/SELL                                              |
//|  - Risk Management                                               |
//|  - SL/TP                                                         |
//|  - Execução de ordens                                            |
//+------------------------------------------------------------------+
#ifndef ASTRA_MOMENTUMENGINE_MQH
#define ASTRA_MOMENTUMENGINE_MQH

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>


//+------------------------------------------------------------------+
//| Momentum Engine                                                  |
//+------------------------------------------------------------------+
class MomentumEngine
  {
private:

   //===============================================================
   // Configuração interna
   //===============================================================

   int m_rsiPeriod;

   int m_momentumPeriod;

   int m_accelerationPeriod;


   //===============================================================
   // Estado interno
   //===============================================================

   double m_rsi;

   double m_momentumValue;

   double m_momentumScore;

   double m_momentumAcceleration;

   double m_momentumAccelerationScore;

   int    m_momentumDivergence;

   bool   m_momentumBullish;

   bool   m_momentumBearish;

   bool   m_overbought;

   bool   m_oversold;


   //===============================================================
   // Clamp
   //===============================================================

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


   //===============================================================
   // Abs
   //===============================================================

   double Abs(
      const double value
   ) const
     {
      return MathAbs(value);
     }


   //===============================================================
   // Reset interno
   //===============================================================

   void Reset()
     {
      m_rsi                       = 50.0;

      m_momentumValue             = 0.0;

      m_momentumScore             = 0.0;

      m_momentumAcceleration      = 0.0;

      m_momentumAccelerationScore = 0.0;

      m_momentumDivergence         = 0;

      m_momentumBullish            = false;

      m_momentumBearish            = false;

      m_overbought                 = false;

      m_oversold                   = false;
     }


   //===============================================================
   // Calcula RSI utilizando marketBars[]
   //
   // marketBars[0] = candle atual
   // marketBars[1] = candle anterior
   //
   // O cálculo utiliza somente candles fechados disponíveis no
   // contexto central.
   //===============================================================

   bool CalculateRSI(
      AnalysisContext &ctx,
      double &result
   ) const
     {
      result = 50.0;

      int count = ctx.GetMarketBarCount();

      if(count < m_rsiPeriod + 1)
         return false;


      double gains = 0.0;

      double losses = 0.0;


      //============================================================
      // Percorre candles do mais antigo para o mais recente.
      //
      // Exemplo:
      //
      // [14] -> [13] -> ... -> [1] -> [0]
      //============================================================

      for(int i=m_rsiPeriod; i>=1; i--)
        {
         double currentClose =
            ctx.marketBars[i-1].close;

         double previousClose =
            ctx.marketBars[i].close;

         double change =
            currentClose-previousClose;


         if(change>0.0)
            gains+=change;

         else
         if(change<0.0)
            losses+=-change;
        }


      double averageGain =
         gains/(double)m_rsiPeriod;

      double averageLoss =
         losses/(double)m_rsiPeriod;


      if(averageLoss<=0.0)
        {
         if(averageGain>0.0)
            result=100.0;
         else
            result=50.0;

         return true;
        }


      double relativeStrength =
         averageGain/averageLoss;


      result =
         100.0-
         (100.0/(1.0+relativeStrength));


      result=
         Clamp(
            result,
            0.0,
            100.0
         );


      return true;
     }


   //===============================================================
   // Calcula momentum percentual
   //
   // Compara o fechamento atual com o fechamento N candles atrás.
   //
   // momentum =
   //
   // (close atual - close anterior) / close anterior * 100
   //===============================================================

   bool CalculateMomentum(
      AnalysisContext &ctx,
      double &result
   ) const
     {
      result=0.0;

      int count=
         ctx.GetMarketBarCount();

      if(count<=m_momentumPeriod+1)
         return false;


      double currentClose=
         ctx.marketBars[1].close;

      double referenceClose=
         ctx.marketBars[m_momentumPeriod+1].close;


      if(currentClose<=0.0 ||
         referenceClose<=0.0)
         return false;


      result=
         ((currentClose-referenceClose)/
          referenceClose)*100.0;


      return true;
     }


   //===============================================================
   // Calcula momentum anterior
   //===============================================================

   bool CalculatePreviousMomentum(
      AnalysisContext &ctx,
      double &result
   ) const
     {
      result=0.0;


      int required=
         m_momentumPeriod+1;


      int count=
         ctx.GetMarketBarCount();


      if(count<=m_momentumPeriod+2)
         return false;


      double currentClose=
         ctx.marketBars[2].close;

      double referenceClose=
         ctx.marketBars[m_momentumPeriod+2].close;


      if(currentClose<=0.0 ||
         referenceClose<=0.0)
         return false;


      result=
         ((currentClose-referenceClose)/
          referenceClose)*100.0;


      return true;
     }


   //===============================================================
   // Calcula aceleração do momentum
   //
   // acceleration =
   // momentum atual - momentum anterior
   //===============================================================

   bool CalculateAcceleration(
      AnalysisContext &ctx,
      double &result
   ) const
     {
      result=0.0;


      double currentMomentum=0.0;

      double previousMomentum=0.0;


      if(!CalculateMomentum(
            ctx,
            currentMomentum
         ))
         return false;


      if(!CalculatePreviousMomentum(
            ctx,
            previousMomentum
         ))
         return false;


      result=
         currentMomentum-
         previousMomentum;


      return true;
     }


   //===============================================================
   // Detecta divergência bullish básica
   //
   // Preço faz lower low enquanto momentum faz higher low.
   //===============================================================

   bool DetectBullishDivergence(
      AnalysisContext &ctx
   ) const
     {
      int count=
         ctx.GetMarketBarCount();


      if(count<10)
         return false;


      double recentLow=
         ctx.marketBars[1].low;

      double previousLow=
         ctx.marketBars[6].low;


      double recentMomentum=
         ctx.marketBars[1].close-
         ctx.marketBars[3].close;

      double previousMomentum=
         ctx.marketBars[6].close-
         ctx.marketBars[8].close;


      if(recentLow>=previousLow)
         return false;


      return
         recentMomentum>
         previousMomentum;
     }


   //===============================================================
   // Detecta divergência bearish básica
   //
   // Preço faz higher high enquanto momentum faz lower high.
   //===============================================================

   bool DetectBearishDivergence(
      AnalysisContext &ctx
   ) const
     {
      int count=
         ctx.GetMarketBarCount();


      if(count<10)
         return false;


      double recentHigh=
         ctx.marketBars[1].high;

      double previousHigh=
         ctx.marketBars[6].high;


      double recentMomentum=
         ctx.marketBars[1].close-
         ctx.marketBars[3].close;

      double previousMomentum=
         ctx.marketBars[6].close-
         ctx.marketBars[8].close;


      if(recentHigh<=previousHigh)
         return false;


      return
         recentMomentum<
         previousMomentum;
     }


   //===============================================================
   // Calcula score de momentum
   //
   // Score:
   //
   // -100 = forte pressão bearish
   //    0 = neutro
   // +100 = forte pressão bullish
   //===============================================================

   double CalculateMomentumScore(
      const double rsi,
      const double momentum,
      const double acceleration
   ) const
     {
      double rsiScore=0.0;

      double momentumScore=0.0;

      double accelerationScore=0.0;


      //============================================================
      // RSI
      //============================================================

      rsiScore=
         (rsi-50.0)*2.0;


      //============================================================
      // Momentum
      //
      // O valor percentual é normalizado para evitar que ativos
      // diferentes produzam scores exagerados.
      //============================================================

      momentumScore=
         momentum*10.0;


      //============================================================
      // Aceleração
      //============================================================

      accelerationScore=
         acceleration*15.0;


      rsiScore=
         Clamp(
            rsiScore,
            -100.0,
            100.0
         );


      momentumScore=
         Clamp(
            momentumScore,
            -100.0,
            100.0
         );


      accelerationScore=
         Clamp(
            accelerationScore,
            -100.0,
            100.0
         );


      //============================================================
      // Combinação
      //============================================================

      double score=
         (rsiScore*0.50)+
         (momentumScore*0.30)+
         (accelerationScore*0.20);


      return
         Clamp(
            score,
            -100.0,
            100.0
         );
     }


   //===============================================================
   // Score da aceleração
   //===============================================================

   double CalculateAccelerationScore(
      const double acceleration
   ) const
     {
      return
         Clamp(
            acceleration*15.0,
            -100.0,
            100.0
         );
     }


   //===============================================================
   // Atualiza estado direcional
   //===============================================================

   void UpdateDirectionalState()
     {
      m_momentumBullish=false;

      m_momentumBearish=false;


      if(m_momentumScore>=15.0)
         m_momentumBullish=true;


      if(m_momentumScore<=-15.0)
         m_momentumBearish=true;
     }


   //===============================================================
   // Atualiza estado RSI
   //===============================================================

   void UpdateRSIState()
     {
      m_overbought=false;

      m_oversold=false;


      if(m_rsi>=70.0)
         m_overbought=true;


      if(m_rsi<=30.0)
         m_oversold=true;
     }


public:


   //===============================================================
   // CONSTRUTOR
   //===============================================================

   MomentumEngine()
     {
      m_rsiPeriod=
         14;

      m_momentumPeriod=
         10;

      m_accelerationPeriod=
         1;

      Reset();
     }


   //===============================================================
   // ANALYZE
   //===============================================================

   bool Analyze(
      AnalysisContext &ctx
   )
     {
      Reset();


      //============================================================
      // Validação básica
      //============================================================

      if(ctx.symbol=="")
         return false;


      int count=
         ctx.GetMarketBarCount();


      //============================================================
      // Necessidade mínima de histórico
      //
      // RSI 14 precisa de 15 candles.
      // Divergência utiliza até o índice 7.
      //============================================================

      int minimumBars=
         m_rsiPeriod+1;


      if(count<minimumBars)
        {
         ctx.momentumState=
            LAYER_INVALID;

         return false;
        }


      //============================================================
      // RSI
      //============================================================

      if(!CalculateRSI(
            ctx,
            m_rsi
         ))
        {
         ctx.momentumState=
            LAYER_INVALID;

         return false;
        }


      //============================================================
      // Momentum
      //============================================================

      if(!CalculateMomentum(
            ctx,
            m_momentumValue
         ))
        {
         ctx.momentumState=
            LAYER_INVALID;

         return false;
        }


      //============================================================
      // Aceleração
      //============================================================

      if(!CalculateAcceleration(
            ctx,
            m_momentumAcceleration
         ))
        {
         m_momentumAcceleration=0.0;
        }


      //============================================================
      // Score de aceleração
      //============================================================

      m_momentumAccelerationScore=
         CalculateAccelerationScore(
            m_momentumAcceleration
         );


      //============================================================
      // Score final
      //============================================================

      m_momentumScore=
         CalculateMomentumScore(
            m_rsi,
            m_momentumValue,
            m_momentumAcceleration
         );


      //============================================================
      // Estado RSI
      //============================================================

      UpdateRSIState();


      //============================================================
      // Estado direcional
      //============================================================

      UpdateDirectionalState();


      //============================================================
      // Divergência
      //
      //  1 = bullish divergence
      // -1 = bearish divergence
      //  0 = nenhuma
      //============================================================

      m_momentumDivergence=0;


      bool bullishDivergence=
         DetectBullishDivergence(
            ctx
         );


      bool bearishDivergence=
         DetectBearishDivergence(
            ctx
         );


      if(bullishDivergence &&
         !bearishDivergence)
        {
         m_momentumDivergence=1;

         // Divergência bullish aumenta a leitura positiva,
         // sem transformar automaticamente a decisão em BUY.
         m_momentumScore+=10.0;
        }
      else
      if(bearishDivergence &&
         !bullishDivergence)
        {
         m_momentumDivergence=-1;

         // Divergência bearish aumenta a leitura negativa.
         m_momentumScore-=10.0;
        }


      //============================================================
      // Clamp final
      //============================================================

      m_momentumScore=
         Clamp(
            m_momentumScore,
            -100.0,
            100.0
         );


      //============================================================
      // Atualiza novamente direção após divergência
      //============================================================

      UpdateDirectionalState();


      //============================================================
      // Escreve no AnalysisContext
      //============================================================

      ctx.rsi=
         m_rsi;


      ctx.momentumValue=
         m_momentumValue;


      ctx.momentumScore=
         m_momentumScore;


      ctx.momentumAcceleration=
         m_momentumAcceleration;


      ctx.momentumAccelerationScore=
         m_momentumAccelerationScore;


      ctx.momentumDivergence=
         m_momentumDivergence;


      ctx.momentumBullish=
         m_momentumBullish;


      ctx.momentumBearish=
         m_momentumBearish;


      ctx.overbought=
         m_overbought;


      ctx.oversold=
         m_oversold;


      //============================================================
      // Estado da camada
      //============================================================

      ctx.momentumState=
         LAYER_VALID;


      return true;
     }


   //===============================================================
   // GETTERS
   //===============================================================

   double GetRSI() const
     {
      return m_rsi;
     }


   double GetMomentumValue() const
     {
      return m_momentumValue;
     }


   double GetMomentumScore() const
     {
      return m_momentumScore;
     }


   double GetMomentumAcceleration() const
     {
      return m_momentumAcceleration;
     }


   double GetMomentumAccelerationScore() const
     {
      return m_momentumAccelerationScore;
     }


   int GetMomentumDivergence() const
     {
      return m_momentumDivergence;
     }


   bool IsMomentumBullish() const
     {
      return m_momentumBullish;
     }


   bool IsMomentumBearish() const
     {
      return m_momentumBearish;
     }


   bool IsOverbought() const
     {
      return m_overbought;
     }


   bool IsOversold() const
     {
      return m_oversold;
     }


   //===============================================================
   // DEBUG
   //===============================================================

   string ToString() const
     {
      return StringFormat(
         "[MomentumEngine] "
         "RSI=%.2f "
         "Momentum=%.2f "
         "Score=%.2f "
         "Acceleration=%.2f "
         "AccelerationScore=%.2f "
         "Divergence=%d "
         "Bullish=%s "
         "Bearish=%s "
         "Overbought=%s "
         "Oversold=%s",
         m_rsi,
         m_momentumValue,
         m_momentumScore,
         m_momentumAcceleration,
         m_momentumAccelerationScore,
         m_momentumDivergence,
         m_momentumBullish ? "true" : "false",
         m_momentumBearish ? "true" : "false",
         m_overbought ? "true" : "false",
         m_oversold ? "true" : "false"
      );
     }
  };


//+------------------------------------------------------------------+
//| FIM                                                                |
//+------------------------------------------------------------------+
#endif // ASTRA_MOMENTUMENGINE_MQH
//+------------------------------------------------------------------+
