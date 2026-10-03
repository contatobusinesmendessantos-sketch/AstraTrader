#ifndef ASTRA_ENGINEERINGCONTEXT_MQH
#define ASTRA_ENGINEERINGCONTEXT_MQH

#property strict

#include <AstraTrader\Analysis\AnalysisContext.mqh>

class EngineeringContext
{
public:
   ulong cycleId;
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   string pipelineStage;

   ENUM_DECISION decision;
   double finalConfidence;
   double consensusScore;
   double confluenceScore;
   bool directionConflict;

   bool executionAllowed;
   bool executionConfirmed;
   bool tradeValidationPassed;
   string rejectStage;
   string rejectReason;
   string rejectBlockReason;

   double aiProbabilityBuy;
   double aiProbabilitySell;
   bool aiDeepAvailable;
   double aiConsensusScore;

   double riskPercent;
   double lotSize;
   double entryPrice;
   double stopLoss;
   double takeProfit;
   double riskReward;
   ulong openedTicket;
   double executionPrice;

   EngineeringContext()
   {
      Reset();
   }

   void Reset()
   {
      cycleId = 0;
      symbol = "";
      timeframe = PERIOD_CURRENT;
      pipelineStage = "";
      decision = DECISION_NONE;
      finalConfidence = 0.0;
      consensusScore = 0.0;
      confluenceScore = 0.0;
      directionConflict = false;
      executionAllowed = false;
      executionConfirmed = false;
      tradeValidationPassed = false;
      rejectStage = "";
      rejectReason = "";
      rejectBlockReason = "";
      aiProbabilityBuy = 0.0;
      aiProbabilitySell = 0.0;
      aiDeepAvailable = false;
      aiConsensusScore = 0.0;
      riskPercent = 0.0;
      lotSize = 0.0;
      entryPrice = 0.0;
      stopLoss = 0.0;
      takeProfit = 0.0;
      riskReward = 0.0;
      openedTicket = 0;
      executionPrice = 0.0;
   }

   void Capture(const AnalysisContext &source)
   {
      cycleId = source.cycleId;
      symbol = source.symbol;
      timeframe = source.primaryTF;
      pipelineStage = source.pipelineStage;
      decision = source.decision;
      finalConfidence = source.finalConfidence;
      consensusScore = source.consensusScore;
      confluenceScore = source.confluenceScore;
      directionConflict = source.directionConflict;
      executionAllowed = source.executionAllowed;
      executionConfirmed = source.executionConfirmed;
      tradeValidationPassed = source.tradeValidationPassed;
      rejectStage = source.rejectStage;
      rejectReason = source.rejectReason;
      rejectBlockReason = BlockReasonToString(source.blockReason);
      aiProbabilityBuy = source.aiProbabilityBuy;
      aiProbabilitySell = source.aiProbabilitySell;
      aiDeepAvailable = source.aiDeepAvailable;
      aiConsensusScore = source.aiConsensusScore;
      riskPercent = source.riskPercent;
      lotSize = source.lotSize;
      entryPrice = source.entryPrice;
      stopLoss = source.stopLoss;
      takeProfit = source.takeProfit;
      riskReward = source.riskReward;
      openedTicket = source.openedTicket;
      executionPrice = source.executionPrice;
   }

   string BlockReasonToString(const ENUM_ASTRA_BLOCK_REASON reason) const
   {
      switch(reason)
      {
         case ASTRA_BLOCK_NONE:                   return "ASTRA_BLOCK_NONE";
         case ASTRA_BLOCK_NO_DECISION:            return "ASTRA_BLOCK_NO_DECISION";
         case ASTRA_BLOCK_INVALID_DATA:           return "ASTRA_BLOCK_INVALID_DATA";
         case ASTRA_BLOCK_INVALID_RISK:           return "ASTRA_BLOCK_INVALID_RISK";
         case ASTRA_BLOCK_MARGIN_INSUFFICIENT:    return "ASTRA_BLOCK_MARGIN_INSUFFICIENT";
         case ASTRA_BLOCK_SPREAD:                 return "ASTRA_BLOCK_SPREAD";
         case ASTRA_BLOCK_SESSION:                return "ASTRA_BLOCK_SESSION";
         case ASTRA_BLOCK_MARKET_CLOSED:          return "ASTRA_BLOCK_MARKET_CLOSED";
         case ASTRA_BLOCK_SYMBOL:                 return "ASTRA_BLOCK_SYMBOL";
         case ASTRA_BLOCK_TRADING_DISABLED:       return "ASTRA_BLOCK_TRADING_DISABLED";
         case ASTRA_BLOCK_POSITION_ALREADY_OPEN:  return "ASTRA_BLOCK_POSITION_ALREADY_OPEN";
         case ASTRA_BLOCK_COOLDOWN_ACTIVE:        return "ASTRA_BLOCK_COOLDOWN_ACTIVE";
         case ASTRA_BLOCK_NEWS:                   return "ASTRA_BLOCK_NEWS";
         case ASTRA_BLOCK_EXPOSURE_LIMIT:         return "ASTRA_BLOCK_EXPOSURE_LIMIT";
         case ASTRA_BLOCK_UNPROTECTED_POSITION:   return "ASTRA_BLOCK_UNPROTECTED_POSITION";
      }

      return "ASTRA_BLOCK_UNKNOWN";
   }

   string DecisionToString() const
   {
      if(decision == DECISION_BUY)
         return "BUY";

      if(decision == DECISION_SELL)
         return "SELL";

      return "NONE";
   }
};

#endif