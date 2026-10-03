//+------------------------------------------------------------------+
//| ConfluenceEngine.mqh - compatibility facade                      |
//| Canonical confluence is calculated by MarketDecisionEngine.       |
//+------------------------------------------------------------------+
#ifndef ASTRA_CONFLUENCEENGINE_MQH
#define ASTRA_CONFLUENCEENGINE_MQH
#include <AstraTrader\Analysis\AnalysisContext.mqh>
class ConfluenceEngine
{
public:
   ConfluenceEngine() {}
   void Reset(AnalysisContext &ctx) { }
   bool Analyze(AnalysisContext &ctx) { return ctx.contextValid && ctx.evidenceQuality >= 0.35; }
   double GetConfluenceScore(const AnalysisContext &ctx) const { return ctx.confluenceScore; }
   double GetBuyScore(const AnalysisContext &ctx) const { return ctx.buyScore; }
   double GetSellScore(const AnalysisContext &ctx) const { return ctx.sellScore; }
};
#endif
