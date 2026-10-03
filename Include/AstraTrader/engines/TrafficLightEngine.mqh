//+------------------------------------------------------------------+
//| TrafficLightEngine.mqh                                          |
//| Astra Trader AI                                                 |
//|                                                                  |
//| CAMADA DE CONFIRMACAO DE TENDENCIA MULTI-TIMEFRAME              |
//|                                                                  |
//| CONTRATO:                                                        |
//|   - trafficDirection = direção                                  |
//|   - trafficLightScore = magnitude 0..100                         |
//|   - análise utiliza somente candles fechados                     |
//|                                                                  |
//| IMPORTANTE:                                                      |
//|   Este engine NÃO utiliza trafficLightState porque esse campo    |
//|   não faz parte do AnalysisContext atual do projeto.             |
//+------------------------------------------------------------------+
#ifndef ASTRA_TRAFFICLIGHTENGINE_MQH
#define ASTRA_TRAFFICLIGHTENGINE_MQH

#include <AstraTrader\Analysis\AnalysisContext.mqh>
#include <AstraTrader\Core\Types.mqh>


//+------------------------------------------------------------------+
//| TrafficLightEngine                                               |
//+------------------------------------------------------------------+
class TrafficLightEngine
{
private:

   //=================================================================
   // EMA
   //=================================================================

   int m_periodEMA9;
   int m_periodEMA21;
   int m_periodEMA50;
   int m_periodEMA200;


   //=================================================================
   // PESOS MTF
   //=================================================================

   double m_weightD1;
   double m_weightH4;
   double m_weightH1;
   double m_weightM15;
   double m_weightM5;


   //=================================================================
   // NORMALIZA PESOS
   //=================================================================

   void NormalizeWeights()
   {
      double total =
         m_weightD1 +
         m_weightH4 +
         m_weightH1 +
         m_weightM15 +
         m_weightM5;

      if(total <= 0.0)
      {
         m_weightD1  = 0.20;
         m_weightH4  = 0.20;
         m_weightH1  = 0.20;
         m_weightM15 = 0.25;
         m_weightM5  = 0.15;

         return;
      }

      m_weightD1  /= total;
      m_weightH4  /= total;
      m_weightH1  /= total;
      m_weightM15 /= total;
      m_weightM5  /= total;
   }


   //=================================================================
   // EMA
   //
   // index 0 = mais antigo
   // último índice = mais recente
   //
   // Seed = SMA inicial.
   //=================================================================

   double CalculateEMA(
      const double &data[],
      const int period
   )
   {
      const int n =
         ArraySize(data);

      if(
         period <= 0 ||
         n < period
      )
      {
         return 0.0;
      }

      double seed =
         0.0;

      for(
         int i = 0;
         i < period;
         i++
      )
      {
         seed += data[i];
      }

      seed /=
         (double)period;

      const double k =
         2.0 /
         ((double)period + 1.0);

      double ema =
         seed;

      for(
         int i = period;
         i < n;
         i++
      )
      {
         ema =
            data[i] * k +
            ema * (1.0 - k);
      }

      return ema;
   }


   //=================================================================
   // SLOPE
   //=================================================================

   double CalculateSlope(
      const double &data[],
      const int lookback
   )
   {
      const int n =
         ArraySize(data);

      if(
         lookback <= 0 ||
         n < lookback + 1
      )
      {
         return 0.0;
      }

      return
         data[n - 1] -
         data[n - 1 - lookback];
   }


   //=================================================================
   // ANALISA UM TIMEFRAME
   //
   // start_pos=1:
   // somente candles fechados.
   //=================================================================

