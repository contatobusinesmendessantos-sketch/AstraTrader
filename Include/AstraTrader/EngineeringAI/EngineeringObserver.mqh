#ifndef ASTRA_ENGINEERINGOBSERVER_MQH
#define ASTRA_ENGINEERINGOBSERVER_MQH

#property strict

#include <AstraTrader\EngineeringAI\EngineeringContext.mqh>
#include <AstraTrader\EngineeringAI\DiagnosticEngine.mqh>
#include <AstraTrader\EngineeringAI\RepairPacket.mqh>
#include <AstraTrader\EngineeringAI\BuildIdentity.mqh>

class EngineeringObserver
{
private:
   DiagnosticEngine m_diagnosticEngine;
   BuildIdentity m_buildIdentity;
   RepairPacket m_lastPacket;

public:
   EngineeringObserver() {}

   void Process(const AnalysisContext &source)
   {
      EngineeringContext context;
      DiagnosticResult diagnostic;

      context.Capture(source);
      m_diagnosticEngine.Diagnose(context, diagnostic);
      m_lastPacket.Build(context, diagnostic, m_buildIdentity);

      PrintFormat(
         "[ASTRA][ENGINEERING] Cycle=%I64u | Build=%s | Identity=%s | Fingerprint=%s | Symbol=%s | TF=%s | Diagnostic=%s | Stage=%s | Decision=%s | Confidence=%.3f | Consensus=%.2f | Confluence=%.2f | AI_Buy=%.4f | AI_Sell=%.4f | Risk=%.3f | RR=%.3f | BlockReason=%s | RejectReason=%s",
         m_lastPacket.cycleId,
         m_lastPacket.buildVersion,
         m_lastPacket.identityStatus,
         m_lastPacket.failureFingerprint,
         m_lastPacket.symbol,
         EnumToString(m_lastPacket.timeframe),
         m_lastPacket.diagnosticCode,
         m_lastPacket.stage,
         m_lastPacket.decision,
         m_lastPacket.confidence,
         m_lastPacket.consensus,
         m_lastPacket.confluence,
         m_lastPacket.aiBuy,
         m_lastPacket.aiSell,
         m_lastPacket.riskPercent,
         m_lastPacket.riskReward,
         m_lastPacket.rejectBlockReason,
         m_lastPacket.rejectReason
      );
   }

   RepairPacket GetLastPacket() const
   {
      return m_lastPacket;
   }
};

#endif