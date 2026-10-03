//+------------------------------------------------------------------+
//| MarketDataEngine.mqh                                             |
//| Astra Trader AI                                                  |
//|                                                                  |
//| CAMADA 1 - MARKET DATA                                           |
//|                                                                  |
//| REGRA CENTRAL:                                                   |
//|   Esta é a única engine do pipeline que coleta histórico MT5.    |
//|                                                                  |
//| CONTRATO:                                                        |
//|   marketBars[0] = candle atual                                   |
//|   marketBars[1] = último candle fechado                          |
//|   marketBars[2] = candle fechado anterior                         |
//|                                                                  |
//| Engines downstream NÃO devem executar CopyRates().               |
//+------------------------------------------------------------------+
#ifndef ASTRA_MARKETDATAENGINE_MQH
#define ASTRA_MARKETDATAENGINE_MQH

#property strict

#include <AstraTrader\Analysis\AnalysisContext.mqh>


//+------------------------------------------------------------------+
//| MarketDataEngine                                                 |
//+------------------------------------------------------------------+
class MarketDataEngine
{
private:

   int m_atrPeriod;
   int m_historyBars;


   //=================================================================
   // NORMALIZA PREÇO
   //=================================================================

   double NormalizePrice(
      const double value,
      const int digits
   ) const
   {
      if(value <= 0.0)
         return 0.0;

      if(digits < 0)
         return value;

      return NormalizeDouble(
         value,
         digits
      );
   }


   //=================================================================
   // ATR
   //
   // O ATR oficial do MarketDataEngine é o ATR da última vela
   // FECHADA.
   //
   // shift=1.
   //=================================================================

   bool CalculateATR(
      const string symbol,
      const ENUM_TIMEFRAMES timeframe,
      const int period,
      double &atrValue
   ) const
   {
      atrValue =
         0.0;

      if(
         symbol == "" ||
         period <= 0 ||
         timeframe == PERIOD_CURRENT
      )
      {
         return false;
      }


      const int handle =
         iATR(
            symbol,
            timeframe,
            period
         );

      if(handle == INVALID_HANDLE)
         return false;


      double buffer[];

      ArraySetAsSeries(
         buffer,
         true
      );


      // shift=1 -> última vela fechada.
      const int copied =
         CopyBuffer(
            handle,
            0,
            1,
            1,
            buffer
         );


      IndicatorRelease(
         handle
      );


      if(copied < 1)
         return false;

      if(ArraySize(buffer) < 1)
         return false;

      if(buffer[0] <= 0.0)
         return false;


      atrValue =
         buffer[0];

      return true;
   }


   //=================================================================
   // TICK ATUAL
   //=================================================================

   bool GetCurrentTick(
      const string symbol,
      MqlTick &tick
   ) const
   {
      ZeroMemory(
         tick
      );

      if(symbol == "")
         return false;

      if(!SymbolInfoTick(
            symbol,
            tick
         ))
      {
         return false;
      }

      if(
         tick.bid <= 0.0 &&
         tick.ask <= 0.0 &&
         tick.last <= 0.0
      )
      {
         return false;
      }

      return true;
   }


   //=================================================================
   // HISTÓRICO CENTRAL
   //
   // CopyRates() ocorre exclusivamente aqui.
   //
   // Array series:
   // [0] atual
   // [1] fechado
   // [2] fechado anterior
   //=================================================================

