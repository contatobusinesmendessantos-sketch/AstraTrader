#ifndef ASTRA_REPAIRPACKET_MQH
#define ASTRA_REPAIRPACKET_MQH

#property strict

#include <AstraTrader\EngineeringAI\EngineeringContext.mqh>
#include <AstraTrader\EngineeringAI\DiagnosticEngine.mqh>
#include <AstraTrader\EngineeringAI\BuildIdentity.mqh>

class RepairPacket
{
public:
   string schemaVersion;
   ulong cycleId;
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   string sourceHash;
   string ex5Hash;
   string diagnosticCode;
   string severity;
   string stage;
   string description;
   string decision;
   double confidence;
   double consensus;
   double confluence;
   double aiBuy;
   double aiSell;
   bool aiDeepAvailable;
   double riskPercent;
   double lotSize;
   double entry;
   double stop;
   double take;
   double riskReward;
   string rejectStage;
   string rejectReason;
   string rejectBlockReason;
   string buildVersion;
   string buildTimestamp;
   string eaVersion;
   string identityStatus;
   string failureFingerprint;
   string protectedFiles[];

   RepairPacket()
   {
      schemaVersion = "1.0";
      sourceHash = "";
      ex5Hash = "";
      buildVersion = "";
      buildTimestamp = "";
      eaVersion = "";
      identityStatus = "";
      failureFingerprint = "";
   }

   void Build(
      const EngineeringContext &context,
      const DiagnosticResult &diagnostic,
      const BuildIdentity &identity
   )
   {
      schemaVersion = identity.schemaVersion;
      sourceHash = identity.sourceHash;
      ex5Hash = identity.ex5Hash;
      buildVersion = identity.buildVersion;
      buildTimestamp = identity.buildTimestamp;
      eaVersion = identity.eaVersion;
      identityStatus = identity.identityStatus;
      cycleId = context.cycleId;
      symbol = context.symbol;
      timeframe = context.timeframe;
      diagnosticCode = diagnostic.diagnosticCode;
      severity = diagnostic.severity;
      stage = diagnostic.stage;
      description = diagnostic.description;
      decision = context.DecisionToString();
      confidence = context.finalConfidence;
      consensus = context.consensusScore;
      confluence = context.confluenceScore;
      aiBuy = context.aiProbabilityBuy;
      aiSell = context.aiProbabilitySell;
      aiDeepAvailable = context.aiDeepAvailable;
      riskPercent = context.riskPercent;
      lotSize = context.lotSize;
      entry = context.entryPrice;
      stop = context.stopLoss;
      take = context.takeProfit;
      riskReward = context.riskReward;
      rejectStage = context.rejectStage;
      rejectReason = context.rejectReason;
      rejectBlockReason = context.rejectBlockReason;
      failureFingerprint = BuildFailureFingerprint(context, diagnostic);

      ArrayResize(protectedFiles, identity.ProtectedFileCount());
      for(int index = 0; index < identity.ProtectedFileCount(); index++)
         protectedFiles[index] = identity.ProtectedFileAt(index);
   }

private:
   string BuildFailureFingerprint(
      const EngineeringContext &context,
      const DiagnosticResult &diagnostic
   ) const
   {
      return StringFormat(
         "D=%s|S=%s|RS=%s|RR=%s|BR=%s|DEC=%s|DC=%s",
         diagnostic.diagnosticCode,
         diagnostic.stage,
         context.rejectStage,
         context.rejectReason,
         context.rejectBlockReason,
         context.DecisionToString(),
         context.directionConflict ? "true" : "false"
      );
   }
};

#endif