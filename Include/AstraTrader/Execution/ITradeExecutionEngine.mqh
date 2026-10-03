//+------------------------------------------------------------------+
//| ITradeExecutionEngine.mqh                                        |
//| Astra Trader AI                                                  |
//+------------------------------------------------------------------+
#ifndef ASTRA_ITRADEEXECUTIONENGINE_MQH
#define ASTRA_ITRADEEXECUTIONENGINE_MQH

#property strict

#include <AstraTrader\Analysis\AnalysisContext.mqh>


class ITradeExecutionEngine
{
public:

   virtual ~ITradeExecutionEngine()
   {
   }


   //===============================================================
   // ABRIR
   //===============================================================
   virtual bool OpenPosition(
      AnalysisContext &context
   ) = 0;


   //===============================================================
   // FECHAR
   //===============================================================
   virtual bool ClosePosition(
      const ulong ticket
   ) = 0;


   //===============================================================
   // MODIFICAR
   //===============================================================
   virtual bool ModifyPosition(
      const ulong ticket,
      const double stopLoss,
      const double takeProfit
   ) = 0;


   //===============================================================
   // OPERACIONAL
   //===============================================================
   virtual bool IsSystemOperational() = 0;


   //===============================================================
   // STATUS
   //===============================================================
   virtual string GetStatus() = 0;


   //===============================================================
   // RETCODE
   //===============================================================
   virtual long GetLastRetcode() = 0;


   //===============================================================
   // RETCODE DESCRIPTION
   //===============================================================
   virtual string GetLastRetcodeDescription() = 0;
};


#endif // ASTRA_ITRADEEXECUTIONENGINE_MQH