   bool GetMarketHistory(
      const string symbol,
      const ENUM_TIMEFRAMES timeframe,
      MqlRates &rates[],
      int &copied
   ) const
   {
      copied =
         0;

      ArrayResize(
         rates,
         0
      );

      if(
         symbol == "" ||
         timeframe == PERIOD_CURRENT
      )
      {
         return false;
      }

      if(m_historyBars < 3)
         return false;


      ArraySetAsSeries(
         rates,
         true
      );


      copied =
         CopyRates(
            symbol,
            timeframe,
            0,
            m_historyBars,
            rates
         );


      if(copied < 3)
      {
         copied =
            0;

         ArrayResize(
            rates,
            0
         );

         return false;
      }


      if(ArraySize(rates) < 3)
      {
         copied =
            0;

         ArrayResize(
            rates,
            0
         );

         return false;
      }

      for(int i = 0; i < copied; i++)
      {
         if(!ValidateOHLC(rates[i]))
         {
            copied =
               0;

            ArrayResize(
               rates,
               0
            );

            return false;
         }
      }

      return true;
   }


   //=================================================================
   // OHLC
   //=================================================================

   bool ValidateOHLC(
      const MqlRates &bar
   ) const
   {
      if(bar.time <= 0)
         return false;

      if(
         !MathIsValidNumber(bar.open) ||
         !MathIsValidNumber(bar.high) ||
         !MathIsValidNumber(bar.low) ||
         !MathIsValidNumber(bar.close) ||
         bar.open == EMPTY_VALUE ||
         bar.high == EMPTY_VALUE ||
         bar.low == EMPTY_VALUE ||
         bar.close == EMPTY_VALUE
      )
      {
         return false;
      }

      if(
         bar.open <= 0.0 ||
         bar.high <= 0.0 ||
         bar.low <= 0.0 ||
         bar.close <= 0.0 ||
         bar.high < bar.low ||
         bar.high < bar.open ||
         bar.high < bar.close ||
         bar.low > bar.open ||
         bar.low > bar.close
      )
      {
         return false;
      }

      return true;
   }


   //=================================================================
   // HISTÓRICO MÍNIMO
   //=================================================================

   bool ValidateMinimumHistory(
      const MqlRates &rates[],
      const int count
   ) const
   {
      if(count < 3)
         return false;

      if(count != ArraySize(rates))
         return false;

      for(int i = 0; i < count; i++)
      {
         if(!ValidateOHLC(rates[i]))
            return false;
      }

      return true;
   }


   //=================================================================
   // VOLATILIDADE EM PONTOS
   //=================================================================

   double CalculateVolatilityPoints(
      const double atr,
      const double point
   ) const
   {
      if(
         atr <= 0.0 ||
         point <= 0.0
      )
      {
         return 0.0;
      }

      return atr / point;
   }


   //=================================================================
   // DADOS ESSENCIAIS
   //=================================================================

   bool ValidateEssentialData(
      const AnalysisContext &context
   ) const
   {
      if(context.symbol == "")
         return false;

      if(context.primaryTF == PERIOD_CURRENT)
         return false;

      if(
         !MathIsValidNumber(context.point) ||
         context.point == EMPTY_VALUE ||
         !MathIsValidNumber(context.tickSize) ||
         context.tickSize == EMPTY_VALUE ||
         !MathIsValidNumber(context.tickValue) ||
         context.tickValue == EMPTY_VALUE ||
         !MathIsValidNumber(context.bid) ||
         context.bid == EMPTY_VALUE ||
         !MathIsValidNumber(context.ask) ||
         context.ask == EMPTY_VALUE ||
         !MathIsValidNumber(context.price) ||
         context.price == EMPTY_VALUE ||
         !MathIsValidNumber(context.spreadPoints) ||
         context.spreadPoints == EMPTY_VALUE ||
         !MathIsValidNumber(context.atr) ||
         context.atr == EMPTY_VALUE ||
         !MathIsValidNumber(context.volatility) ||
         context.volatility == EMPTY_VALUE ||
         !MathIsValidNumber(context.open) ||
         context.open == EMPTY_VALUE ||
         !MathIsValidNumber(context.high) ||
         context.high == EMPTY_VALUE ||
         !MathIsValidNumber(context.low) ||
         context.low == EMPTY_VALUE ||
         !MathIsValidNumber(context.close) ||
         context.close == EMPTY_VALUE
      )
      {
         return false;
      }

      if(context.point <= 0.0)
         return false;

      if(context.digits < 0)
         return false;

      if(
         context.bid <= 0.0 &&
         context.ask <= 0.0 &&
         context.price <= 0.0
      )
      {
         return false;
      }

      if(context.high <= 0.0)
         return false;

      if(context.low <= 0.0)
         return false;

      if(context.open <= 0.0)
         return false;

      if(context.close <= 0.0)
         return false;

      if(context.high < context.low)
         return false;

      if(context.high < context.open)
         return false;

      if(context.high < context.close)
         return false;

      if(context.low > context.open)
         return false;

      if(context.low > context.close)
         return false;

      return true;
   }


