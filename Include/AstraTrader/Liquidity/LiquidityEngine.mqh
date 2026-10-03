//+------------------------------------------------------------------+
//| LiquidityEngine.mqh                                              |
//| Astra Trader AI                                                  |
//|                                                                  |
//| ESTÁGIO - LIQUIDITY                                              |
//|                                                                  |
//| Responsabilidades:                                               |
//| - Detectar Equal Highs                                            |
//| - Detectar Equal Lows                                             |
//| - Detectar Bullish Liquidity Sweep                               |
//| - Detectar Bearish Liquidity Sweep                               |
//| - Detectar Liquidity Grab                                         |
//| - Avaliar liquidez próxima                                        |
//| - Produzir liquidityScore                                         |
//|                                                                  |
//| CONTRATO ARQUITETURAL:                                            |
//| - NÃO executa CopyRates()                                        |
//| - NÃO executa CopyHigh()                                         |
//| - NÃO executa CopyLow()                                          |
//| - NÃO executa CopyClose()                                        |
//| - NÃO executa CopyTime()                                         |
//| - NÃO acessa histórico diretamente no terminal                    |
//| - NÃO reseta o AnalysisContext inteiro                            |
//| - Consome exclusivamente AnalysisContext                          |
//| - Histórico oficial = ctx.marketBars[]                            |
//+------------------------------------------------------------------+
#ifndef ASTRA_LIQUIDITYENGINE_MQH
#define ASTRA_LIQUIDITYENGINE_MQH

#property strict

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>


//+------------------------------------------------------------------+
//| LiquidityEngine                                                   |
//+------------------------------------------------------------------+
class LiquidityEngine
{
private:

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
   // HISTÓRICO DISPONÍVEL
   //=================================================================

   int GetAvailableBars(
      const AnalysisContext &ctx
   ) const
   {
      int count =
         ctx.marketBarsCount;

      int arraySize =
         ArraySize(
            ctx.marketBars
         );

      if(count <= 0)
         count = arraySize;

      if(count > arraySize)
         count = arraySize;

      if(count < 0)
         count = 0;

      return count;
   }


   //=================================================================
   // VALIDA BARRA
   //=================================================================

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


   //=================================================================
   // VALIDA HISTÓRICO
   //=================================================================

   bool ValidateMarketHistory(
      const AnalysisContext &ctx
   ) const
   {
      if(!ctx.marketHistoryReady)
         return false;

      int count =
         GetAvailableBars(
            ctx
         );

      if(count < 3)
         return false;

      if(ArraySize(ctx.marketBars) < 3)
         return false;

      for(int i = 0; i < 3; i++)
      {
         if(!IsValidBar(ctx.marketBars[i]))
            return false;
      }

      return true;
   }


   //=================================================================
   // PREÇO PRÓXIMO DO NÍVEL
   //=================================================================

   bool PriceNearLevel(
      const double price,
      const double level,
      const double tolerance
   ) const
   {
      if(price <= 0.0 ||
         level <= 0.0 ||
         tolerance <= 0.0)
      {
         return false;
      }

      return (
         MathAbs(price - level) <= tolerance
      );
   }


   //=================================================================
   // EQUAL HIGH
   //=================================================================

   bool HasEqualHigh(
      const AnalysisContext &ctx,
      const double targetLevel,
      const double tolerance
   ) const
   {
      if(targetLevel <= 0.0 ||
         tolerance <= 0.0)
      {
         return false;
      }

      int count =
         GetAvailableBars(
            ctx
         );

      int matches =
         0;

      for(int i = 1;
          i < count;
          i++)
      {
         MqlRates bar =
            ctx.marketBars[i];

         if(!IsValidBar(bar))
            continue;

         if(
            PriceNearLevel(
               bar.high,
               targetLevel,
               tolerance
            )
         )
         {
            matches++;

            if(matches >= 2)
               return true;
         }
      }

      return false;
   }


   //=================================================================
   // EQUAL LOW
   //=================================================================

   bool HasEqualLow(
      const AnalysisContext &ctx,
      const double targetLevel,
      const double tolerance
   ) const
   {
      if(targetLevel <= 0.0 ||
         tolerance <= 0.0)
      {
         return false;
      }

      int count =
         GetAvailableBars(
            ctx
         );

      int matches =
         0;

      for(int i = 1;
          i < count;
          i++)
      {
         MqlRates bar =
            ctx.marketBars[i];

         if(!IsValidBar(bar))
            continue;

         if(
            PriceNearLevel(
               bar.low,
               targetLevel,
               tolerance
            )
         )
         {
            matches++;

            if(matches >= 2)
               return true;
         }
      }

      return false;
   }


   //=================================================================
   // BULLISH LIQUIDITY SWEEP
   //
   // Sweep abaixo de uma liquidez inferior seguido por fechamento
   // acima do nível.
   //
   // Utilizamos somente candles fechados [1] e [2].
   //=================================================================

