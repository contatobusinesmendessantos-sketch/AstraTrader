//+------------------------------------------------------------------+
//| OrderBlockEngine.mqh                                             |
//| Astra Trader AI                                                  |
//|                                                                  |
//| ORDER BLOCK / FVG ENGINE                                         |
//|                                                                  |
//| REGRA ARQUITETURAL:                                              |
//| - NÃO utiliza CopyRates()                                        |
//| - consome exclusivamente AnalysisContext.marketBars[]           |
//| - NÃO decide BUY/SELL                                            |
//| - NÃO calcula lote                                               |
//| - NÃO calcula SL/TP                                               |
//| - NÃO executa ordens                                             |
//+------------------------------------------------------------------+
#ifndef ASTRA_ORDERBLOCKENGINE_MQH
#define ASTRA_ORDERBLOCKENGINE_MQH

#property strict

#include <AstraTrader\Analysis\AnalysisContext.mqh>


//==================================================================
// CONFIGURAÇÃO
//==================================================================
#define ASTRA_OB_MIN_BODY_RATIO       0.55
#define ASTRA_OB_MIN_IMPULSE_RATIO    1.20
#define ASTRA_OB_MAX_AGE_BARS         100

#define ASTRA_FVG_MIN_GAP_POINTS      1.0


class OrderBlockEngine
{
private:

   string m_status;
   bool   m_operational;

   double m_lastBullishOBHigh;
   double m_lastBullishOBLow;
   double m_bullishStrength;

   double m_lastBearishOBHigh;
   double m_lastBearishOBLow;
   double m_bearishStrength;

   bool m_bullishOB;
   bool m_bearishOB;

   bool m_bullishFVG;
   bool m_bearishFVG;

   bool m_mitigation;


   //=================================================================
   // CLAMP
   //=================================================================
   double ClampScore(
      const double value
   ) const
   {
      if(value < 0.0)
         return 0.0;

      if(value > 100.0)
         return 100.0;

      return value;
   }


   double ClampSigned(
      const double value
   ) const
   {
      return MathMax(
         -100.0,
         MathMin(
            100.0,
            value
         )
      );
   }


   //=================================================================
   // BODY
   //=================================================================
   double CandleBody(
      const double openPrice,
      const double closePrice
   ) const
   {
      return MathAbs(
         closePrice -
         openPrice
      );
   }


   //=================================================================
   // RANGE
   //=================================================================
   double CandleRange(
      const double highPrice,
      const double lowPrice
   ) const
   {
      return (
         highPrice -
         lowPrice
      );
   }


   //=================================================================
   // BODY RATIO
   //=================================================================
   double BodyRatio(
      const double openPrice,
      const double closePrice,
      const double highPrice,
      const double lowPrice
   ) const
   {
      double range =
         CandleRange(
            highPrice,
            lowPrice
         );

      if(range <= 0.0)
         return 0.0;

      return
         CandleBody(
            openPrice,
            closePrice
         ) /
         range;
   }


   //=================================================================
   // IMPULSE RATIO
   //=================================================================
   double ImpulseRatio(
      const double currentOpen,
      const double currentClose,
      const double previousOpen,
      const double previousClose
   ) const
   {
      double previousBody =
         CandleBody(
            previousOpen,
            previousClose
         );

      if(previousBody <= 0.0)
         return 0.0;

      return
         CandleBody(
            currentOpen,
            currentClose
         ) /
         previousBody;
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

      m_lastBullishOBHigh =
         0.0;

      m_lastBullishOBLow =
         0.0;

      m_bullishStrength =
         0.0;

      m_lastBearishOBHigh =
         0.0;

      m_lastBearishOBLow =
         0.0;

      m_bearishStrength =
         0.0;

      m_bullishOB =
         false;

      m_bearishOB =
         false;

      m_bullishFVG =
         false;

      m_bearishFVG =
         false;

      m_mitigation =
         false;
   }