   //=================================================================
   // LIMPA MARKET DATA
   //=================================================================

   void ResetMarketData(
      AnalysisContext &context
   ) const
   {
      context.dataQuality =
         ASTRA_DATA_UNKNOWN;
      context.marketDataSource =
         "";
      context.syntheticMarketBarsCount =
         0;

      context.bid =
         0.0;

      context.ask =
         0.0;

      context.price =
         0.0;

      context.point =
         0.0;

      context.digits =
         0;

      context.tickSize =
         0.0;

      context.tickValue =
         0.0;

      context.spreadPoints =
         0.0;

      context.volume =
         0;

      context.tickVolume =
         0;

      context.atr =
         0.0;

      context.volatility =
         0.0;

      context.high =
         0.0;

      context.low =
         0.0;

      context.open =
         0.0;

      context.close =
         0.0;

      context.barTime =
         0;

      context.barsAvailable =
         0;

      context.marketDataBarCount =
         0;

      context.marketDataReady =
         false;

      context.marketBarsCount =
         0;

      context.marketHistoryReady =
         false;


      ArrayResize(
         context.marketBars,
         0
      );


      ZeroMemory(
         context.currentBar
      );

      ZeroMemory(
         context.previousBar
      );

      ZeroMemory(
         context.olderBar
      );
   }


   //=================================================================
   // COMMIT HISTÓRICO
   //=================================================================

   bool CommitMarketHistory(
      AnalysisContext &context,
      const MqlRates &rates[],
      const int count
   ) const
   {
      if(
         count < 3 ||
         ArraySize(rates) < 3
      )
      {
         return false;
      }


      if(
         ArrayResize(
            context.marketBars,
            count
         ) != count
      )
      {
         return false;
      }


      for(int i = 0; i < count; i++)
      {
         context.marketBars[i] =
            rates[i];
      }


      context.marketBarsCount =
         count;

      context.marketHistoryReady =
         true;


      context.currentBar =
         context.marketBars[0];

      context.previousBar =
         context.marketBars[1];

      context.olderBar =
         context.marketBars[2];


      context.marketDataBarCount =
         count;

      context.marketDataReady =
         true;


      return true;
   }


   bool LoadMTFSeries(
      const AnalysisContext &context,
      const string symbol,
      const ENUM_TIMEFRAMES timeframe,
      MqlRates &rates[]
   ) const
   {
      ArrayResize(
         rates,
         0
      );

      if(symbol == "" || timeframe == PERIOD_CURRENT)
         return false;

      ArraySetAsSeries(
         rates,
         true
      );

      const int copied =
         CopyRates(
            symbol,
            timeframe,
            1,
            250,
            rates
         );

      if(copied < 50)
      {
         ArrayResize(
            rates,
            0
         );

         return false;
      }

      return true;
   }


public:

   //=================================================================
   // CONSTRUTOR
   //=================================================================

   MarketDataEngine()
   {
      m_atrPeriod =
         14;

      m_historyBars =
         500;
   }


   //=================================================================
   // CONSTRUTOR CONFIGURÁVEL
   //=================================================================

