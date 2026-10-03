//+------------------------------------------------------------------+
//| PatternRecognitionEngine.mqh                                     |
//| Astra Trader AI                                                  |
//|                                                                  |
//| CAMADA: MARKET PATTERN RECOGNITION                               |
//|                                                                  |
//| CONTRATO TEMPORAL:                                               |
//|   marketBars[0] = candle atual                                   |
//|   marketBars[1] = último candle fechado                          |
//|   marketBars[2] = segundo candle fechado                         |
//|   marketBars[3] = terceiro candle fechado                        |
//|   marketBars[4] = quarto candle fechado                           |
//|                                                                  |
//| REGRA:                                                           |
//|   Toda detecção estratégica utiliza somente candles fechados.      |
//|   marketBars[0] não participa da detecção dos padrões.             |
//|                                                                  |
//| FONTE DE VERDADE:                                                |
//|   AnalysisContext                                                 |
//|                                                                  |
//| NÃO EXECUTA:                                                     |
//|   - CopyRates()                                                   |
//|   - decisão BUY/SELL                                              |
//|   - cálculo de risco                                              |
//|   - execução de ordens                                            |
//+------------------------------------------------------------------+
#ifndef ASTRA_PATTERNRECOGNITIONENGINE_MQH
#define ASTRA_PATTERNRECOGNITIONENGINE_MQH

#property strict

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>


//+------------------------------------------------------------------+
//| PatternRecognitionEngine                                         |
//+------------------------------------------------------------------+
class PatternRecognitionEngine
{
private:

   //=================================================================
   // ESTADO INTERNO DO ENGINE
   //=================================================================

   bool   m_bullishPattern;
   bool   m_bearishPattern;

   bool   m_doji;
   bool   m_hammer;
   bool   m_invertedHammer;
   bool   m_shootingStar;
   bool   m_hangingMan;

   bool   m_bullishEngulfing;
   bool   m_bearishEngulfing;

   bool   m_bullishPinBar;
   bool   m_bearishPinBar;

   bool   m_insideBar;
   bool   m_bullishInsideBreak;
   bool   m_bearishInsideBreak;

   bool   m_threeWhiteSoldiers;
   bool   m_threeBlackCrows;

   bool   m_morningStar;
   bool   m_eveningStar;

   double m_bullishScore;
   double m_bearishScore;
   double m_patternScore;

   string m_primaryPattern;


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
   // BODY
   //=================================================================