   ENUM_TRAFFIC_LIGHT AnalyzeTimeframe(
      const AnalysisContext &context,
      const string symbol,
      const ENUM_TIMEFRAMES timeframe,
      const MqlRates &series[],
      ENUM_TRAFFIC_DIRECTION &direction,
      double &score
   )
   {
      direction =
         TRAFFIC_NONE;

      score =
         0.0;

      if(
         symbol == "" ||
         timeframe == PERIOD_CURRENT ||
         ArraySize(series) < 10
      )
      {
         return TRAFFIC_YELLOW;
      }


      //==============================================================
      // HISTÓRICO CENTRAL DO PIPELINE
      //==============================================================

      const int count =
         ArraySize(series);

      double closes[];

      if(
         ArrayResize(
            closes,
            count
         ) != count
      )
      {
         return TRAFFIC_YELLOW;
      }

      for(
         int i = 0;
         i < count;
         i++
      )
      {
         closes[i] =
            series[count - 1 - i].close;
      }


      //==============================================================
      // EMAs
      //==============================================================

      const double ema9 =
         CalculateEMA(
            closes,
            m_periodEMA9
         );

      const double ema21 =
         CalculateEMA(
            closes,
            m_periodEMA21
         );

      const double ema50 =
         CalculateEMA(
            closes,
            m_periodEMA50
         );

      const double ema200 =
         CalculateEMA(
            closes,
            m_periodEMA200
         );


      if(
         ema9 <= 0.0 ||
         ema21 <= 0.0 ||
         ema50 <= 0.0 ||
         ema200 <= 0.0
      )
      {
         return TRAFFIC_YELLOW;
      }


      //==============================================================
      // ÚLTIMO CANDLE FECHADO
      //==============================================================

      const double price =
         closes[ArraySize(closes) - 1];

      if(price <= 0.0)
         return TRAFFIC_YELLOW;


      //==============================================================
      // SLOPES
      //==============================================================

      const double slope9 =
         CalculateSlope(
            closes,
            5
         );

      const double slope21 =
         CalculateSlope(
            closes,
            10
         );


      //==============================================================
      // PONTOS
      //==============================================================

      double bullishPoints =
         0.0;

      double bearishPoints =
         0.0;


      //==============================================================
      // 1. EMA ALIGNMENT
      //==============================================================

      if(
         ema9 > ema21 &&
         ema21 > ema50
      )
      {
         bullishPoints += 30.0;
      }
      else
      if(
         ema9 < ema21 &&
         ema21 < ema50
      )
      {
         bearishPoints += 30.0;
      }


      //==============================================================
      // 2. PRICE VS EMA50
      //==============================================================

      if(price > ema50)
      {
         bullishPoints += 20.0;
      }
      else
      if(price < ema50)
      {
         bearishPoints += 20.0;
      }


      //==============================================================
      // 3. PRICE VS EMA200
      //==============================================================

      if(price > ema200)
      {
         bullishPoints += 15.0;
      }
      else
      if(price < ema200)
      {
         bearishPoints += 15.0;
      }


      //==============================================================
      // 4. MOMENTUM
      //==============================================================

      if(
         slope9 > 0.0 &&
         slope21 > 0.0
      )
      {
         bullishPoints += 20.0;
      }
      else
      if(
         slope9 < 0.0 &&
         slope21 < 0.0
      )
      {
         bearishPoints += 20.0;
      }


      //==============================================================
      // 5. ACELERAÇÃO
      //==============================================================
      //
      // A comparação só recebe pontos quando a diferença ocorre
      // na mesma direção do slope.
      //==============================================================

      if(
         slope9 > slope21 &&
         slope9 > 0.0
      )
      {
         bullishPoints += 15.0;
      }
      else
      if(
         slope9 < slope21 &&
         slope9 < 0.0
      )
      {
         bearishPoints += 15.0;
      }


      //==============================================================
      // TOTAL
      //==============================================================

      const double totalPoints =
         bullishPoints +
         bearishPoints;

      if(totalPoints <= 0.0)
      {
         direction =
            TRAFFIC_NONE;

         score =
            0.0;

         return TRAFFIC_YELLOW;
      }


      //==============================================================
      // NET SCORE
      //==============================================================

      const double netScore =
         (
            (bullishPoints -
             bearishPoints) /
            totalPoints
         ) * 100.0;


      //==============================================================
      // DIREÇÃO
      //==============================================================

      if(netScore > 20.0)
      {
         direction =
            TRAFFIC_BULLISH;

         score =
            bullishPoints;
      }
      else
      if(netScore < -20.0)
      {
         direction =
            TRAFFIC_BEARISH;

         score =
            bearishPoints;
      }
      else
      {
         direction =
            TRAFFIC_NONE;

         score =
            MathMax(
               bullishPoints,
               bearishPoints
            );

         return TRAFFIC_YELLOW;
      }


      //==============================================================
      // CLASSIFICAÇÃO INDIVIDUAL — CORRIGIDA
      //
      // A classificação precisa respeitar a DIREÇÃO.
      //
      // Antes:
      //   score >= 80 -> STRONG_GREEN
      //   score >= 60 -> GREEN
      //
      // O problema era que isso acontecia também quando
      // direction == TRAFFIC_BEARISH.
      //
      // Agora:
      //
      // BULLISH:
      //   >= 80 -> STRONG_GREEN
      //   >= 60 -> GREEN
      //   <  60 -> YELLOW
      //
      // BEARISH:
      //   qualquer sinal bearish confirmado -> RED
      //
      // NONE:
      //   YELLOW
      //
      // IMPORTANTE:
      // score representa MAGNITUDE.
      // A direção é determinada separadamente por netScore.
      // Portanto, score sozinho não pode definir BUY/GREEN.
      //==============================================================

      if(direction == TRAFFIC_BULLISH)
      {
         if(score >= 80.0)
            return TRAFFIC_STRONG_GREEN;

         if(score >= 60.0)
            return TRAFFIC_GREEN;

         return TRAFFIC_YELLOW;
      }


      if(direction == TRAFFIC_BEARISH)
      {
         return TRAFFIC_RED;
      }


      // TRAFFIC_NONE
      return TRAFFIC_YELLOW;
   }


public:

