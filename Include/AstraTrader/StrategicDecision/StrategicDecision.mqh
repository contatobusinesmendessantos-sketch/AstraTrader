//+------------------------------------------------------------------+
//| StrategicDecision.mqh - legacy compatibility facade              |
//| Operational decision source of truth: MarketDecisionEngine.       |
//+------------------------------------------------------------------+
#ifndef ASTRA_STRATEGICDECISION_MQH
#define ASTRA_STRATEGICDECISION_MQH
#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>
#include <AstraTrader\Decision\MarketDecisionEngine.mqh>
class StrategicDecision
{
private:
   MarketDecisionEngine m_canonicalDecisionEngine;
public:
   StrategicDecision() {}
   void Reset(AnalysisContext &ctx) { m_canonicalDecisionEngine.Reset(); }
   bool Analyze(AnalysisContext &ctx)
   {
      PrintFormat("[StrategicDecision] LEGACY_FACADE | Delegating to MarketDecisionEngine | Cycle=%I64u", ctx.cycleId);
      return m_canonicalDecisionEngine.Analyze(ctx);
   }
};
#endif