   double Body(
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

   double Range(
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
   // UPPER WICK
   //=================================================================

   double UpperWick(
      const double openPrice,
      const double highPrice,
      const double closePrice
   ) const
   {
      const double wick =
         highPrice -
         MathMax(
            openPrice,
            closePrice
         );

      return MathMax(
         0.0,
         wick
      );
   }


   //=================================================================
   // LOWER WICK
   //=================================================================

   double LowerWick(
      const double openPrice,
      const double lowPrice,
      const double closePrice
   ) const
   {
      const double wick =
         MathMin(
            openPrice,
            closePrice
         ) -
         lowPrice;

      return MathMax(
         0.0,
         wick
      );
   }


   //=================================================================
   // DIREÇÃO
   //=================================================================

   bool IsBullish(
      const double openPrice,
      const double closePrice
   ) const
   {
      return (
         closePrice >
         openPrice
      );
   }


   bool IsBearish(
      const double openPrice,
      const double closePrice
   ) const
   {
      return (
         closePrice <
         openPrice
      );
   }


   //=================================================================
   // DOJI
   //=================================================================

   bool DetectDoji(
      const double openPrice,
      const double highPrice,
      const double lowPrice,
      const double closePrice
   ) const
   {
      const double range =
         Range(
            highPrice,
            lowPrice
         );

      if(range <= 0.0)
         return false;

      const double body =
         Body(
            openPrice,
            closePrice
         );

      return (
         body / range <= 0.10
      );
   }


   //=================================================================
   // HAMMER
   //=================================================================

   bool DetectHammerShape(
      const double openPrice,
      const double highPrice,
      const double lowPrice,
      const double closePrice
   ) const
   {
      const double range =
         Range(
            highPrice,
            lowPrice
         );

      if(range <= 0.0)
         return false;

      double body =
         Body(
            openPrice,
            closePrice
         );

      const double upper =
         UpperWick(
            openPrice,
            highPrice,
            closePrice
         );

      const double lower =
         LowerWick(
            openPrice,
            lowPrice,
            closePrice
         );

      if(body <= 0.0)
      {
         body =
            range * 0.05;
      }

      return (
         lower >= body * 2.0 &&
         upper <= body * 0.75 &&
         body / range <= 0.45
      );
   }


   //=================================================================
   // INVERTED HAMMER / SHOOTING STAR
   //=================================================================

   bool DetectInvertedHammerShape(
      const double openPrice,
      const double highPrice,
      const double lowPrice,
      const double closePrice
   ) const
   {
      const double range =
         Range(
            highPrice,
            lowPrice
         );

      if(range <= 0.0)
         return false;

      double body =
         Body(
            openPrice,
            closePrice
         );

      const double upper =
         UpperWick(
            openPrice,
            highPrice,
            closePrice
         );

      const double lower =
         LowerWick(
            openPrice,
            lowPrice,
            closePrice
         );

      if(body <= 0.0)
      {
         body =
            range * 0.05;
      }

      return (
         upper >= body * 2.0 &&
         lower <= body * 0.75 &&
         body / range <= 0.45
      );
   }


   //=================================================================
   // CONTEXTO BULLISH
   //=================================================================

   bool HasBullishContext(
      const MqlRates &bar1,
      const MqlRates &bar2,
      const MqlRates &bar3
   ) const
   {
      const double move1 =
         bar1.close -
         bar2.close;

      const double move2 =
         bar2.close -
         bar3.close;

      const double netMove =
         bar1.close -
         bar3.close;

      if(
         move1 > 0.0 &&
         move2 > 0.0
      )
      {
         return true;
      }

      if(
         netMove > 0.0 &&
         (
            move1 > 0.0 ||
            move2 > 0.0
         )
      )
      {
         return true;
      }

      return false;
   }


   //=================================================================
   // CONTEXTO BEARISH
   //=================================================================

   bool HasBearishContext(
      const MqlRates &bar1,
      const MqlRates &bar2,
      const MqlRates &bar3
   ) const
   {
      const double move1 =
         bar1.close -
         bar2.close;

      const double move2 =
         bar2.close -
         bar3.close;

      const double netMove =
         bar1.close -
         bar3.close;

      if(
         move1 < 0.0 &&
         move2 < 0.0
      )
      {
         return true;
      }

      if(
         netMove < 0.0 &&
         (
            move1 < 0.0 ||
            move2 < 0.0
         )
      )
      {
         return true;
      }

      return false;
   }


   //=================================================================
   // BULLISH ENGULFING
   //=================================================================

   bool DetectBullishEngulfing(
      const double open0,
      const double close0,
      const double open1,
      const double close1,
      const bool hasBearishContext
   ) const
   {
      if(!IsBullish(open0,close0))
         return false;

      if(!IsBearish(open1,close1))
         return false;

      if(!hasBearishContext)
         return false;

      const double body0 =
         Body(
            open0,
            close0
         );

      const double body1 =
         Body(
            open1,
            close1
         );

      if(
         body0 <= 0.0 ||
         body1 <= 0.0
      )
      {
         return false;
      }

      return (
         open0 <= close1 &&
         close0 >= open1 &&
         body0 >= body1 * 1.05
      );
   }


   //=================================================================
   // BEARISH ENGULFING
   //=================================================================

   bool DetectBearishEngulfing(
      const double open0,
      const double close0,
      const double open1,
      const double close1,
      const bool hasBullishContext
   ) const
   {
      if(!IsBearish(open0,close0))
         return false;

      if(!IsBullish(open1,close1))
         return false;

      if(!hasBullishContext)
         return false;

      const double body0 =
         Body(
            open0,
            close0
         );

      const double body1 =
         Body(
            open1,
            close1
         );

      if(
         body0 <= 0.0 ||
         body1 <= 0.0
      )
      {
         return false;
      }

      return (
         open0 >= close1 &&
         close0 <= open1 &&
         body0 >= body1 * 1.05
      );
   }


   //=================================================================
   // BULLISH PIN BAR
   //=================================================================

   bool DetectBullishPinBar(
      const double openPrice,
      const double highPrice,
      const double lowPrice,
      const double closePrice
   ) const
   {
      const double range =
         Range(
            highPrice,
            lowPrice
         );

      if(range <= 0.0)
         return false;

      const double body =
         Body(
            openPrice,
            closePrice
         );

      const double lower =
         LowerWick(
            openPrice,
            lowPrice,
            closePrice
         );

      const double upper =
         UpperWick(
            openPrice,
            highPrice,
            closePrice
         );

      const double midpoint =
         lowPrice +
         range * 0.50;

      if(closePrice < midpoint)
         return false;

      return (
         lower >= range * 0.50 &&
         upper <= range * 0.20 &&
         body <= range * 0.35
      );
   }


   //=================================================================
   // BEARISH PIN BAR
   //=================================================================

   bool DetectBearishPinBar(
      const double openPrice,
      const double highPrice,
      const double lowPrice,
      const double closePrice
   ) const
   {
      const double range =
         Range(
            highPrice,
            lowPrice
         );

      if(range <= 0.0)
         return false;

      const double body =
         Body(
            openPrice,
            closePrice
         );

      const double lower =
         LowerWick(
            openPrice,
            lowPrice,
            closePrice
         );

      const double upper =
         UpperWick(
            openPrice,
            highPrice,
            closePrice
         );

      const double midpoint =
         lowPrice +
         range * 0.50;

      if(closePrice > midpoint)
         return false;

      return (
         upper >= range * 0.50 &&
         lower <= range * 0.20 &&
         body <= range * 0.35
      );
   }


   //=================================================================
   // INSIDE BAR
   //=================================================================

   bool DetectInsideBar(
      const double insideHigh,
      const double insideLow,
      const double motherHigh,
      const double motherLow
   ) const
   {
      return (
         insideHigh < motherHigh &&
         insideLow > motherLow
      );
   }


   //=================================================================
   // BULLISH INSIDE BREAK
   //=================================================================

   bool DetectBullishInsideBreak(
      const MqlRates &breakBar,
      const MqlRates &insideBar,
      const MqlRates &motherBar
   ) const
   {
      if(!DetectInsideBar(
         insideBar.high,
         insideBar.low,
         motherBar.high,
         motherBar.low
      ))
      {
         return false;
      }

      if(
         breakBar.time <= 0 ||
         !IsBullish(
            breakBar.open,
            breakBar.close
         )
      )
      {
         return false;
      }

      const double motherRange =
         Range(
            motherBar.high,
            motherBar.low
         );

      const double margin =
         (
            motherRange > 0.0
            ? motherRange * 0.02
            : 0.0
         );

      return (
         breakBar.close >
         motherBar.high + margin
      );
   }


   //=================================================================
   // BEARISH INSIDE BREAK
   //=================================================================

   bool DetectBearishInsideBreak(
      const MqlRates &breakBar,
      const MqlRates &insideBar,
      const MqlRates &motherBar
   ) const
   {
      if(!DetectInsideBar(
         insideBar.high,
         insideBar.low,
         motherBar.high,
         motherBar.low
      ))
      {
         return false;
      }

      if(
         breakBar.time <= 0 ||
         !IsBearish(
            breakBar.open,
            breakBar.close
         )
      )
      {
         return false;
      }

      const double motherRange =
         Range(
            motherBar.high,
            motherBar.low
         );

      const double margin =
         (
            motherRange > 0.0
            ? motherRange * 0.02
            : 0.0
         );

      return (
         breakBar.close <
         motherBar.low - margin
      );
   }


   //=================================================================
   // THREE WHITE SOLDIERS
   //=================================================================

   bool DetectThreeWhiteSoldiers(
      const MqlRates &bar0,
      const MqlRates &bar1,
      const MqlRates &bar2
   ) const
   {
      if(
         !IsBullish(bar0.open,bar0.close) ||
         !IsBullish(bar1.open,bar1.close) ||
         !IsBullish(bar2.open,bar2.close)
      )
      {
         return false;
      }

      const double b0 =
         Body(
            bar0.open,
            bar0.close
         );

      const double b1 =
         Body(
            bar1.open,
            bar1.close
         );

      const double b2 =
         Body(
            bar2.open,
            bar2.close
         );

      if(
         b0 <= 0.0 ||
         b1 <= 0.0 ||
         b2 <= 0.0
      )
      {
         return false;
      }

      // bar0 = mais recente
      // bar1 = anterior
      // bar2 = anterior ao bar1
      if(
         bar1.close >= bar0.close ||
         bar2.close >= bar1.close
      )
      {
         return false;
      }

      if(
         bar1.open < bar0.open ||
         bar1.open > bar0.close
      )
      {
         return false;
      }

      if(
         bar2.open < bar1.open ||
         bar2.open > bar1.close
      )
      {
         return false;
      }

      return (
         b1 >= b0 * 0.60 &&
         b2 >= b1 * 0.60
      );
   }


   //=================================================================
   // THREE BLACK CROWS
   //=================================================================

   bool DetectThreeBlackCrows(
      const MqlRates &bar0,
      const MqlRates &bar1,
      const MqlRates &bar2
   ) const
   {
      if(
         !IsBearish(bar0.open,bar0.close) ||
         !IsBearish(bar1.open,bar1.close) ||
         !IsBearish(bar2.open,bar2.close)
      )
      {
         return false;
      }

      const double b0 =
         Body(
            bar0.open,
            bar0.close
         );

      const double b1 =
         Body(
            bar1.open,
            bar1.close
         );

      const double b2 =
         Body(
            bar2.open,
            bar2.close
         );

      if(
         b0 <= 0.0 ||
         b1 <= 0.0 ||
         b2 <= 0.0
      )
      {
         return false;
      }

      // bar0 = mais recente
      // bar1 = anterior
      // bar2 = anterior ao bar1
      if(
         bar1.close <= bar0.close ||
         bar2.close <= bar1.close
      )
      {
         return false;
      }

      if(
         bar1.open > bar0.open ||
         bar1.open < bar0.close
      )
      {
         return false;
      }

      if(
         bar2.open > bar1.open ||
         bar2.open < bar1.close
      )
      {
         return false;
      }

      return (
         b1 >= b0 * 0.60 &&
         b2 >= b1 * 0.60
      );
   }


   //=================================================================
   // MORNING STAR
   //=================================================================

   bool DetectMorningStar(
      const MqlRates &olderBar,
      const MqlRates &middleBar,
      const MqlRates &newerBar
   ) const
   {
      if(!IsBearish(
         olderBar.open,
         olderBar.close
      ))
      {
         return false;
      }

      if(!IsBullish(
         newerBar.open,
         newerBar.close
      ))
      {
         return false;
      }

      const double bodyOlder =
         Body(
            olderBar.open,
            olderBar.close
         );

      const double bodyMiddle =
         Body(
            middleBar.open,
            middleBar.close
         );

      const double bodyNewer =
         Body(
            newerBar.open,
            newerBar.close
         );

      if(
         bodyOlder <= 0.0 ||
         bodyMiddle <= 0.0 ||
         bodyNewer <= 0.0
      )
      {
         return false;
      }

      if(
         bodyMiddle >
         bodyOlder * 0.50
      )
      {
         return false;
      }

      const double midpoint =
         olderBar.close +
         bodyOlder * 0.50;

      return (
         newerBar.close >
         midpoint
      );
   }


   //=================================================================
   // EVENING STAR
   //=================================================================

   bool DetectEveningStar(
      const MqlRates &olderBar,
      const MqlRates &middleBar,
      const MqlRates &newerBar
   ) const
   {
      if(!IsBullish(
         olderBar.open,
         olderBar.close
      ))
      {
         return false;
      }

      if(!IsBearish(
         newerBar.open,
         newerBar.close
      ))
      {
         return false;
      }

      const double bodyOlder =
         Body(
            olderBar.open,
            olderBar.close
         );

      const double bodyMiddle =
         Body(
            middleBar.open,
            middleBar.close
         );

      const double bodyNewer =
         Body(
            newerBar.open,
            newerBar.close
         );

      if(
         bodyOlder <= 0.0 ||
         bodyMiddle <= 0.0 ||
         bodyNewer <= 0.0
      )
      {
         return false;
      }

      if(
         bodyMiddle >
         bodyOlder * 0.50
      )
      {
         return false;
      }

      const double midpoint =
         olderBar.close -
         bodyOlder * 0.50;

      return (
         newerBar.close <
         midpoint
      );
   }


   //=================================================================
   // RESET INTERNO
   //=================================================================

   void Reset()
   {
      m_bullishPattern = false;
      m_bearishPattern = false;

      m_doji = false;
      m_hammer = false;
      m_invertedHammer = false;
      m_shootingStar = false;
      m_hangingMan = false;

      m_bullishEngulfing = false;
      m_bearishEngulfing = false;

      m_bullishPinBar = false;
      m_bearishPinBar = false;

      m_insideBar = false;
      m_bullishInsideBreak = false;
      m_bearishInsideBreak = false;

      m_threeWhiteSoldiers = false;
      m_threeBlackCrows = false;

      m_morningStar = false;
      m_eveningStar = false;

      m_bullishScore = 0.0;
      m_bearishScore = 0.0;
      m_patternScore = 0.0;

      m_primaryPattern = "";
   }


   //=================================================================
   // RESET DA CAMADA NO CONTEXTO
   //=================================================================

   void ResetContextLayer(
      AnalysisContext &ctx
   ) const
   {
      ctx.patternScore =
         0.0;

      ctx.bullishPatternScore =
         0.0;

      ctx.bearishPatternScore =
         0.0;

      ctx.bullishPatternDetected =
         false;

      ctx.bearishPatternDetected =
         false;

      ctx.primaryPattern =
         "";

      ctx.dojiDetected =
         false;

      ctx.hammerDetected =
         false;

      ctx.invertedHammerDetected =
         false;

      ctx.shootingStarDetected =
         false;

      ctx.hangingManDetected =
         false;

      ctx.bullishEngulfingDetected =
         false;

      ctx.bearishEngulfingDetected =
         false;

      ctx.bullishPinBarDetected =
         false;

      ctx.bearishPinBarDetected =
         false;

      ctx.insideBarDetected =
         false;

      ctx.bullishInsideBreakDetected =
         false;

      ctx.bearishInsideBreakDetected =
         false;

      ctx.threeWhiteSoldiersDetected =
         false;

      ctx.threeBlackCrowsDetected =
         false;

      ctx.morningStarDetected =
         false;

      ctx.eveningStarDetected =
         false;

      ctx.patternState =
         LAYER_NEUTRAL;
   }


   //=================================================================
   // PRIMARY PATTERN
   //=================================================================

   void DeterminePrimaryPattern()
   {
      double maxBullishScore =
         0.0;

      double maxBearishScore =
         0.0;

      string maxBullishPattern =
         "NONE";

      string maxBearishPattern =
         "NONE";


      //==============================================================
      // BULLISH
      //==============================================================

      if(
         m_bullishEngulfing &&
         30.0 > maxBullishScore
      )
      {
         maxBullishScore =
            30.0;

         maxBullishPattern =
            "BULLISH_ENGULFING";
      }

      if(
         m_threeWhiteSoldiers &&
         35.0 > maxBullishScore
      )
      {
         maxBullishScore =
            35.0;

         maxBullishPattern =
            "THREE_WHITE_SOLDIERS";
      }

      if(
         m_morningStar &&
         35.0 > maxBullishScore
      )
      {
         maxBullishScore =
            35.0;

         maxBullishPattern =
            "MORNING_STAR";
      }

      if(
         m_bullishInsideBreak &&
         15.0 > maxBullishScore
      )
      {
         maxBullishScore =
            15.0;

         maxBullishPattern =
            "BULLISH_INSIDE_BREAK";
      }

      if(
         m_bullishPinBar &&
         25.0 > maxBullishScore
      )
      {
         maxBullishScore =
            25.0;

         maxBullishPattern =
            "BULLISH_PIN_BAR";
      }

      if(
         m_hammer &&
         20.0 > maxBullishScore
      )
      {
         maxBullishScore =
            20.0;

         maxBullishPattern =
            "HAMMER";
      }

      if(
         m_invertedHammer &&
         12.0 > maxBullishScore
      )
      {
         maxBullishScore =
            12.0;

         maxBullishPattern =
            "INVERTED_HAMMER";
      }


      //==============================================================
      // BEARISH
      //==============================================================

      if(
         m_bearishEngulfing &&
         30.0 > maxBearishScore
      )
      {
         maxBearishScore =
            30.0;

         maxBearishPattern =
            "BEARISH_ENGULFING";
      }

      if(
         m_threeBlackCrows &&
         35.0 > maxBearishScore
      )
      {
         maxBearishScore =
            35.0;

         maxBearishPattern =
            "THREE_BLACK_CROWS";
      }

      if(
         m_eveningStar &&
         35.0 > maxBearishScore
      )
      {
         maxBearishScore =
            35.0;

         maxBearishPattern =
            "EVENING_STAR";
      }

      if(
         m_bearishInsideBreak &&
         15.0 > maxBearishScore
      )
      {
         maxBearishScore =
            15.0;

         maxBearishPattern =
            "BEARISH_INSIDE_BREAK";
      }

      if(
         m_bearishPinBar &&
         25.0 > maxBearishScore
      )
      {
         maxBearishScore =
            25.0;

         maxBearishPattern =
            "BEARISH_PIN_BAR";
      }

      if(
         m_shootingStar &&
         25.0 > maxBearishScore
      )
      {
         maxBearishScore =
            25.0;

         maxBearishPattern =
            "SHOOTING_STAR";
      }

      if(
         m_hangingMan &&
         20.0 > maxBearishScore
      )
      {
         maxBearishScore =
            20.0;

         maxBearishPattern =
            "HANGING_MAN";
      }


      //==============================================================
      // DEFINIÇÃO FINAL
      //==============================================================

      if(
         maxBullishScore >
         maxBearishScore
      )
      {
         m_primaryPattern =
            maxBullishPattern;

         return;
      }


      if(
         maxBearishScore >
         maxBullishScore
      )
      {
         m_primaryPattern =
            maxBearishPattern;

         return;
      }


      //==============================================================
      // EMPATE
      //==============================================================

      if(m_bullishEngulfing)
      {
         m_primaryPattern =
            "BULLISH_ENGULFING";
      }
      else
      if(m_bearishEngulfing)
      {
         m_primaryPattern =
            "BEARISH_ENGULFING";
      }
      else
      if(m_threeWhiteSoldiers)
      {
         m_primaryPattern =
            "THREE_WHITE_SOLDIERS";
      }
      else
      if(m_threeBlackCrows)
      {
         m_primaryPattern =
            "THREE_BLACK_CROWS";
      }
      else
      if(m_morningStar)
      {
         m_primaryPattern =
            "MORNING_STAR";
      }
      else
      if(m_eveningStar)
      {
         m_primaryPattern =
            "EVENING_STAR";
      }
      else
      if(m_bullishInsideBreak)
      {
         m_primaryPattern =
            "BULLISH_INSIDE_BREAK";
      }
      else
      if(m_bearishInsideBreak)
      {
         m_primaryPattern =
            "BEARISH_INSIDE_BREAK";
      }
      else
      if(m_bullishPinBar)
      {
         m_primaryPattern =
            "BULLISH_PIN_BAR";
      }
      else
      if(m_bearishPinBar)
      {
         m_primaryPattern =
            "BEARISH_PIN_BAR";
      }
      else
      if(m_hammer)
      {
         m_primaryPattern =
            "HAMMER";
      }
      else
      if(m_invertedHammer)
      {
         m_primaryPattern =
            "INVERTED_HAMMER";
      }
      else
      if(m_shootingStar)
      {
         m_primaryPattern =
            "SHOOTING_STAR";
      }
      else
      if(m_hangingMan)
      {
         m_primaryPattern =
            "HANGING_MAN";
      }
      else
      if(m_doji)
      {
         m_primaryPattern =
            "DOJI";
      }
      else
      if(m_insideBar)
      {
         m_primaryPattern =
            "INSIDE_BAR";
      }
      else
      {
         m_primaryPattern =
            "NONE";
      }
   }


   //=================================================================
   // SCORE
   //=================================================================

   void CalculateScores()
   {
      double bullScore =
         0.0;

      double bearScore =
         0.0;


      //==============================================================
      // HAMMER / BULLISH PIN BAR
      //==============================================================

      double hammerPinBarBull =
         0.0;

      if(m_hammer)
      {
         hammerPinBarBull =
            MathMax(
               hammerPinBarBull,
               20.0
            );
      }

      if(m_bullishPinBar)
      {
         hammerPinBarBull =
            MathMax(
               hammerPinBarBull,
               25.0
            );
      }

      bullScore +=
         hammerPinBarBull;


      //==============================================================
      // SHOOTING STAR / BEARISH PIN BAR
      //==============================================================

      double starPinBarBear =
         0.0;

      if(m_shootingStar)
      {
         starPinBarBear =
            MathMax(
               starPinBarBear,
               25.0
            );
      }

      if(m_bearishPinBar)
      {
         starPinBarBear =
            MathMax(
               starPinBarBear,
               25.0
            );
      }

      bearScore +=
         starPinBarBear;


      //==============================================================
      // BULLISH
      //==============================================================

      if(m_invertedHammer)
         bullScore += 12.0;

      if(m_bullishEngulfing)
         bullScore += 30.0;

      if(m_threeWhiteSoldiers)
         bullScore += 35.0;

      if(m_morningStar)
         bullScore += 35.0;

      if(m_bullishInsideBreak)
         bullScore += 15.0;


      //==============================================================
      // BEARISH
      //==============================================================

      if(m_hangingMan)
         bearScore += 20.0;

      if(m_bearishEngulfing)
         bearScore += 30.0;

      if(m_threeBlackCrows)
         bearScore += 35.0;

      if(m_eveningStar)
         bearScore += 35.0;

      if(m_bearishInsideBreak)
         bearScore += 15.0;


      //==============================================================
      // DOJI
      //==============================================================

      if(m_doji)
      {
         bullScore *= 0.85;
         bearScore *= 0.85;
      }


      //==============================================================
      // CLAMP
      //==============================================================

      m_bullishScore =
         Clamp(
            bullScore,
            0.0,
            100.0
         );

      m_bearishScore =
         Clamp(
            bearScore,
            0.0,
            100.0
         );

      m_patternScore =
         Clamp(
            m_bullishScore -
            m_bearishScore,
            -100.0,
            100.0
         );


      //==============================================================
      // DIREÇÕES
      //==============================================================

      m_bullishPattern =
         (
            m_bullishScore >
            m_bearishScore &&
            m_bullishScore >= 15.0
         );

      m_bearishPattern =
         (
            m_bearishScore >
            m_bullishScore &&
            m_bearishScore >= 15.0
         );
   }


   //=================================================================
   // WRITE CONTEXT
   //=================================================================

   void WriteToContext(
      AnalysisContext &ctx
   ) const
   {
      ctx.patternScore =
         m_patternScore;

      ctx.bullishPatternScore =
         m_bullishScore;

      ctx.bearishPatternScore =
         m_bearishScore;

      ctx.bullishPatternDetected =
         m_bullishPattern;

      ctx.bearishPatternDetected =
         m_bearishPattern;

      ctx.primaryPattern =
         m_primaryPattern;

      ctx.dojiDetected =
         m_doji;

      ctx.hammerDetected =
         m_hammer;

      ctx.invertedHammerDetected =
         m_invertedHammer;

      ctx.shootingStarDetected =
         m_shootingStar;

      ctx.hangingManDetected =
         m_hangingMan;

      ctx.bullishEngulfingDetected =
         m_bullishEngulfing;

      ctx.bearishEngulfingDetected =
         m_bearishEngulfing;

      ctx.bullishPinBarDetected =
         m_bullishPinBar;

      ctx.bearishPinBarDetected =
         m_bearishPinBar;

      ctx.insideBarDetected =
         m_insideBar;

      ctx.bullishInsideBreakDetected =
         m_bullishInsideBreak;

      ctx.bearishInsideBreakDetected =
         m_bearishInsideBreak;

      ctx.threeWhiteSoldiersDetected =
         m_threeWhiteSoldiers;

      ctx.threeBlackCrowsDetected =
         m_threeBlackCrows;

      ctx.morningStarDetected =
         m_morningStar;

      ctx.eveningStarDetected =
         m_eveningStar;


      if(
         m_bullishPattern ||
         m_bearishPattern ||
         m_doji ||
         m_insideBar
      )
      {
         ctx.patternState =
            LAYER_VALID;
      }
      else
      {
         ctx.patternState =
            LAYER_NEUTRAL;
      }
   }


public:

   //=================================================================
   // CONSTRUCTOR
   //=================================================================

   PatternRecognitionEngine()
   {
      Reset();
   }


   //=================================================================
   // ANALYZE
   //=================================================================

   bool Analyze(
      AnalysisContext &ctx
   )
   {
      //==============================================================
      // RESET
      //==============================================================

      Reset();

      ResetContextLayer(
         ctx
      );


      //==============================================================
      // SYMBOL
      //==============================================================

      if(ctx.symbol == "")
      {
         ctx.patternState =
            LAYER_INVALID;

         ctx.validationMessage =
            "PatternRecognitionEngine: symbol invalido.";

         return false;
      }


      //==============================================================
      // HISTORICO CENTRAL
      //==============================================================

      if(!ctx.marketDataReady)
      {
         ctx.patternState =
            LAYER_INVALID;

         ctx.validationMessage =
            "PatternRecognitionEngine: market data nao esta pronto.";

         return false;
      }


      if(!ctx.marketHistoryReady)
      {
         ctx.patternState =
            LAYER_INVALID;

         ctx.validationMessage =
            "PatternRecognitionEngine: historico nao esta pronto.";

         return false;
      }


      if(
         ctx.marketBarsCount < 5 ||
         ctx.marketDataBarCount < 5 ||
         ArraySize(ctx.marketBars) < 5
      )
      {
         ctx.patternState =
            LAYER_INVALID;

         ctx.validationMessage =
            "PatternRecognitionEngine: "
            "historico insuficiente para reconhecimento de padroes.";

         return false;
      }


      //==============================================================
      // VALIDA BARRAS CENTRAIS
      //==============================================================

      MqlRates currentBar;
      MqlRates bar1;
      MqlRates bar2;
      MqlRates bar3;
      MqlRates bar4;

      ZeroMemory(
         currentBar
      );

      ZeroMemory(
         bar1
      );

      ZeroMemory(
         bar2
      );

      ZeroMemory(
         bar3
      );

      ZeroMemory(
         bar4
      );


      currentBar =
         ctx.marketBars[0];

      bar1 =
         ctx.marketBars[1];

      bar2 =
         ctx.marketBars[2];

      bar3 =
         ctx.marketBars[3];

      bar4 =
         ctx.marketBars[4];


      //==============================================================
      // TIMESTAMPS
      //==============================================================

      if(
         currentBar.time <= 0 ||
         bar1.time <= 0 ||
         bar2.time <= 0 ||
         bar3.time <= 0 ||
         bar4.time <= 0
      )
      {
         ctx.patternState =
            LAYER_INVALID;

         ctx.validationMessage =
            "PatternRecognitionEngine: timestamps invalidos.";

         return false;
      }


      //==============================================================
      // ORDENAÇÃO
      //
      // [0] atual
      // [1] fechado mais recente
      // [2] fechado anterior
      // [3] fechado anterior
      // [4] fechado anterior
      //==============================================================

      if(
         currentBar.time <= bar1.time ||
         bar1.time <= bar2.time ||
         bar2.time <= bar3.time ||
         bar3.time <= bar4.time
      )
      {
         ctx.patternState =
            LAYER_INVALID;

         ctx.validationMessage =
            "PatternRecognitionEngine: "
            "ordem temporal das barras invalida.";

         return false;
      }


      //==============================================================
      // RANGE
      //==============================================================

      const double range1 =
         Range(
            bar1.high,
            bar1.low
         );

      const double range2 =
         Range(
            bar2.high,
            bar2.low
         );

      const double range3 =
         Range(
            bar3.high,
            bar3.low
         );

      const double range4 =
         Range(
            bar4.high,
            bar4.low
         );

      if(
         range1 <= 0.0 ||
         range2 <= 0.0 ||
         range3 <= 0.0 ||
         range4 <= 0.0
      )
      {
         ctx.patternState =
            LAYER_INVALID;

         ctx.validationMessage =
            "PatternRecognitionEngine: "
            "range invalido em uma das barras.";

         return false;
      }


      //==============================================================
      // BAR 2
      //==============================================================

      const double body2 =
         Body(
            bar2.open,
            bar2.close
         );

      const bool bar2IsStrong =
         (
            range2 > 0.0 &&
            body2 / range2 > 0.30
         );

      const bool bar2IsBullish =
         IsBullish(
            bar2.open,
            bar2.close
         );

      const bool bar2IsBearish =
         IsBearish(
            bar2.open,
            bar2.close
         );


      //==============================================================
      // CONTEXTO
      //==============================================================

      const bool hasBullishContext =
         HasBullishContext(
            bar1,
            bar2,
            bar3
         );

      const bool hasBearishContext =
         HasBearishContext(
            bar1,
            bar2,
            bar3
         );


      //==============================================================
      // DOJI
      //==============================================================

      m_doji =
         DetectDoji(
            bar1.open,
            bar1.high,
            bar1.low,
            bar1.close
         );


      //==============================================================
      // HAMMER
      //==============================================================

      const bool hammerShape =
         DetectHammerShape(
            bar1.open,
            bar1.high,
            bar1.low,
            bar1.close
         );

      m_hammer =
         (
            hammerShape &&
            hasBearishContext &&
            bar2IsBearish &&
            bar2IsStrong
         );


      //==============================================================
      // HANGING MAN
      //==============================================================

      m_hangingMan =
         (
            hammerShape &&
            hasBullishContext &&
            bar2IsBullish &&
            bar2IsStrong
         );


      //==============================================================
      // INVERTED HAMMER
      //==============================================================

      const bool invertedHammerShape =
         DetectInvertedHammerShape(
            bar1.open,
            bar1.high,
            bar1.low,
            bar1.close
         );

      m_invertedHammer =
         (
            invertedHammerShape &&
            hasBearishContext &&
            bar2IsBearish &&
            bar2IsStrong
         );


      //==============================================================
      // SHOOTING STAR
      //==============================================================

      m_shootingStar =
         (
            invertedHammerShape &&
            hasBullishContext &&
            bar2IsBullish &&
            bar2IsStrong
         );


      //==============================================================
      // BULLISH ENGULFING
      //==============================================================

      m_bullishEngulfing =
         DetectBullishEngulfing(
            bar1.open,
            bar1.close,
            bar2.open,
            bar2.close,
            hasBearishContext
         );


      //==============================================================
      // BEARISH ENGULFING
      //==============================================================

      m_bearishEngulfing =
         DetectBearishEngulfing(
            bar1.open,
            bar1.close,
            bar2.open,
            bar2.close,
            hasBullishContext
         );


      //==============================================================
      // BULLISH PIN BAR
      //==============================================================

      m_bullishPinBar =
         DetectBullishPinBar(
            bar1.open,
            bar1.high,
            bar1.low,
            bar1.close
         );


      //==============================================================
      // BEARISH PIN BAR
      //==============================================================

      m_bearishPinBar =
         DetectBearishPinBar(
            bar1.open,
            bar1.high,
            bar1.low,
            bar1.close
         );


      //==============================================================
      // INSIDE BAR
      //==============================================================

      m_insideBar =
         DetectInsideBar(
            bar2.high,
            bar2.low,
            bar3.high,
            bar3.low
         );


      if(m_insideBar)
      {
         // bar1 = possível candle de rompimento
         // bar2 = inside bar
         // bar3 = mother bar

         m_bullishInsideBreak =
            DetectBullishInsideBreak(
               bar1,
               bar2,
               bar3
            );

         m_bearishInsideBreak =
            DetectBearishInsideBreak(
               bar1,
               bar2,
               bar3
            );
      }


      //==============================================================
      // THREE WHITE SOLDIERS
      //
      // bar1 = mais recente
      // bar2 = anterior
      // bar3 = anterior
      //==============================================================

      m_threeWhiteSoldiers =
         DetectThreeWhiteSoldiers(
            bar1,
            bar2,
            bar3
         );


      //==============================================================
      // THREE BLACK CROWS
      //==============================================================

      m_threeBlackCrows =
         DetectThreeBlackCrows(
            bar1,
            bar2,
            bar3
         );


      //==============================================================
      // MORNING STAR
      //
      // bar3 = candle mais antigo
      // bar2 = candle intermediário
      // bar1 = candle mais recente
      //==============================================================

      m_morningStar =
         DetectMorningStar(
            bar3,
            bar2,
            bar1
         );


      //==============================================================
      // EVENING STAR
      //==============================================================

      m_eveningStar =
         DetectEveningStar(
            bar3,
            bar2,
            bar1
         );


      //==============================================================
      // SCORES
      //==============================================================

      CalculateScores();


      //==============================================================
      // PRIMARY PATTERN
      //==============================================================

      DeterminePrimaryPattern();


      //==============================================================
      // WRITE CONTEXT
      //==============================================================

      WriteToContext(
         ctx
      );


      //==============================================================
      // STATUS
      //==============================================================

      ctx.validationMessage =
         "PatternRecognitionEngine: "
         "analise concluida com sucesso.";

      PrintFormat(
         "[PatternRecognitionEngine][Cycle=%I64u] "
         "Pattern=%s | Bullish=%.2f | Bearish=%.2f | "
         "Score=%.2f | State=%s",
         ctx.cycleId,
         m_primaryPattern,
         m_bullishScore,
         m_bearishScore,
         m_patternScore,
         ctx.LayerStateToString(
            ctx.patternState
         )
      );

      return true;
   }


   //=================================================================
   // PROCESS
   //=================================================================

   bool Process(
      AnalysisContext &ctx
   )
   {
      return Analyze(
         ctx
      );
   }


   //=================================================================
   // UPDATE
   //=================================================================

   bool Update(
      AnalysisContext &ctx
   )
   {
      return Analyze(
         ctx
      );
   }


   //=================================================================
   // GETTERS
   //=================================================================

   bool HasBullishPattern() const
   {
      return m_bullishPattern;
   }


   bool HasBearishPattern() const
   {
      return m_bearishPattern;
   }


   double GetBullishScore() const
   {
      return m_bullishScore;
   }


   double GetBearishScore() const
   {
      return m_bearishScore;
   }


   double GetPatternScore() const
   {
      return m_patternScore;
   }


   string GetPrimaryPattern() const
   {
      return m_primaryPattern;
   }


   bool IsDoji() const
   {
      return m_doji;
   }


   bool IsHammer() const
   {
      return m_hammer;
   }


   bool IsInvertedHammer() const
   {
      return m_invertedHammer;
   }


   bool IsShootingStar() const
   {
      return m_shootingStar;
   }


   bool IsHangingMan() const
   {
      return m_hangingMan;
   }


   bool IsBullishEngulfing() const
   {
      return m_bullishEngulfing;
   }


   bool IsBearishEngulfing() const
   {
      return m_bearishEngulfing;
   }


   bool IsBullishPinBar() const
   {
      return m_bullishPinBar;
   }


   bool IsBearishPinBar() const
   {
      return m_bearishPinBar;
   }


   bool IsInsideBar() const
   {
      return m_insideBar;
   }


   bool IsBullishInsideBreak() const
   {
      return m_bullishInsideBreak;
   }


   bool IsBearishInsideBreak() const
   {
      return m_bearishInsideBreak;
   }


   bool IsMorningStar() const
   {
      return m_morningStar;
   }


   bool IsEveningStar() const
   {
      return m_eveningStar;
   }


   bool IsThreeWhiteSoldiers() const
   {
      return m_threeWhiteSoldiers;
   }


   bool IsThreeBlackCrows() const
   {
      return m_threeBlackCrows;
   }


   //=================================================================
   // DEBUG
   //=================================================================

   string ToString() const
   {
      return StringFormat(
         "[PatternRecognition] "
         "Pattern=%s | "
         "Bullish=%.2f | "
         "Bearish=%.2f | "
         "Score=%.2f",
         m_primaryPattern,
         m_bullishScore,
         m_bearishScore,
         m_patternScore
      );
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_PATTERNRECOGNITIONENGINE_MQH