   //=================================================================
   // DETECT BULLISH OB
   //=================================================================
   bool DetectBullishOrderBlock(
      const MqlRates &previous,
      const MqlRates &current,
      AnalysisContext &context
   )
   {
      double previousBody =
         CandleBody(
            previous.open,
            previous.close
         );

      double previousRange =
         CandleRange(
            previous.high,
            previous.low
         );

      if(previousRange <= 0.0)
         return false;


      double currentBody =
         CandleBody(
            current.open,
            current.close
         );

      if(currentBody <= 0.0)
         return false;


      // Candle anterior bearish.
      if(previous.close >= previous.open)
         return false;


      // Candle atual bullish.
      if(current.close <= current.open)
         return false;


      double bodyRatio =
         previousBody /
         previousRange;

      if(
         bodyRatio <
         ASTRA_OB_MIN_BODY_RATIO
      )
      {
         return false;
      }


      double impulseRatio =
         currentBody /
         previousBody;

      if(
         impulseRatio <
         ASTRA_OB_MIN_IMPULSE_RATIO
      )
      {
         return false;
      }


      m_bullishOB =
         true;

      m_lastBullishOBHigh =
         previous.high;

      m_lastBullishOBLow =
         previous.low;


      double strength =
         50.0;

      strength +=
         bodyRatio * 25.0;

      strength +=
         MathMin(
            25.0,
            impulseRatio * 10.0
         );


      m_bullishStrength =
         ClampScore(
            strength
         );


      context.orderBlock =
         true;

      context.orderBlockValid =
         true;

      context.orderBlockStrength =
         m_bullishStrength;


      return true;
   }


   //=================================================================
   // DETECT BEARISH OB
   //=================================================================
   bool DetectBearishOrderBlock(
      const MqlRates &previous,
      const MqlRates &current,
      AnalysisContext &context
   )
   {
      double previousBody =
         CandleBody(
            previous.open,
            previous.close
         );

      double previousRange =
         CandleRange(
            previous.high,
            previous.low
         );

      if(previousRange <= 0.0)
         return false;


      double currentBody =
         CandleBody(
            current.open,
            current.close
         );

      if(currentBody <= 0.0)
         return false;


      // Candle anterior bullish.
      if(previous.close <= previous.open)
         return false;


      // Candle atual bearish.
      if(current.close >= current.open)
         return false;


      double bodyRatio =
         previousBody /
         previousRange;

      if(
         bodyRatio <
         ASTRA_OB_MIN_BODY_RATIO
      )
      {
         return false;
      }


      double impulseRatio =
         currentBody /
         previousBody;

      if(
         impulseRatio <
         ASTRA_OB_MIN_IMPULSE_RATIO
      )
      {
         return false;
      }


      m_bearishOB =
         true;

      m_lastBearishOBHigh =
         previous.high;

      m_lastBearishOBLow =
         previous.low;


      double strength =
         50.0;

      strength +=
         bodyRatio * 25.0;

      strength +=
         MathMin(
            25.0,
            impulseRatio * 10.0
         );


      m_bearishStrength =
         ClampScore(
            strength
         );


      context.orderBlock =
         true;

      context.orderBlockValid =
         true;

      context.orderBlockStrength =
         m_bearishStrength;


      return true;
   }


   //=================================================================
   // BULLISH FVG
   //=================================================================
   bool DetectBullishFVG(
      const MqlRates &older,
      const MqlRates &middle,
      const MqlRates &newer,
      AnalysisContext &context
   )
   {
      if(
         middle.close <=
         middle.open
      )
      {
         return false;
      }


      double gap =
         newer.low -
         older.high;


      double minimumGap =
         ASTRA_FVG_MIN_GAP_POINTS *
         context.point;


      if(gap < minimumGap)
         return false;


      m_bullishFVG =
         true;


      context.fairValueGap =
         true;

      context.bullishFVG =
         true;

      context.bearishFVG =
         false;

      context.fvgPresent =
         true;


      return true;
   }


