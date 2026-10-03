#ifndef ASTRA_BUILDIDENTITY_MQH
#define ASTRA_BUILDIDENTITY_MQH

#property strict

#include <AstraTrader\Core\Config.mqh>

class BuildIdentity
{
private:
   string m_protectedFiles[];

public:
   string schemaVersion;
   string sourceHash;
   string ex5Hash;
   string buildVersion;
   string buildTimestamp;
   string eaVersion;
   string identityStatus;

   BuildIdentity()
   {
      schemaVersion = "1.0";
      sourceHash = "";
      ex5Hash = "";
      buildVersion = "ASTRA_PHASE_1";
      buildTimestamp = TimeToString((datetime)__DATETIME__, TIME_DATE | TIME_SECONDS);
      eaVersion = ASTRA_VERSION;
      identityStatus = "NOT_AVAILABLE_IN_RUNTIME";

      ArrayResize(m_protectedFiles, 9);
      m_protectedFiles[0] = "AnalysisContext.mqh";
      m_protectedFiles[1] = "AstraPipeline.mqh";
      m_protectedFiles[2] = "MarketDecisionEngine.mqh";
      m_protectedFiles[3] = "SignalValidator.mqh";
      m_protectedFiles[4] = "RiskManagementEngine.mqh";
      m_protectedFiles[5] = "ExposureGate.mqh";
      m_protectedFiles[6] = "TradeValidator.mqh";
      m_protectedFiles[7] = "TradeExecutionEngine.mqh";
      m_protectedFiles[8] = "PositionManager.mqh";
   }

   int ProtectedFileCount() const
   {
      return ArraySize(m_protectedFiles);
   }

   string ProtectedFileAt(const int index) const
   {
      if(index < 0 || index >= ArraySize(m_protectedFiles))
         return "";

      return m_protectedFiles[index];
   }
};

#endif