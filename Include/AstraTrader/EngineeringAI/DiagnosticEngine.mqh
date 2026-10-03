#ifndef ASTRA_DIAGNOSTICENGINE_MQH
#define ASTRA_DIAGNOSTICENGINE_MQH

#property strict

#include <AstraTrader\EngineeringAI\EngineeringContext.mqh>

class DiagnosticResult
{
public:
   string diagnosticCode;
   string severity;
   string stage;
   string description;

   void Reset()
   {
      diagnosticCode = "ASTRA_DIAG_NONE";
      severity = "INFO";
      stage = "PIPELINE";
      description = "no anomaly detected";
   }
};

class DiagnosticEngine
{
public:
   DiagnosticEngine() {}

   void Diagnose(const EngineeringContext &context, DiagnosticResult &result) const
   {
      result.Reset();

      if(context.executionConfirmed && !context.executionAllowed)
      {
         SetResult(result, "ASTRA_DIAG_CONTRACT_INCONSISTENCY", "CRITICAL", "EXECUTION", "execution confirmed without permission");
         return;
      }

      if(context.executionConfirmed && !context.tradeValidationPassed)
      {
         SetResult(result, "ASTRA_DIAG_CONTRACT_INCONSISTENCY", "CRITICAL", "EXECUTION", "execution confirmed without trade validation");
         return;
      }

      const bool explicitExecutionFailure =
         context.rejectStage == "EXECUTION" ||
         context.rejectStage == "TRADE_EXECUTION";

      const bool pendingExecutionFailure =
         context.rejectStage == "EXECUTION_PENDING" &&
         context.rejectReason != "" &&
         !context.executionConfirmed &&
         !context.executionAllowed;

      if(explicitExecutionFailure || pendingExecutionFailure)
      {
         SetResult(result, "ASTRA_DIAG_EXECUTION_FAILED", "ERROR", "EXECUTION", "trade execution failed");
         return;
      }

      if(context.rejectStage == "SIGNAL_VALIDATION")
      {
         SetResult(result, "ASTRA_DIAG_SIGNAL_REJECTED", "WARNING", context.rejectStage, "signal validation rejected the decision");
         return;
      }

      if(context.rejectStage == "RISK_MANAGEMENT" || context.rejectStage == "RISK")
      {
         SetResult(result, "ASTRA_DIAG_RISK_REJECTED", "WARNING", context.rejectStage, "risk management rejected the decision");
         return;
      }

      if(context.rejectStage == "AGGREGATE_EXPOSURE")
      {
         SetResult(result, "ASTRA_DIAG_EXPOSURE_BLOCKED", "WARNING", context.rejectStage, "aggregate exposure gate blocked execution");
         return;
      }

      if(context.rejectStage == "POSITION_GATE_INITIAL" ||
         context.rejectStage == "POSITION_GATE_FINAL" ||
         context.rejectStage == "EXECUTION_POSITION_GATE")
      {
         SetResult(result, "ASTRA_DIAG_POSITION_GATE_BLOCKED", "WARNING", context.rejectStage, "position gate blocked execution");
         return;
      }

      if(context.rejectStage == "TRADE_VALIDATION")
      {
         SetResult(result, "ASTRA_DIAG_TRADE_VALIDATION_FAILED", "ERROR", context.rejectStage, "trade validation failed");
         return;
      }

      if(context.rejectStage != "" || context.rejectReason != "")
      {
         SetResult(result, "ASTRA_DIAG_CONTRACT_INCONSISTENCY", "ERROR", context.rejectStage, "pipeline rejected without a recognized diagnostic stage");
         return;
      }

      if(context.directionConflict)
      {
         SetResult(result, "ASTRA_DIAG_DIRECTION_CONFLICT", "WARNING", "MARKET_DECISION", "directional evidence is conflicting");
         return;
      }

      if(context.decision == DECISION_NONE)
      {
         SetResult(result, "ASTRA_DIAG_NO_DECISION", "INFO", "MARKET_DECISION", "pipeline completed without a market decision");
         return;
      }
   }

private:
   void SetResult(
      DiagnosticResult &result,
      const string code,
      const string level,
      const string stageName,
      const string text
   ) const
   {
      result.diagnosticCode = code;
      result.severity = level;
      result.stage = stageName;
      result.description = text;
   }
};

#endif