   bool DetectBullishSweep(
      const AnalysisContext &ctx,
      const double lowLevel,
      const double tolerance
   ) const
   {
      if(lowLevel <= 0.0 ||
         tolerance <= 0.0)
      {
         return false;
      }

      int count =
         GetAvailableBars(
            ctx
         );

      if(count < 2)
         return false;

      bool swept =
         false;

      if(
         ctx.marketBars[1].low <
         lowLevel - tolerance
      )
      {
         swept = true;
      }

      if(
         !swept &&
         count >= 3 &&
         ctx.marketBars[2].low <
         lowLevel - tolerance
      )
      {
         swept = true;
      }

      if(!swept)
         return false;

      return (
         ctx.marketBars[1].close >
         lowLevel
      );
   }


   //=================================================================
   // BEARISH LIQUIDITY SWEEP
   //
   // Sweep acima de uma liquidez superior seguido por fechamento
   // abaixo do nível.
   //=================================================================

   bool DetectBearishSweep(
      const AnalysisContext &ctx,
      const double highLevel,
      const double tolerance
   ) const
   {
      if(highLevel <= 0.0 ||
         tolerance <= 0.0)
      {
         return false;
      }

      int count =
         GetAvailableBars(
            ctx
         );

      if(count < 2)
         return false;

      bool swept =
         false;

      if(
         ctx.marketBars[1].high >
         highLevel + tolerance
      )
      {
         swept = true;
      }

      if(
         !swept &&
         count >= 3 &&
         ctx.marketBars[2].high >
         highLevel + tolerance
      )
      {
         swept = true;
      }

      if(!swept)
         return false;

      return (
         ctx.marketBars[1].close <
         highLevel
      );
   }


   //=================================================================
   // TOLERÂNCIA DINÂMICA
   //=================================================================

   double CalculateTolerance(
      const AnalysisContext &ctx
   ) const
   {
      double referencePrice =
         ctx.price;

      if(referencePrice <= 0.0)
         referencePrice =
            ctx.close;

      if(
         referencePrice <= 0.0 &&
         ArraySize(ctx.marketBars) > 1
      )
      {
         referencePrice =
            ctx.marketBars[1].close;
      }

      if(referencePrice <= 0.0)
         return 0.0;


      double tolerance =
         0.0;


      if(ctx.atr > 0.0)
      {
         tolerance =
            ctx.atr * 0.25;
      }


      double percentageTolerance =
         referencePrice * 0.0005;


      if(
         percentageTolerance >
         tolerance
      )
      {
         tolerance =
            percentageTolerance;
      }


      if(
         tolerance <= 0.0 &&
         ctx.point > 0.0
      )
      {
         tolerance =
            ctx.point * 10.0;
      }


      return tolerance;
   }


public:

   //=================================================================
   // CONSTRUCTOR
   //=================================================================

   LiquidityEngine()
   {
   }


   //=================================================================
   // ANALYZE
   //=================================================================

