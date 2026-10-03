//+------------------------------------------------------------------+
//| SignalValidator.mqh                                              |
//| Astra Trader AI                                                  |
//+------------------------------------------------------------------+
#ifndef ASTRA_SIGNALVALIDATOR_MQH
#define ASTRA_SIGNALVALIDATOR_MQH

#property strict

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>


class SignalValidator
{
private:

   double m_minConfidence;
   double m_minConsensus;
   double m_minConfluence;

   bool m_requireDecision;
   bool m_requireTechnicalIntelligence;
   bool m_requireMarketData;


   //=================================================================
   // CLAMP
   //=================================================================
   double Clamp(
      const double value,
      const double minimum,
      const double maximum
   ) const
   {
      return MathMax(
         minimum,
         MathMin(
            maximum,
            value
         )
      );
   }


   //=================================================================
   // BLOCK
   //=================================================================
   void Block(
      AnalysisContext &c,
      const ENUM_ASTRA_BLOCK_REASON reason,
      const string description
   ) const
   {
      c.blockReason =
         reason;

      c.blockDescription =
         description;

      c.validationMessage =
         description;

      c.rejectStage =
         "SIGNAL_VALIDATION";

      c.rejectReason =
         description;

      c.pipelineStage =
         "SIGNAL_VALIDATION";
   }


   //=================================================================
   // REJECT
   //=================================================================
   bool Reject(
      AnalysisContext &c,
      const ENUM_ASTRA_BLOCK_REASON reason,
      const string description
   ) const
   {
      c.isValid =
         false;

      c.decisionApproved =
         false;

      c.riskApproved =
         false;

      c.tradeValidationPassed =
         false;

      c.executionAllowed =
         false;

      c.executionConfirmed =
         false;

      c.orderSent =
         false;

      Block(
         c,
         reason,
         description
      );

      PrintFormat(
         "[SignalValidator][Cycle=%I64u] "
         "REJECTED | %s",
         c.cycleId,
         description
      );

      return false;
   }


public:

   //=================================================================
   // CONSTRUCTOR
   //=================================================================
   SignalValidator(
      const double minConfidence =
         ASTRA_MIN_CONFIDENCE_DEFAULT,
      const double minConsensus =
         ASTRA_MIN_CONSENSUS_DEFAULT,
      const double minConfluence =
         ASTRA_MIN_CONFLUENCE
   )
   {
      m_minConfidence =
         Clamp(
            minConfidence,
            0.0,
            1.0
         );

      m_minConsensus =
         Clamp(
            minConsensus,
            0.0,
            100.0
         );

      m_minConfluence =
         Clamp(
            minConfluence,
            0.0,
            100.0
         );

      m_requireDecision =
         true;

      m_requireTechnicalIntelligence =
         false;

      m_requireMarketData =
         true;
   }


   //=================================================================
   // VALIDATE
   //=================================================================
   bool Validate(
      AnalysisContext &c
   )
   {
      c.pipelineStage =
         "SIGNAL_VALIDATION";

      c.rejectStage =
         "";

      c.rejectReason =
         "";

      c.decisionApproved =
         false;

      c.riskApproved =
         false;

      c.tradeValidationPassed =
         false;

      c.executionAllowed =
         false;

      c.executionConfirmed =
         false;

      c.orderSent =
         false;


      //==============================================================
      // CONTEXT
      //==============================================================

      if(!c.Validate())
      {
         return Reject(
            c,
            ASTRA_BLOCK_INVALID_DATA,
            c.validationMessage == ""
            ? "AnalysisContext inválido."
            : c.validationMessage
         );
      }


      if(!c.contextValid)
      {
         return Reject(
            c,
            ASTRA_BLOCK_INVALID_DATA,
            "AnalysisContext não está válido."
         );
      }


      //==============================================================
      // MARKET DATA
      //==============================================================

      if(m_requireMarketData)
      {
         if(c.symbol == "")
         {
            return Reject(
               c,
               ASTRA_BLOCK_INVALID_DATA,
               "Symbol inválido."
            );
         }

         if(c.primaryTF == PERIOD_CURRENT)
         {
            return Reject(
               c,
               ASTRA_BLOCK_INVALID_DATA,
               "Timeframe inválido."
            );
         }

         if(c.point <= 0.0)
         {
            return Reject(
               c,
               ASTRA_BLOCK_INVALID_DATA,
               "Point inválido."
            );
         }

         if(
            c.bid <= 0.0 &&
            c.ask <= 0.0 &&
            c.price <= 0.0 &&
            c.close <= 0.0
         )
         {
            return Reject(
               c,
               ASTRA_BLOCK_INVALID_DATA,
               "Market data sem preço válido."
            );
         }

         if(
            c.bid > 0.0 &&
            c.ask > 0.0 &&
            c.ask < c.bid
         )
         {
            return Reject(
               c,
               ASTRA_BLOCK_INVALID_DATA,
               "Bid/Ask incoerentes."
            );
         }
      }


      //==============================================================
      // DECISION
      //==============================================================

      if(
         m_requireDecision &&
         c.decision != DECISION_BUY &&
         c.decision != DECISION_SELL
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_NO_DECISION,
            "Nenhuma decisão BUY/SELL válida."
         );
      }


