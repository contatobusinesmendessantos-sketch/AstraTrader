//+------------------------------------------------------------------+
//| MarketMemory.mqh                                                 |
//| Astra Trader AI                                                  |
//|                                                                  |
//| Estágio 17b - Memória de contexto                                |
//|                                                                  |
//| IMPORTANTE:                                                       |
//| - Não depende de AnalysisContext                                 |
//| - Não carrega histórico                                          |
//| - Não executa análise                                             |
//| - Não executa ordens                                              |
//+------------------------------------------------------------------+
#ifndef ASTRA_MARKETMEMORY_MQH
#define ASTRA_MARKETMEMORY_MQH

#property strict

#include <AstraTrader\Core\Types.mqh>


//+------------------------------------------------------------------+
//| MarketMemory                                                     |
//+------------------------------------------------------------------+
class MarketMemory
{
private:

   //=================================================================
   // IDENTIFICAÇÃO
   //=================================================================

   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;


   //=================================================================
   // ÚLTIMA OPERAÇÃO
   //=================================================================

   double m_lastPrice;
   double m_lastStopLoss;
   double m_lastTakeProfit;


   //=================================================================
   // ÚLTIMA DECISÃO
   //=================================================================

   int    m_lastDecision;
   double m_lastConfidence;


   //=================================================================
   // ESTADO
   //=================================================================

   bool m_initialized;


   //=================================================================
   // OBTÉM POINT DO SÍMBOLO
   //=================================================================

   double GetSymbolPoint() const
   {
      if(m_symbol == "")
         return 0.0;

      double point =
         SymbolInfoDouble(
            m_symbol,
            SYMBOL_POINT
         );

      if(point <= 0.0)
         return 0.0;

      return point;
   }


public:

   //=================================================================
   // CONSTRUCTOR
   //=================================================================

   MarketMemory()
   {
      Reset();
   }


   //=================================================================
   // RESET
   //=================================================================

   void Reset()
   {
      m_symbol =
         "";

      m_timeframe =
         PERIOD_CURRENT;

      m_lastPrice =
         0.0;

      m_lastStopLoss =
         0.0;

      m_lastTakeProfit =
         0.0;

      m_lastDecision =
         0;

      m_lastConfidence =
         0.0;

      m_initialized =
         false;
   }


   //=================================================================
   // UPDATE
   //=================================================================

   void Update(
      const string symbol,
      const ENUM_TIMEFRAMES timeframe,
      const double price,
      const double stopLoss,
      const double takeProfit,
      const int decision,
      const double confidence
   )
   {
      if(symbol == "")
         return;

      if(timeframe == PERIOD_CURRENT)
         return;

      if(!MathIsValidNumber(price))
         return;

      if(!MathIsValidNumber(stopLoss))
         return;

      if(!MathIsValidNumber(takeProfit))
         return;

      if(!MathIsValidNumber(confidence))
         return;


      m_symbol =
         symbol;

      m_timeframe =
         timeframe;

      m_lastPrice =
         price;

      m_lastStopLoss =
         stopLoss;

      m_lastTakeProfit =
         takeProfit;

      m_lastDecision =
         decision;

      m_lastConfidence =
         confidence;

      m_initialized =
         true;
   }


   //=================================================================
   // IS INITIALIZED
   //=================================================================

   bool IsInitialized() const
   {
      return m_initialized;
   }


   //=================================================================
   // TESTA MITIGAÇÃO DE NÍVEL
   //=================================================================

   bool WasLevelMitigated(
      const double price
   ) const
   {
      if(!m_initialized)
         return false;

      if(price <= 0.0)
         return false;

      if(m_lastStopLoss <= 0.0)
         return false;


      double point =
         GetSymbolPoint();


      //==============================================================
      // Fallback somente para comparação de memória.
      //==============================================================

      if(point <= 0.0)
         point = 0.00001;


      double tolerance =
         point * 10.0;


      return (
         MathAbs(
            price -
            m_lastStopLoss
         ) <= tolerance
      );
   }


   //=================================================================
   // GET SYMBOL
   //=================================================================

   string GetSymbol() const
   {
      return m_symbol;
   }


   //=================================================================
   // GET TIMEFRAME
   //=================================================================

   ENUM_TIMEFRAMES GetTimeframe() const
   {
      return m_timeframe;
   }


   //=================================================================
   // GET LAST PRICE
   //=================================================================

   double GetLastPrice() const
   {
      return m_lastPrice;
   }


   //=================================================================
   // GET LAST STOP LOSS
   //=================================================================

   double GetLastStopLoss() const
   {
      return m_lastStopLoss;
   }


   //=================================================================
   // GET LAST TAKE PROFIT
   //=================================================================

   double GetLastTakeProfit() const
   {
      return m_lastTakeProfit;
   }


   //=================================================================
   // GET LAST DECISION
   //=================================================================

   int GetLastDecision() const
   {
      return m_lastDecision;
   }


   //=================================================================
   // GET LAST CONFIDENCE
   //=================================================================

   double GetLastConfidence() const
   {
      return m_lastConfidence;
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_MARKETMEMORY_MQH
//+------------------------------------------------------------------+