//+------------------------------------------------------------------+
//| IRiskManagementEngine.mqh                                        |
//| Astra Trader AI                                                  |
//+------------------------------------------------------------------+
#ifndef ASTRA_IRISKMANAGEMENTENGINE_MQH
#define ASTRA_IRISKMANAGEMENTENGINE_MQH

#include <AstraTrader\Analysis\AnalysisContext.mqh>

class IRiskManagementEngine
{
public:
   virtual ~IRiskManagementEngine()
   {
   }

   virtual bool IsSystemOperational() = 0;
   virtual bool AnalyzeRisk(AnalysisContext &context) = 0;
   virtual bool IsAllowed() const = 0;
   virtual string GetStatus() const = 0;
   virtual double GetEntry() const = 0;
   virtual double GetStopLoss() const = 0;
   virtual double GetTakeProfit() const = 0;
   virtual double GetRiskReward() const = 0;
   virtual double GetMarginSafetyBuffer() const = 0;
};

#endif // ASTRA_IRISKMANAGEMENTENGINE_MQH