   bool Analyze(
      AnalysisContext &ctx
   )
   {
      //==============================================================
      // RESET SOMENTE DA CAMADA LIQUIDITY
      //==============================================================

      ctx.liquiditySweep =
         false;

      ctx.liquidityGrab =
         false;

      ctx.buySideLiquidityTaken =
         false;

      ctx.sellSideLiquidityTaken =
         false;

      ctx.liquidityScore =
         0.0;

      ctx.nearestLiquidityHigh =
         0.0;

      ctx.nearestLiquidityLow =
         0.0;

      ctx.liquidityState =
         LAYER_NEUTRAL;


      //==============================================================
      // CONTEXTO
      //==============================================================

      if(ctx.symbol == "")
      {
         ctx.liquidityState =
            LAYER_INVALID;

         return false;
      }


      //==============================================================
      // HISTÓRICO
      //==============================================================

      if(!ValidateMarketHistory(ctx))
      {
         ctx.liquidityState =
            LAYER_INVALID;

         PrintFormat(
            "[LiquidityEngine] Histórico central inválido | "
            "Symbol=%s | TF=%s | Bars=%d",
            ctx.symbol,
            EnumToString(ctx.primaryTF),
            GetAvailableBars(ctx)
         );

         return false;
      }


      //==============================================================
      // SINCRONIZAÇÃO DE BARRAS
      //==============================================================

      ctx.currentBar =
         ctx.marketBars[0];

      ctx.previousBar =
         ctx.marketBars[1];

      ctx.olderBar =
         ctx.marketBars[2];


      //==============================================================
      // SWINGS NECESSÁRIOS
      //==============================================================

      if(
         ctx.lastSwingHighPrice <= 0.0 ||
         ctx.lastSwingLowPrice <= 0.0
      )
      {
         ctx.liquidityState =
            LAYER_NEUTRAL;

         ctx.validationMessage =
            "LiquidityEngine: swings estruturais ainda indisponíveis.";

         return true;
      }


      //==============================================================
      // TOLERÂNCIA
      //==============================================================

      double tolerance =
         CalculateTolerance(
            ctx
         );

      if(tolerance <= 0.0)
      {
         ctx.liquidityState =
            LAYER_INVALID;

         return false;
      }


      //==============================================================
      // EQUAL LEVELS
      //==============================================================

      bool equalHigh =
         HasEqualHigh(
            ctx,
            ctx.lastSwingHighPrice,
            tolerance
         );

      bool equalLow =
         HasEqualLow(
            ctx,
            ctx.lastSwingLowPrice,
            tolerance
         );


      //==============================================================
      // NÍVEIS MAIS PRÓXIMOS
      //==============================================================

      ctx.nearestLiquidityHigh =
         ctx.lastSwingHighPrice;

      ctx.nearestLiquidityLow =
         ctx.lastSwingLowPrice;


      //==============================================================
      // SWEEP BULLISH
      //
      // SELL-SIDE LIQUIDITY
      //==============================================================

      bool bullishSweep =
         DetectBullishSweep(
            ctx,
            ctx.lastSwingLowPrice,
            tolerance
         );


      //==============================================================
      // SWEEP BEARISH
      //
      // BUY-SIDE LIQUIDITY
      //==============================================================

      bool bearishSweep =
         DetectBearishSweep(
            ctx,
            ctx.lastSwingHighPrice,
            tolerance
         );


      //==============================================================
      // NÃO FORÇAR DIREÇÃO QUANDO NÃO HOUVER EVIDÊNCIA
      //==============================================================

      if(
         ctx.structuralBias ==
         BIAS_BULLISH
      )
      {
         ctx.liquiditySweep =
            bullishSweep;

         ctx.liquidityGrab =
            false;
      }
      else
      if(
         ctx.structuralBias ==
         BIAS_BEARISH
      )
      {
         ctx.liquiditySweep =
            false;

         ctx.liquidityGrab =
            bearishSweep;
      }
      else
      {
         ctx.liquiditySweep =
            bullishSweep;

         ctx.liquidityGrab =
            bearishSweep;
      }


      //==============================================================
      // LIQUIDITY TAKEN
      //==============================================================

      if(ctx.liquiditySweep)
      {
         ctx.sellSideLiquidityTaken =
            true;
      }

      if(ctx.liquidityGrab)
      {
         ctx.buySideLiquidityTaken =
            true;
      }


      //==============================================================
      // SCORE
      //==============================================================

      double score =
         0.0;


      if(equalHigh)
         score += 20.0;


      if(equalLow)
         score += 20.0;


      if(ctx.liquiditySweep)
         score += 35.0;


      if(ctx.liquidityGrab)
         score += 35.0;


      ctx.liquidityScore =
         Clamp(
            score,
            0.0,
            100.0
         );


      //==============================================================
      // STATE
      //==============================================================

      if(
         ctx.liquiditySweep ||
         ctx.liquidityGrab ||
         equalHigh ||
         equalLow
      )
      {
         ctx.liquidityState =
            LAYER_VALID;
      }
      else
      {
         ctx.liquidityState =
            LAYER_NEUTRAL;
      }


      //==============================================================
      // LOG
      //==============================================================

      PrintFormat(
         "[LiquidityEngine] %s %s | "
         "Bars=%d | "
         "EqualHigh=%s | "
         "EqualLow=%s | "
         "BullSweep=%s | "
         "BearSweep=%s | "
         "SellSideTaken=%s | "
         "BuySideTaken=%s | "
         "Score=%.1f",
         ctx.symbol,
         EnumToString(ctx.primaryTF),
         GetAvailableBars(ctx),
         equalHigh ? "true" : "false",
         equalLow ? "true" : "false",
         ctx.liquiditySweep ? "true" : "false",
         ctx.liquidityGrab ? "true" : "false",
         ctx.sellSideLiquidityTaken ? "true" : "false",
         ctx.buySideLiquidityTaken ? "true" : "false",
         ctx.liquidityScore
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
      return Analyze(ctx);
   }


   //=================================================================
   // UPDATE
   //=================================================================

   bool Update(
      AnalysisContext &ctx
   )
   {
      return Analyze(ctx);
   }


   //=================================================================
   // IS VALID
   //=================================================================

   bool IsValid(
      const AnalysisContext &ctx
   ) const
   {
      if(
         ctx.liquidityState ==
         LAYER_INVALID
      )
      {
         return false;
      }

      if(!ctx.marketHistoryReady)
         return false;

      if(GetAvailableBars(ctx) < 3)
         return false;

      return true;
   }


   //=================================================================
   // LAST ERROR
   //=================================================================

   string GetLastErrorDescription() const
   {
      return
         "LiquidityEngine: análise executada exclusivamente sobre "
         "AnalysisContext.marketBars[].";
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_LIQUIDITYENGINE_MQH
//+------------------------------------------------------------------+