   //=================================================================
   // CONSTRUTOR
   //=================================================================

   TrafficLightEngine()
   {
      m_periodEMA9   = 9;
      m_periodEMA21  = 21;
      m_periodEMA50  = 50;
      m_periodEMA200 = 200;

      m_weightD1  = 0.20;
      m_weightH4  = 0.20;
      m_weightH1  = 0.20;
      m_weightM15 = 0.25;
      m_weightM5  = 0.15;

      NormalizeWeights();
   }


   //=================================================================
   // CONFIGURA PESOS
   //=================================================================

   void SetWeights(
      const double d1,
      const double h4,
      const double h1,
      const double m15,
      const double m5
   )
   {
      m_weightD1 =
         MathMax(
            0.0,
            d1
         );

      m_weightH4 =
         MathMax(
            0.0,
            h4
         );

      m_weightH1 =
         MathMax(
            0.0,
            h1
         );

      m_weightM15 =
         MathMax(
            0.0,
            m15
         );

      m_weightM5 =
         MathMax(
            0.0,
            m5
         );

      NormalizeWeights();
   }


   //=================================================================
   // ANALYZE
   //=================================================================

   bool Analyze(
      AnalysisContext &context
   )
   {
      //==============================================================
      // RESET
      //==============================================================

      context.trafficLight =
         TRAFFIC_YELLOW;

      context.trafficDirection =
         TRAFFIC_NONE;

      context.trafficLightScore =
         0.0;

      context.trafficD1 =
         TRAFFIC_YELLOW;

      context.trafficH4 =
         TRAFFIC_YELLOW;

      context.trafficH1 =
         TRAFFIC_YELLOW;

      context.trafficM15 =
         TRAFFIC_YELLOW;

      context.trafficM5 =
         TRAFFIC_YELLOW;

      context.trafficBullishScore =
         0.0;

      context.trafficBearishScore =
         0.0;

      context.trafficTrendAligned =
         false;

      context.trafficMomentumAligned =
         false;

      context.trafficMTFAligned =
         false;
      context.mtfCanonicalState =
         ASTRA_MTF_NEUTRAL;
      context.mtfCanonicalDirection =
         TRAFFIC_NONE;


      //==============================================================
      // VALIDAÇÃO
      //==============================================================

      if(context.symbol == "")
      {
         return false;
      }


      if(!context.mtfDataReady)
      {
         return false;
      }


      //==============================================================
      // TIMEFRAMES
      //==============================================================

      ENUM_TRAFFIC_DIRECTION dirD1 =
         TRAFFIC_NONE;

      ENUM_TRAFFIC_DIRECTION dirH4 =
         TRAFFIC_NONE;

      ENUM_TRAFFIC_DIRECTION dirH1 =
         TRAFFIC_NONE;

      ENUM_TRAFFIC_DIRECTION dirM15 =
         TRAFFIC_NONE;

      ENUM_TRAFFIC_DIRECTION dirM5 =
         TRAFFIC_NONE;


      double scoreD1 =
         0.0;

      double scoreH4 =
         0.0;

      double scoreH1 =
         0.0;

      double scoreM15 =
         0.0;

      double scoreM5 =
         0.0;


      context.trafficD1 =
         AnalyzeTimeframe(
            context,
            context.symbol,
            PERIOD_D1,
            context.mtfD1,
            dirD1,
            scoreD1
         );

      context.trafficH4 =
         AnalyzeTimeframe(
            context,
            context.symbol,
            PERIOD_H4,
            context.mtfH4,
            dirH4,
            scoreH4
         );

      context.trafficH1 =
         AnalyzeTimeframe(
            context,
            context.symbol,
            PERIOD_H1,
            context.mtfH1,
            dirH1,
            scoreH1
         );

      context.trafficM15 =
         AnalyzeTimeframe(
            context,
            context.symbol,
            PERIOD_M15,
            context.mtfM15,
            dirM15,
            scoreM15
         );

      context.trafficM5 =
         AnalyzeTimeframe(
            context,
            context.symbol,
            PERIOD_M5,
            context.mtfM5,
            dirM5,
            scoreM5
         );


      //==============================================================
      // SCORE PONDERADO
      //
      // Bullish = positivo
      // Bearish = negativo
      //==============================================================

      double weightedScore =
         0.0;


      if(dirD1 == TRAFFIC_BULLISH)
         weightedScore +=
            scoreD1 *
            m_weightD1;
      else
      if(dirD1 == TRAFFIC_BEARISH)
         weightedScore -=
            scoreD1 *
            m_weightD1;


      if(dirH4 == TRAFFIC_BULLISH)
         weightedScore +=
            scoreH4 *
            m_weightH4;
      else
      if(dirH4 == TRAFFIC_BEARISH)
         weightedScore -=
            scoreH4 *
            m_weightH4;


      if(dirH1 == TRAFFIC_BULLISH)
         weightedScore +=
            scoreH1 *
            m_weightH1;
      else
      if(dirH1 == TRAFFIC_BEARISH)
         weightedScore -=
            scoreH1 *
            m_weightH1;


      if(dirM15 == TRAFFIC_BULLISH)
         weightedScore +=
            scoreM15 *
            m_weightM15;
      else
      if(dirM15 == TRAFFIC_BEARISH)
         weightedScore -=
            scoreM15 *
            m_weightM15;


      if(dirM5 == TRAFFIC_BULLISH)
         weightedScore +=
            scoreM5 *
            m_weightM5;
      else
      if(dirM5 == TRAFFIC_BEARISH)
         weightedScore -=
            scoreM5 *
            m_weightM5;


      weightedScore =
         MathMax(
            -100.0,
            MathMin(
               100.0,
               weightedScore
            )
         );


      //==============================================================
      // DIREÇÃO GLOBAL
      //==============================================================

      if(weightedScore > 20.0)
      {
         context.trafficDirection =
            TRAFFIC_BULLISH;
      }
      else
      if(weightedScore < -20.0)
      {
         context.trafficDirection =
            TRAFFIC_BEARISH;
      }
      else
      {
         context.trafficDirection =
            TRAFFIC_NONE;
      }


      //==============================================================
      // CONTAGEM MTF
      //==============================================================

      int bullishCount =
         0;

      int bearishCount =
         0;

      int neutralCount =
         0;


      if(dirD1 == TRAFFIC_BULLISH)
         bullishCount++;
      else
      if(dirD1 == TRAFFIC_BEARISH)
         bearishCount++;
      else
         neutralCount++;


      if(dirH4 == TRAFFIC_BULLISH)
         bullishCount++;
      else
      if(dirH4 == TRAFFIC_BEARISH)
         bearishCount++;
      else
         neutralCount++;


      if(dirH1 == TRAFFIC_BULLISH)
         bullishCount++;
      else
      if(dirH1 == TRAFFIC_BEARISH)
         bearishCount++;
      else
         neutralCount++;


      if(dirM15 == TRAFFIC_BULLISH)
         bullishCount++;
      else
      if(dirM15 == TRAFFIC_BEARISH)
         bearishCount++;
      else
         neutralCount++;


      if(dirM5 == TRAFFIC_BULLISH)
         bullishCount++;
      else
      if(dirM5 == TRAFFIC_BEARISH)
         bearishCount++;
      else
         neutralCount++;


      //==============================================================
      // ALINHAMENTO MTF
      //==============================================================

      context.trafficMTFAligned =
         (
            bullishCount >= 4 ||
            bearishCount >= 4
         );


      context.trafficTrendAligned =
         context.trafficMTFAligned;


      context.trafficMomentumAligned =
         (
            dirH1 != TRAFFIC_NONE &&
            dirM15 != TRAFFIC_NONE &&
            dirH1 == dirM15
         );


      //==============================================================
      // SCORES DIRECIONAIS
      //==============================================================

      double totalBullish =
         0.0;

      double totalBearish =
         0.0;


      if(dirD1 == TRAFFIC_BULLISH)
         totalBullish +=
            scoreD1 *
            m_weightD1;

      if(dirD1 == TRAFFIC_BEARISH)
         totalBearish +=
            scoreD1 *
            m_weightD1;


      if(dirH4 == TRAFFIC_BULLISH)
         totalBullish +=
            scoreH4 *
            m_weightH4;

      if(dirH4 == TRAFFIC_BEARISH)
         totalBearish +=
            scoreH4 *
            m_weightH4;


      if(dirH1 == TRAFFIC_BULLISH)
         totalBullish +=
            scoreH1 *
            m_weightH1;

      if(dirH1 == TRAFFIC_BEARISH)
         totalBearish +=
            scoreH1 *
            m_weightH1;


      if(dirM15 == TRAFFIC_BULLISH)
         totalBullish +=
            scoreM15 *
            m_weightM15;

      if(dirM15 == TRAFFIC_BEARISH)
         totalBearish +=
            scoreM15 *
            m_weightM15;


      if(dirM5 == TRAFFIC_BULLISH)
         totalBullish +=
            scoreM5 *
            m_weightM5;

      if(dirM5 == TRAFFIC_BEARISH)
         totalBearish +=
            scoreM5 *
            m_weightM5;


      context.trafficBullishScore =
         totalBullish;

      context.trafficBearishScore =
         totalBearish;

      // Exporta a leitura MTF para o AnalysisContext, que é a fonte de
      // verdade consumida pelas etapas seguintes do pipeline.
      context.d1Score =
         dirD1 == TRAFFIC_BULLISH ? scoreD1 :
         dirD1 == TRAFFIC_BEARISH ? -scoreD1 : 0.0;

      context.h4Score =
         dirH4 == TRAFFIC_BULLISH ? scoreH4 :
         dirH4 == TRAFFIC_BEARISH ? -scoreH4 : 0.0;

      context.h1Score =
         dirH1 == TRAFFIC_BULLISH ? scoreH1 :
         dirH1 == TRAFFIC_BEARISH ? -scoreH1 : 0.0;

      context.m15Score =
         dirM15 == TRAFFIC_BULLISH ? scoreM15 :
         dirM15 == TRAFFIC_BEARISH ? -scoreM15 : 0.0;

      context.m5Score =
         dirM5 == TRAFFIC_BULLISH ? scoreM5 :
         dirM5 == TRAFFIC_BEARISH ? -scoreM5 : 0.0;

      context.alignedBullishTFs = bullishCount;
      context.alignedBearishTFs = bearishCount;
      context.neutralTFCount = neutralCount;

      if(dirD1 != TRAFFIC_NONE &&
         dirH4 != TRAFFIC_NONE &&
         dirD1 != dirH4)
      {
         context.mtfCanonicalState = ASTRA_MTF_CONFLICT;
         context.mtfCanonicalDirection = TRAFFIC_NONE;
      }
      else
      {
         const ENUM_TRAFFIC_DIRECTION higherTFDirection =
            dirD1 != TRAFFIC_NONE ? dirD1 : dirH4;

         if(higherTFDirection != TRAFFIC_NONE)
         {
            context.mtfCanonicalDirection = higherTFDirection;
            context.mtfCanonicalState =
               dirH1 != TRAFFIC_NONE && dirH1 != higherTFDirection
               ? ASTRA_MTF_CONFLICT
               : ASTRA_MTF_ALIGNED;
         }
         else if(dirH1 != TRAFFIC_NONE)
         {
            context.mtfCanonicalState = ASTRA_MTF_ALIGNED;
            context.mtfCanonicalDirection = dirH1;
         }
         else
         {
            context.mtfCanonicalState = ASTRA_MTF_NEUTRAL;
            context.mtfCanonicalDirection = TRAFFIC_NONE;
         }
      }


      //==============================================================
      // CONFLITO MTF
      //
      // Não criamos um novo campo no AnalysisContext.
      // O conflito é utilizado somente para classificar o semáforo.
      //==============================================================

      const bool strongMTFConflict =
         (
            bullishCount >= 2 &&
            bearishCount >= 2
         );


      //==============================================================
      // CLASSIFICAÇÃO GLOBAL
      //
      // O valor global continua sendo derivado do weightedScore.
      //
      // TRAFFIC_RED NÃO significa bloqueio.
      // Significa sinal global bearish.
      //==============================================================

      if(strongMTFConflict)
      {
         context.trafficLight =
            TRAFFIC_YELLOW;
      }
      else
      if(weightedScore >= 60.0)
      {
         context.trafficLight =
            TRAFFIC_STRONG_GREEN;
      }
      else
      if(weightedScore >= 30.0)
      {
         context.trafficLight =
            TRAFFIC_GREEN;
      }
      else
      if(weightedScore >= -30.0)
      {
         context.trafficLight =
            TRAFFIC_YELLOW;
      }
      else
      {
         context.trafficLight =
            TRAFFIC_RED;
      }


      //==============================================================
      // SCORE = MAGNITUDE
      //==============================================================

      context.trafficLightScore =
         MathAbs(
            weightedScore
         );


      //==============================================================
      // DEBUG / AUDITORIA
      //
      // IMPORTANTE:
      // Agora o log mostra separadamente:
      //
      // 1. classificação individual:
      //    trafficD1/H4/H1/M15/M5
      //
      // 2. direção matemática individual:
      //    dirD1/H4/H1/M15/M5
      //
      // 3. score individual.
      //
      // Isso impede que uma classificação visual seja confundida
      // com a direção utilizada pelo cálculo.
      //==============================================================

      PrintFormat(
         "[TrafficLightEngine] "
         "Light=%s | "
         "Direction=%s | "
         "Score=%.2f | "
         "BullishScore=%.2f | "
         "BearishScore=%.2f | "
         "D1=%s | "
         "DirD1=%s | "
         "ScoreD1=%.2f | "
         "H4=%s | "
         "DirH4=%s | "
         "ScoreH4=%.2f | "
         "H1=%s | "
         "DirH1=%s | "
         "ScoreH1=%.2f | "
         "M15=%s | "
         "DirM15=%s | "
         "ScoreM15=%.2f | "
         "M5=%s | "
         "DirM5=%s | "
         "ScoreM5=%.2f | "
         "BullishCount=%d | "
         "BearishCount=%d | "
         "NeutralCount=%d | "
         "MTF_Aligned=%s | "
         "Conflict=%s",
         EnumToString(
            context.trafficLight
         ),
         EnumToString(
            context.trafficDirection
         ),
         context.trafficLightScore,
         context.trafficBullishScore,
         context.trafficBearishScore,

         EnumToString(
            context.trafficD1
         ),
         EnumToString(
            dirD1
         ),
         scoreD1,

         EnumToString(
            context.trafficH4
         ),
         EnumToString(
            dirH4
         ),
         scoreH4,

         EnumToString(
            context.trafficH1
         ),
         EnumToString(
            dirH1
         ),
         scoreH1,

         EnumToString(
            context.trafficM15
         ),
         EnumToString(
            dirM15
         ),
         scoreM15,

         EnumToString(
            context.trafficM5
         ),
         EnumToString(
            dirM5
         ),
         scoreM5,

         bullishCount,
         bearishCount,
         neutralCount,

         context.trafficMTFAligned
            ? "true"
            : "false",

         strongMTFConflict
            ? "true"
            : "false"
      );

      return true;
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_TRAFFICLIGHTENGINE_MQH