   MarketDataEngine(
      const int atrPeriod,
      const int historyBars
   )
   {
      m_atrPeriod =
         atrPeriod;

      if(m_atrPeriod <= 0)
         m_atrPeriod = 14;

      m_historyBars =
         historyBars;

      if(m_historyBars < 3)
         m_historyBars = 500;
   }


   //=================================================================
   // SET ATR
   //=================================================================

   void SetATRPeriod(
      const int period
   )
   {
      if(period <= 0)
         return;

      m_atrPeriod =
         period;
   }


   int GetATRPeriod() const
   {
      return m_atrPeriod;
   }


   //=================================================================
   // SET HISTORY
   //=================================================================

   void SetHistoryBars(
      const int bars
   )
   {
      if(bars < 3)
         return;

      m_historyBars =
         bars;
   }


   int GetHistoryBars() const
   {
      return m_historyBars;
   }


   //=================================================================
   // PROCESS
   //=================================================================

   bool Process(
      AnalysisContext &context
   )
   {
      //==============================================================
      // RESET SOMENTE MARKET DATA
      //==============================================================

      ResetMarketData(
         context
      );


      //==============================================================
      // SYMBOL
      //==============================================================

      string symbol =
         context.symbol;

      if(symbol == "")
         symbol =
            _Symbol;


      if(symbol == "")
      {
         context.dataQuality =
            ASTRA_DATA_INVALID;

         context.contextValid =
            false;

         context.validationMessage =
            "MarketDataEngine: simbolo invalido.";

         return false;
      }


      //==============================================================
      // TIMEFRAME
      //==============================================================

      ENUM_TIMEFRAMES timeframe =
         context.primaryTF;

      if(timeframe == PERIOD_CURRENT)
         timeframe =
            (ENUM_TIMEFRAMES)_Period;


      if(timeframe == PERIOD_CURRENT)
      {
         context.dataQuality =
            ASTRA_DATA_INVALID;

         context.contextValid =
            false;

         context.validationMessage =
            "MarketDataEngine: timeframe invalido.";

         return false;
      }


      //==============================================================
      // SYMBOL
      //==============================================================

      if(!SymbolSelect(
            symbol,
            true
         ))
      {
         context.dataQuality =
            ASTRA_DATA_INVALID;

         context.contextValid =
            false;

         context.validationMessage =
            "MarketDataEngine: "
            "falha ao selecionar simbolo.";

         return false;
      }


      context.symbol =
         symbol;

      context.primaryTF =
         timeframe;


      //==============================================================
      // POINT
      //==============================================================

      const double point =
         SymbolInfoDouble(
            symbol,
            SYMBOL_POINT
         );

      if(point <= 0.0)
      {
         context.dataQuality =
            ASTRA_DATA_INVALID;

         context.contextValid =
            false;

         context.validationMessage =
            "MarketDataEngine: SYMBOL_POINT invalido.";

         return false;
      }

      context.point =
         point;


      //==============================================================
      // DIGITS
      //==============================================================

      const int digits =
         (int)
         SymbolInfoInteger(
            symbol,
            SYMBOL_DIGITS
         );

      if(digits < 0)
      {
         context.dataQuality =
            ASTRA_DATA_INVALID;

         context.contextValid =
            false;

         context.validationMessage =
            "MarketDataEngine: digits invalido.";

         return false;
      }

      context.digits =
         digits;


      //==============================================================
      // TICK SIZE / VALUE
      //==============================================================

      context.tickSize =
         SymbolInfoDouble(
            symbol,
            SYMBOL_TRADE_TICK_SIZE
         );

      if(context.tickSize <= 0.0)
         context.tickSize =
            point;


      context.tickValue =
         SymbolInfoDouble(
            symbol,
            SYMBOL_TRADE_TICK_VALUE
         );


      //==============================================================
      // TICK
      //==============================================================

      MqlTick tick;

      if(!GetCurrentTick(
            symbol,
            tick
         ))
      {
         context.dataQuality =
            ASTRA_DATA_INVALID;

         context.contextValid =
            false;

         context.validationMessage =
            "MarketDataEngine: "
            "tick atual indisponivel.";

         return false;
      }


      //==============================================================
      // BID
      //==============================================================

      if(tick.bid > 0.0)
      {
         context.bid =
            NormalizePrice(
               tick.bid,
               digits
            );
      }


      //==============================================================
      // ASK
      //==============================================================

      if(tick.ask > 0.0)
      {
         context.ask =
            NormalizePrice(
               tick.ask,
               digits
            );
      }


      //==============================================================
      // PRICE
      //==============================================================

      if(context.bid > 0.0)
      {
         context.price =
            context.bid;
      }
      else
      if(context.ask > 0.0)
      {
         context.price =
            context.ask;
      }
      else
      if(tick.last > 0.0)
      {
         context.price =
            NormalizePrice(
               tick.last,
               digits
            );
      }


      //==============================================================
      // SPREAD
      //==============================================================

      if(
         context.bid > 0.0 &&
         context.ask > 0.0 &&
         context.ask >= context.bid
      )
      {
         context.spreadPoints =
            MathMax(
               0.0,
               (
                  context.ask -
                  context.bid
               ) / point
            );
      }


      //==============================================================
      // HISTÓRICO
      //==============================================================

      MqlRates rates[];

      int copied =
         0;


      if(!GetMarketHistory(
            symbol,
            timeframe,
            rates,
            copied
         ))
      {
         context.dataQuality =
            ASTRA_DATA_INVALID;

         context.contextValid =
            false;

         context.marketDataReady =
            false;

         context.marketHistoryReady =
            false;

         context.validationMessage =
            "MarketDataEngine: "
            "historico insuficiente.";

         return false;
      }


      //==============================================================
      // VALIDAR HISTÓRICO
      //==============================================================

      if(!ValidateMinimumHistory(
            rates,
            copied
         ))
      {
         context.dataQuality =
            ASTRA_DATA_INVALID;

         context.contextValid =
            false;

         context.marketDataReady =
            false;

         context.marketHistoryReady =
            false;

         context.validationMessage =
            "MarketDataEngine: "
            "barras invalidas no historico.";

         return false;
      }


      //==============================================================
      // COMMIT
      //==============================================================

      if(!CommitMarketHistory(
            context,
            rates,
            copied
         ))
      {
         context.dataQuality =
            ASTRA_DATA_INVALID;

         context.contextValid =
            false;

         context.marketDataReady =
            false;

         context.marketHistoryReady =
            false;

         context.validationMessage =
            "MarketDataEngine: "
            "falha ao gravar historico.";

         return false;
      }


      //==============================================================
      // CURRENT BAR
      //==============================================================

      context.barTime =
         context.currentBar.time;


      context.open =
         NormalizePrice(
            context.currentBar.open,
            digits
         );

      context.high =
         NormalizePrice(
            context.currentBar.high,
            digits
         );

      context.low =
         NormalizePrice(
            context.currentBar.low,
            digits
         );

      context.close =
         NormalizePrice(
            context.currentBar.close,
            digits
         );


      context.volume =
         (long)
         context.currentBar.real_volume;

      context.tickVolume =
         (long)
         context.currentBar.tick_volume;


      //==============================================================
      // BARS AVAILABLE
      //==============================================================

      const int bars =
         Bars(
            symbol,
            timeframe
         );

      context.barsAvailable =
         (
            bars > 0
            ? bars
            : copied
         );


      //==============================================================
      // ATR FECHADO
      //==============================================================

      double atrValue =
         0.0;

      if(
         CalculateATR(
            symbol,
            timeframe,
            m_atrPeriod,
            atrValue
         )
      )
      {
         context.atr =
            NormalizePrice(
               atrValue,
               digits
            );

         context.volatility =
            CalculateVolatilityPoints(
               context.atr,
               context.point
            );
      }
      else
      {
         context.atr =
            0.0;

         context.volatility =
            0.0;
      }


      //==============================================================
      // ESSENCIAIS
      //==============================================================

      if(!ValidateEssentialData(
            context
         ))
      {
         context.dataQuality =
            ASTRA_DATA_INVALID;

         context.contextValid =
            false;

         context.marketDataReady =
            false;

         context.marketHistoryReady =
            false;

         context.validationMessage =
            "MarketDataEngine: "
            "dados essenciais invalidos.";

         return false;
      }


      //==============================================================
      // CONTRATO MINIMO
      //==============================================================

      if(
         context.marketBarsCount < 3 ||
         ArraySize(context.marketBars) < 3
      )
      {
         context.dataQuality =
            ASTRA_DATA_INVALID;

         context.contextValid =
            false;

         context.marketDataReady =
            false;

         context.marketHistoryReady =
            false;

         context.validationMessage =
            "MarketDataEngine: "
            "contrato minimo nao atendido.";

         return false;
      }


      //==============================================================
      // SINCRONIZAÇÃO
      //==============================================================

      context.currentBar =
         context.marketBars[0];

      context.previousBar =
         context.marketBars[1];

      context.olderBar =
         context.marketBars[2];

      context.marketDataBarCount =
         context.marketBarsCount;

      context.marketDataReady =
         true;

      context.marketHistoryReady =
         true;

      context.mtfDataReady = false;

      LoadMTFSeries(context, symbol, PERIOD_D1, context.mtfD1);
      LoadMTFSeries(context, symbol, PERIOD_H4, context.mtfH4);
      LoadMTFSeries(context, symbol, PERIOD_H1, context.mtfH1);
      LoadMTFSeries(context, symbol, PERIOD_M15, context.mtfM15);
      LoadMTFSeries(context, symbol, PERIOD_M5, context.mtfM5);

      context.mtfDataReady =
         ArraySize(context.mtfD1) > 0 &&
         ArraySize(context.mtfH4) > 0 &&
         ArraySize(context.mtfH1) > 0 &&
         ArraySize(context.mtfM15) > 0 &&
         ArraySize(context.mtfM5) > 0;

      context.dataQuality =
         ASTRA_DATA_GOOD;

      context.contextValid =
         true;
      context.marketDataSource =
         "MT5";
      context.syntheticMarketBarsCount =
         0;


      //==============================================================
      // STATUS
      //==============================================================

      if(context.atr <= 0.0)
      {
         context.validationMessage =
            "MarketDataEngine: "
            "dados validos; "
            "ATR indisponivel.";

         return true;
      }


      context.validationMessage =
         "MarketDataEngine: "
         "market data e historico "
         "central carregados com sucesso.";

      return true;
   }


   //=================================================================
   // ALIASES
   //=================================================================

   bool Update(
      AnalysisContext &context
   )
   {
      return Process(
         context
      );
   }


   bool Load(
      AnalysisContext &context
   )
   {
      return Process(
         context
      );
   }


   //=================================================================
   // IS VALID
   //=================================================================

   bool IsValid(
      const AnalysisContext &context
   ) const
   {
      if(
         context.dataQuality ==
         ASTRA_DATA_INVALID
      )
      {
         return false;
      }

      if(!context.marketDataReady)
         return false;

      if(!context.marketHistoryReady)
         return false;

      if(context.marketBarsCount < 3)
         return false;

      if(ArraySize(context.marketBars) < 3)
         return false;

      if(!context.HasMarketDataBars())
         return false;

      if(!context.HasMarketHistory())
         return false;

      return ValidateEssentialData(
         context
      );
   }


   //=================================================================
   // ERROR
   //=================================================================

   string GetLastErrorDescription() const
   {
      return
         "MarketDataEngine: "
         "dados centralizados no AnalysisContext.";
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_MARKETDATAENGINE_MQH