   //=================================================================
   // BEARISH FVG
   //=================================================================
   bool DetectBearishFVG(
      const MqlRates &older,
      const MqlRates &middle,
      const MqlRates &newer,
      AnalysisContext &context
   )
   {
      if(
         middle.close >=
         middle.open
      )
      {
         return false;
      }


      double gap =
         older.low -
         newer.high;


      double minimumGap =
         ASTRA_FVG_MIN_GAP_POINTS *
         context.point;


      if(gap < minimumGap)
         return false;


      m_bearishFVG =
         true;


      context.fairValueGap =
         true;

      context.bullishFVG =
         false;

      context.bearishFVG =
         true;

      context.fvgPresent =
         true;


      return true;
   }


   //=================================================================
   // MITIGAÇÃO
   //=================================================================
   void DetectMitigation(
      AnalysisContext &context
   )
   {
      m_mitigation =
         false;


      double currentLow =
         context.marketBars[0].low;

      double currentHigh =
         context.marketBars[0].high;


      if(m_bullishOB)
      {
         if(
            currentLow <=
            m_lastBullishOBHigh &&
            currentLow >=
            m_lastBullishOBLow
         )
         {
            m_mitigation =
               true;
         }
      }


      if(m_bearishOB)
      {
         if(
            currentHigh >=
            m_lastBearishOBLow &&
            currentHigh <=
            m_lastBearishOBHigh
         )
         {
            m_mitigation =
               true;
         }
      }


      context.mitigation =
         m_mitigation;
   }


public:

   //=================================================================
   // CONSTRUCTOR
   //=================================================================
   OrderBlockEngine()
   {
      ResetInternal();

      m_status =
         "INITIALIZED";

      m_operational =
         true;
   }


   //=================================================================
   // DESTRUCTOR
   //=================================================================
   ~OrderBlockEngine()
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
   // OPERATIONAL
   //=================================================================
   bool IsSystemOperational() const
   {
      return m_operational;
   }


   //=================================================================
   // STATUS
   //=================================================================
   string GetStatus() const
   {
      return m_status;
   }


