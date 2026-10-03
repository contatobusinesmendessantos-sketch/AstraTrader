//+------------------------------------------------------------------+
//| MarketScanner.mqh                                                |
//| Astra Trader AI                                                  |
//|                                                                  |
//| ESTÁGIO 1 - MARKET SANITY CHECK                                  |
//|                                                                  |
//| Responsabilidade:                                                |
//| - validar símbolo                                                |
//| - validar timeframe                                               |
//| - verificar disponibilidade mínima de barras                     |
//| - preparar apenas identidade do ciclo                            |
//|                                                                  |
//| NÃO é responsável por:                                           |
//| - Market Structure                                               |
//| - Liquidity                                                      |
//| - Smart Money                                                    |
//| - Decision                                                       |
//| - Risk                                                           |
//| - Execution                                                      |
//+------------------------------------------------------------------+
#ifndef ASTRA_MARKETSCANNER_MQH
#define ASTRA_MARKETSCANNER_MQH

#property strict

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>


//+------------------------------------------------------------------+
//| MarketScanner                                                    |
//+------------------------------------------------------------------+
class MarketScanner
{
private:

   int m_minBarsRequired;


   //=================================================================
   // RESET MÍNIMO DO SCANNER
   //
   // Não destrói dados analíticos já existentes.
   //=================================================================

   void PrepareContextIdentity(
      const string symbol,
      const ENUM_TIMEFRAMES timeframe,
      AnalysisContext &ctx
   )
   {
      ctx.symbol =
         symbol;

      ctx.primaryTF =
         timeframe;


      // Somente estado diretamente pertencente ao scanner.

      ctx.marketDataReady =
         false;

      ctx.marketHistoryReady =
         false;

      ctx.marketDataBarCount =
         0;

      ctx.marketBarsCount =
         0;
   }


public:

   //=================================================================
   // CONSTRUCTOR
   //=================================================================

   MarketScanner(
      const int minBarsRequired = ASTRA_SCANNER_MIN_BARS
   )
   {
      m_minBarsRequired =
         MathMax(
            3,
            minBarsRequired
         );
   }


   //=================================================================
   // SCAN
   //=================================================================

   bool Scan(
      const string symbol,
      const ENUM_TIMEFRAMES timeframe,
      AnalysisContext &ctx
   )
   {
      //==============================================================
      // IDENTIDADE
      //==============================================================

      PrepareContextIdentity(
         symbol,
         timeframe,
         ctx
      );


      //==============================================================
      // SYMBOL
      //==============================================================

      if(symbol == "")
      {
         ctx.contextValid =
            false;

         ctx.validationMessage =
            "MarketScanner: símbolo vazio.";

         Print(
            "[MarketScanner] Símbolo inválido."
         );

         return false;
      }


      //==============================================================
      // TIMEFRAME
      //==============================================================

      if(timeframe == PERIOD_CURRENT)
      {
         ctx.contextValid =
            false;

         ctx.validationMessage =
            "MarketScanner: PERIOD_CURRENT não permitido.";

         Print(
            "[MarketScanner] Timeframe inválido."
         );

         return false;
      }


      //==============================================================
      // SYMBOL SELECT
      //
      // Esta é uma função de infraestrutura do scanner.
      // Não coleta OHLC nem cria histórico.
      //==============================================================

      if(!SymbolSelect(
            symbol,
            true
         ))
      {
         ctx.contextValid =
            false;

         ctx.validationMessage =
            StringFormat(
               "MarketScanner: não foi possível selecionar %s.",
               symbol
            );

         PrintFormat(
            "[MarketScanner] Não foi possível selecionar o símbolo %s.",
            symbol
         );

         return false;
      }


      //==============================================================
      // BARS DISPONÍVEIS
      //==============================================================

      int bars =
         Bars(
            symbol,
            timeframe
         );


      if(bars < m_minBarsRequired)
      {
         ctx.contextValid =
            false;

         ctx.validationMessage =
            StringFormat(
               "MarketScanner: barras insuficientes | "
               "Symbol=%s | TF=%s | Bars=%d | Min=%d",
               symbol,
               EnumToString(timeframe),
               bars,
               m_minBarsRequired
            );

         PrintFormat(
            "[MarketScanner] Dados insuficientes para %s %s: "
            "%d barras (mínimo %d).",
            symbol,
            EnumToString(timeframe),
            bars,
            m_minBarsRequired
         );

         return false;
      }


      //==============================================================
      // SANITY CHECK APROVADO
      //==============================================================

      ctx.barsAvailable =
         bars;

      ctx.contextValid =
         true;

      ctx.validationMessage =
         "MarketScanner: símbolo, timeframe e disponibilidade "
         "mínima de barras confirmados.";

      PrintFormat(
         "[MarketScanner] READY | "
         "Symbol=%s | TF=%s | Bars=%d",
         symbol,
         EnumToString(timeframe),
         bars
      );


      return true;
   }


   //=================================================================
   // SET MIN BARS
   //=================================================================

   void SetMinimumBars(
      const int value
   )
   {
      if(value < 3)
         return;

      m_minBarsRequired =
         value;
   }


   //=================================================================
   // GET MIN BARS
   //=================================================================

   int GetMinimumBars() const
   {
      return m_minBarsRequired;
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_MARKETSCANNER_MQH
//+------------------------------------------------------------------+
