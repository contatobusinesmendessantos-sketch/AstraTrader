//+------------------------------------------------------------------+
//| Logger.mqh                                                       |
//| Astra Trader AI                                                  |
//|                                                                  |
//| Sistema de logging estruturado e auditoria do pipeline.          |
//|                                                                  |
//| Responsabilidades:                                               |
//|  - Registrar eventos no Journal/Experts                         |
//|  - Registrar decisões do AnalysisContext                         |
//|  - Registrar operações executadas                                |
//|                                                                  |
//| IMPORTANTE:                                                      |
//| Logger NÃO toma decisões de trading.                             |
//| Logger NÃO altera AnalysisContext.                               |
//| Logger NÃO executa ordens.                                      |
//+------------------------------------------------------------------+
#ifndef ASTRA_LOGGER_MQH
#define ASTRA_LOGGER_MQH

#include <AstraTrader\Analysis\AnalysisContext.mqh>

//==================================================================
// NÍVEL DO LOG
//==================================================================
enum ENUM_LOG_LEVEL
  {
   LOG_DEBUG = 0,
   LOG_INFO  = 1,
   LOG_WARN  = 2,
   LOG_ERROR = 3
  };

//==================================================================
// LOGGER
//==================================================================
class Logger
  {
private:

   //===============================================================
   // CONVERTE NÍVEL PARA TEXTO
   //===============================================================
   static string LevelToString(const ENUM_LOG_LEVEL level)
     {
      switch(level)
        {
         case LOG_DEBUG:
            return "DEBUG";

         case LOG_INFO:
            return "INFO";

         case LOG_WARN:
            return "WARN";

         case LOG_ERROR:
            return "ERROR";
        }

      return "UNKNOWN";
     }

public:

   //===============================================================
   // LOG GENÉRICO
   //===============================================================
   static void Log(const ENUM_LOG_LEVEL level,
                   const string message)
     {
      string levelText = LevelToString(level);

      PrintFormat(
         "[ASTRA][%s] %s",
         levelText,
         message
      );
     }

   //===============================================================
   // DEBUG
   //===============================================================
   static void Debug(const string message)
     {
      Log(LOG_DEBUG,message);
     }

   //===============================================================
   // INFO
   //===============================================================
   static void Info(const string message)
     {
      Log(LOG_INFO,message);
     }

   //===============================================================
   // WARNING
   //===============================================================
   static void Warning(const string message)
     {
      Log(LOG_WARN,message);
     }

   //===============================================================
   // ERROR
   //===============================================================
   static void Error(const string message)
     {
      Log(LOG_ERROR,message);
     }

   //===============================================================
   // DECISION AUDIT
   //===============================================================
   static void LogDecision(const AnalysisContext &ctx)
     {
      PrintFormat(
         "[ASTRA][DECISION] "
         "Cycle=%I64u "
         "Symbol=%s "
         "TF=%s "
         "Bias=%s "
         "Regime=%s "
         "Wyckoff=%s "
         "Elliott=%s "
         "AI=%.3f "
         "Confluence=%.3f "
         "Decision=%s "
         "Grade=%s "
         "Confidence=%.3f "
         "Risk=%s "
         "Lot=%.2f "
         "Approved=%s",
         
         ctx.cycleId,
         ctx.symbol,
         EnumToString(ctx.primaryTF),
         EnumToString(ctx.structuralBias),
         ctx.RegimeToString(),
         EnumToString(ctx.wyckoffPhase),
         EnumToString(ctx.elliottWave),
         ctx.predictionScore,
         ctx.confluenceScore,
         ctx.DecisionToString(),
         ctx.GradeToString(),
         ctx.finalConfidence,
         ctx.RiskLevelToString(),
         ctx.lotSize,
         ctx.decisionApproved ? "true" : "false"
      );

      //--- explicação detalhada da decisão
      if(ctx.decisionExplanation != "")
        {
         PrintFormat(
            "[ASTRA][DECISION_EXPLANATION] %s",
            ctx.decisionExplanation
         );
        }

      //--- motivo da decisão
      if(ctx.decisionReason != "")
        {
         PrintFormat(
            "[ASTRA][DECISION_REASON] %s",
            ctx.decisionReason
         );
        }

      //--- caso tenha ocorrido bloqueio
      if(ctx.blockReason != ASTRA_BLOCK_NONE)
        {
         PrintFormat(
            "[ASTRA][DECISION_BLOCK] "
            "Reason=%d | Description=%s",
            ctx.blockReason,
            ctx.blockDescription
         );
        }
     }

   //===============================================================
   // TRADE AUDIT
   //===============================================================
   static void LogTrade(const string action,
                        const ulong ticket,
                        const double lots,
                        const double price)
     {
      PrintFormat(
         "[ASTRA][TRADE] "
         "Action=%s "
         "Ticket=%I64u "
         "Lots=%.2f "
         "Price=%s",
         action,
         ticket,
         lots,
         DoubleToString(price,_Digits)
      );
     }

   //===============================================================
   // PIPELINE STATUS
   //===============================================================
   static void LogPipeline(const AnalysisContext &ctx)
     {
      PrintFormat(
         "[ASTRA][PIPELINE] "
         "Cycle=%I64u "
         "Symbol=%s "
         "TF=%s "
         "Data=%s "
         "ContextValid=%s "
         "AnalysisComplete=%s",
         
         ctx.cycleId,
         ctx.symbol,
         EnumToString(ctx.primaryTF),
         EnumToString(ctx.dataQuality),
         ctx.contextValid ? "true" : "false",
         ctx.analysisComplete ? "true" : "false"
      );
     }

   //===============================================================
   // VALIDATION
   //===============================================================
   static void LogValidation(const AnalysisContext &ctx)
     {
      PrintFormat(
         "[ASTRA][VALIDATION] "
         "Symbol=%s "
         "Decision=%s "
         "ExecutionAllowed=%s "
         "SpreadValid=%s "
         "SessionValid=%s "
         "MarketOpen=%s "
         "TradingAllowed=%s "
         "MarginValid=%s",
         
         ctx.symbol,
         ctx.DecisionToString(),
         ctx.executionAllowed ? "true" : "false",
         ctx.spreadValid ? "true" : "false",
         ctx.sessionValid ? "true" : "false",
         ctx.marketOpen ? "true" : "false",
         ctx.tradingAllowed ? "true" : "false",
         ctx.marginValid ? "true" : "false"
      );

      if(ctx.executionRejection != "")
        {
         PrintFormat(
            "[ASTRA][VALIDATION_REJECTION] %s",
            ctx.executionRejection
         );
        }
     }
  };

//+------------------------------------------------------------------+
#endif // ASTRA_LOGGER_MQH
//+------------------------------------------------------------------+