   //=================================================================
   // ANALYZE
   //=================================================================
   bool Analyze(
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

      m_operational =
         true;


      //==============================================================
      // CONTEXTO
      //==============================================================

      if(!context.Validate())
      {
         m_status =
            "INVALID_CONTEXT";

         return false;
      }


      if(context.point <= 0.0)
      {
         m_status =
            "INVALID_POINT";

         return false;
      }


      //==============================================================
      // HISTÓRICO CENTRAL
      //==============================================================

      if(
         !context.marketHistoryReady ||
         context.marketBarsCount < 4 ||
         ArraySize(context.marketBars) < 4
      )
      {
         m_status =
            "INSUFFICIENT_DATA";

         return false;
      }


      //==============================================================
      // RESET DOS CAMPOS DO CONTEXTO
      //==============================================================

      context.orderBlock =
         false;

      context.orderBlockValid =
         false;

      context.orderBlockStrength =
         0.0;

      context.fairValueGap =
         false;

      context.fvgPresent =
         false;

      context.bullishFVG =
         false;

      context.bearishFVG =
         false;

      context.mitigation =
         false;


      //==============================================================
      // CANDLES
      //
      // [0] atual
      // [1] fechado recente
      // [2] fechado anterior
      // [3] fechado anterior
      //==============================================================

      MqlRates current =
         context.marketBars[1];

      MqlRates middle =
         context.marketBars[2];

      MqlRates older =
         context.marketBars[3];


      //==============================================================
      // VALIDAÇÃO TEMPORAL
      //==============================================================

      if(
         current.time <= 0 ||
         middle.time <= 0 ||
         older.time <= 0
      )
      {
         m_status =
            "INVALID_CANDLE_TIME";

         return false;
      }


      if(
         current.time <= middle.time ||
         middle.time <= older.time
      )
      {
         m_status =
            "INVALID_TIME_SEQUENCE";

         return false;
      }


      //==============================================================
      // ORDER BLOCK
      //==============================================================

      bool bullishOB =
         DetectBullishOrderBlock(
            middle,
            current,
            context
         );


      bool bearishOB =
         DetectBearishOrderBlock(
            middle,
            current,
            context
         );


      //==============================================================
      // FVG
      //==============================================================

      bool bullishFVG =
         DetectBullishFVG(
            older,
            middle,
            current,
            context
         );


      bool bearishFVG =
         DetectBearishFVG(
            older,
            middle,
            current,
            context
         );


      //==============================================================
      // MITIGAÇÃO
      //==============================================================

      DetectMitigation(
         context
      );


      //==============================================================
      // SCORE SMART MONEY ASSINADO
      //==============================================================

      double bullishScore = 0.0;
      double bearishScore = 0.0;


      if(bullishOB)
      {
         bullishScore +=
            m_bullishStrength *
            0.50;
      }


      if(bearishOB)
      {
         bearishScore +=
            m_bearishStrength *
            0.50;
      }


      if(bullishFVG)
         bullishScore += 20.0;


      if(bearishFVG)
         bearishScore += 20.0;


      if(m_mitigation)
      {
         if(bullishOB)
            bullishScore += 10.0;

         if(bearishOB)
            bearishScore += 10.0;
      }


      bullishScore =
         ClampScore(
            bullishScore
         );

      bearishScore =
         ClampScore(
            bearishScore
         );


      double signedScore =
         bullishScore -
         bearishScore;


      context.smartMoneyScore =
         ClampSigned(
            signedScore
         );


      //==============================================================
      // SCORE DE ESTRUTURA SMART MONEY
      //==============================================================

      if(
         context.smartMoneyScore > 0.0 &&
         context.structuralBias == BIAS_BULLISH
      )
      {
         context.smartMoneyState =
            LAYER_VALID;
      }
      else
      if(
         context.smartMoneyScore < 0.0 &&
         context.structuralBias == BIAS_BEARISH
      )
      {
         context.smartMoneyState =
            LAYER_VALID;
      }
      else
      if(
         bullishOB ||
         bearishOB ||
         bullishFVG ||
         bearishFVG
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


      //==============================================================
      // STATUS
      //==============================================================

      m_status =
         "ANALYSIS_COMPLETE";


      PrintFormat(
         "[OrderBlockEngine] %s %s | "
         "BullOB=%s | BearOB=%s | "
         "BullFVG=%s | BearFVG=%s | "
         "Mitigation=%s | "
         "BullScore=%.2f | BearScore=%.2f | "
         "SmartMoneyScore=%.2f",
         context.symbol,
         EnumToString(context.primaryTF),
         bullishOB ? "true" : "false",
         bearishOB ? "true" : "false",
         bullishFVG ? "true" : "false",
         bearishFVG ? "true" : "false",
         m_mitigation ? "true" : "false",
         bullishScore,
         bearishScore,
         context.smartMoneyScore
      );


      return true;
   }


   //=================================================================
   // GETTERS
   //=================================================================
   bool HasBullishOrderBlock() const
   {
      return m_bullishOB;
   }


   bool HasBearishOrderBlock() const
   {
      return m_bearishOB;
   }


   bool HasBullishFVG() const
   {
      return m_bullishFVG;
   }


   bool HasBearishFVG() const
   {
      return m_bearishFVG;
   }


   bool IsMitigated() const
   {
      return m_mitigation;
   }


   double GetBullishStrength() const
   {
      return m_bullishStrength;
   }


   double GetBearishStrength() const
   {
      return m_bearishStrength;
   }


   double GetBullishOBHigh() const
   {
      return m_lastBullishOBHigh;
   }


   double GetBullishOBLow() const
   {
      return m_lastBullishOBLow;
   }


   double GetBearishOBHigh() const
   {
      return m_lastBearishOBHigh;
   }


   double GetBearishOBLow() const
   {
      return m_lastBearishOBLow;
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_ORDERBLOCKENGINE_MQH