      //==============================================================
      // DIRECTION / CONSENSUS CONSISTENCY
      //==============================================================

      if(
         !MathIsValidNumber(c.consensusScore) ||
         MathAbs(c.consensusScore) > 100.0
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_INVALID_DATA,
            "Consensus inválido."
         );
      }

      const double directionalConsensus =
         (
            c.decision == DECISION_BUY
            ? c.consensusScore
            : -c.consensusScore
         );

      // Direction is a hard semantic contract: the candidate direction
      // must point to the same side as Consensus.
      if(directionalConsensus <= 0.0)
      {
         return Reject(
            c,
            ASTRA_BLOCK_NO_DECISION,
            StringFormat(
               "Direção incoerente com Consensus %.2f",
               directionalConsensus
            )
         );
      }

      if(directionalConsensus < m_minConsensus)
      {
         return Reject(
            c,
            ASTRA_BLOCK_NO_DECISION,
            StringFormat(
               "Consensus direcional insuficiente %.2f < %.2f",
               directionalConsensus,
               m_minConsensus
            )
         );
      }


      //==============================================================
      // CONFIDENCE
      //==============================================================

      double confidence =
         c.finalConfidence;

      if(!MathIsValidNumber(confidence))
      {
         return Reject(
            c,
            ASTRA_BLOCK_INVALID_DATA,
            "Confiança inválida."
         );
      }

      if(confidence > 1.0)
      {
         if(confidence > 100.0)
         {
            return Reject(
               c,
               ASTRA_BLOCK_INVALID_DATA,
               "Confiança fora da escala."
            );
         }

         confidence /= 100.0;

         c.finalConfidence =
            confidence;
      }


      if(confidence < m_minConfidence)
      {
         return Reject(
            c,
            ASTRA_BLOCK_NO_DECISION,
            StringFormat(
               "Confiança insuficiente %.3f < %.3f",
               confidence,
               m_minConfidence
            )
         );
      }


      //==============================================================
      // CONFLUENCE
      //==============================================================

      if(
         !MathIsValidNumber(
            c.confluenceScore
         ) ||
         MathAbs(c.confluenceScore) > 100.0
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_INVALID_DATA,
            "Confluence inválida."
         );
      }


      const double directionalConfluence =
         (
            c.decision == DECISION_BUY
            ? c.confluenceScore
            : -c.confluenceScore
         );


      if(
         directionalConfluence <
         m_minConfluence
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_NO_DECISION,
            StringFormat(
               "Confluence direcional insuficiente %.2f < %.2f",
               directionalConfluence,
               m_minConfluence
            )
         );
      }


      //==============================================================
      // PROBABILITIES
      //==============================================================

      if(
         !MathIsValidNumber(c.probabilityBuy) ||
         !MathIsValidNumber(c.probabilitySell)
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_INVALID_DATA,
            "Probabilidades inválidas."
         );
      }


      if(
         c.probabilityBuy < 0.0 ||
         c.probabilityBuy > 1.0 ||
         c.probabilitySell < 0.0 ||
         c.probabilitySell > 1.0
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_INVALID_DATA,
            "Probabilidades fora da escala."
         );
      }


      if(
         MathAbs(
            (
               c.probabilityBuy +
               c.probabilitySell
            ) - 1.0
         ) > 0.000001
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_INVALID_DATA,
            "Probabilidades incoerentes."
         );
      }


      //==============================================================
      // DIRECTION / PROBABILITY
      //==============================================================

      if(
         c.decision == DECISION_BUY &&
         c.probabilityBuy < c.probabilitySell
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_NO_DECISION,
            "BUY rejeitado: probabilitySell superior."
         );
      }


      if(
         c.decision == DECISION_SELL &&
         c.probabilitySell < c.probabilityBuy
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_NO_DECISION,
            "SELL rejeitado: probabilityBuy superior."
         );
      }


      //==============================================================
      // CONFLUENCE DIRECTION
      //==============================================================

      if(
         c.decision == DECISION_BUY &&
         c.bearishConfluence >
         c.bullishConfluence
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_NO_DECISION,
            "BUY rejeitado: confluence bearish superior."
         );
      }


      if(
         c.decision == DECISION_SELL &&
         c.bullishConfluence >
         c.bearishConfluence
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_NO_DECISION,
            "SELL rejeitado: confluence bullish superior."
         );
      }


      //==============================================================
      // GRADE
      //
      // Não permitimos que NO_TRADE chegue ao Risk.
      //==============================================================

      if(
         c.opportunityGrade ==
         GRADE_NO_TRADE
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_NO_DECISION,
            "OpportunityGrade=NO_TRADE."
         );
      }


      //==============================================================
      // TECHNICAL INTELLIGENCE
      //==============================================================

      if(
         m_requireTechnicalIntelligence &&
         (
            !MathIsValidNumber(c.technicalIntelligenceScore) ||
            MathAbs(c.technicalIntelligenceScore) <= 0.0
         )
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_NO_DECISION,
            "Inteligência técnica sem confirmação."
         );
      }


      //==============================================================
      // APPROVED
      //
      // Aprovação estratégica somente.
      // Risk ainda não aprovou.
      // TradeValidator ainda não aprovou.
      //==============================================================

      c.isValid =
         true;

      c.decisionApproved =
         true;

      c.riskApproved =
         false;

      c.tradeValidationPassed =
         false;

      c.executionAllowed =
         false;

      c.executionConfirmed =
         false;

      c.orderSent =
         false;

      c.blockReason =
         ASTRA_BLOCK_NONE;

      c.blockDescription =
         "";

      c.validationMessage =
         "Sinal estratégico validado; aguardando RiskManagement.";

      c.pipelineStage =
         "RISK_MANAGEMENT_PENDING";


      PrintFormat(
         "[SignalValidator][Cycle=%I64u] "
         "APPROVED | Decision=%s | "
         "Conf=%.3f | Consensus=%.2f | "
         "Confluence=%.2f | Grade=%s",
         c.cycleId,
         c.DecisionToString(),
         c.finalConfidence,
         c.consensusScore,
         c.confluenceScore,
         c.GradeToString()
      );


      return true;
   }


   //=================================================================
   // CONFIG
   //=================================================================

   void SetMinimumConfidence(
      const double value
   )
   {
      m_minConfidence =
         Clamp(
            value,
            0.0,
            1.0
         );
   }


   void SetMinimumConsensus(
      const double value
   )
   {
      m_minConsensus =
         Clamp(
            value,
            0.0,
            100.0
         );
   }


   void SetMinimumConfluence(
      const double value
   )
   {
      m_minConfluence =
         Clamp(
            value,
            0.0,
            100.0
         );
   }


   void SetRequireTechnicalIntelligence(
      const bool value
   )
   {
      m_requireTechnicalIntelligence =
         value;
   }


   void SetRequireMarketData(
      const bool value
   )
   {
      m_requireMarketData =
         value;
   }


   //=================================================================
   // GETTERS
   //=================================================================

   double GetMinimumConfidence() const
   {
      return m_minConfidence;
   }


   double GetMinimumConsensus() const
   {
      return m_minConsensus;
   }


   double GetMinimumConfluence() const
   {
      return m_minConfluence;
   }


   bool IsTechnicalIntelligenceRequired() const
   {
      return m_requireTechnicalIntelligence;
   }


   bool IsMarketDataRequired() const
   {
      return m_requireMarketData;
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_SIGNALVALIDATOR_MQH
