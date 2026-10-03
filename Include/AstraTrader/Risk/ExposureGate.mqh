//+------------------------------------------------------------------+
//| ExposureGate.mqh                                                 |
//| Astra Trader AI                                                  |
//|                                                                  |
//| Account-wide aggregate risk guard for Astra positions.           |
//|                                                                  |
//| This is a safety layer after individual RiskManagement because   |
//| the proposed trade risk is available there. Full Global Bank    |
//| (daily target/loss, drawdown, loss streak, capital protection,   |
//| news/session) remains a later phase after fresh backtest.         |
//+------------------------------------------------------------------+
#ifndef ASTRA_EXPOSUREGATE_MQH
#define ASTRA_EXPOSUREGATE_MQH
#property strict

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>

class ExposureGate
{
private:
   double m_maxAggregateRiskPercent;

   double CalculatePositionRiskMoney(
      const string symbol,
      const ENUM_POSITION_TYPE type,
      const double volume,
      const double openPrice,
      const double stopLoss,
      bool &protectedPosition
   ) const
   {
      protectedPosition = false;

      if(symbol == "" || volume <= 0.0 || openPrice <= 0.0 || stopLoss <= 0.0)
         return -1.0;

      if(type == POSITION_TYPE_BUY)
      {
         if(stopLoss >= openPrice)
         {
            // Stop is already at/above entry: no downside risk remains.
            protectedPosition = true;
            return 0.0;
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         if(stopLoss <= openPrice)
         {
            protectedPosition = true;
            return 0.0;
         }
      }
      else
      {
         return -1.0;
      }

      double profitToStop = 0.0;
      const ENUM_ORDER_TYPE orderType =
         (type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);

      ResetLastError();
      if(!OrderCalcProfit(
            orderType,
            symbol,
            volume,
            openPrice,
            stopLoss,
            profitToStop
         ))
      {
         return -1.0;
      }

      protectedPosition = true;
      return MathMax(0.0, -profitToStop);
   }

public:
   ExposureGate()
   {
      m_maxAggregateRiskPercent = ASTRA_MAX_AGGREGATE_RISK_PERCENT_DEFAULT;
   }

   void Reset()
   {
      m_maxAggregateRiskPercent = ASTRA_MAX_AGGREGATE_RISK_PERCENT_DEFAULT;
   }

   void SetMaxAggregateRiskPercent(const double percent)
   {
      m_maxAggregateRiskPercent = MathMin(100.0, MathMax(0.10, percent));
   }

   double GetMaxAggregateRiskPercent() const
   {
      return m_maxAggregateRiskPercent;
   }

   bool Check(AnalysisContext &c)
   {
      c.aggregateExposureApproved = false;
      c.aggregateCurrentRiskMoney = 0.0;
      c.aggregateCurrentRiskPercent = 0.0;
      c.aggregateProposedRiskMoney = 0.0;
      c.aggregateRiskMoney = 0.0;
      c.aggregateRiskPercent = 0.0;
      c.maxAggregateRiskPercent = m_maxAggregateRiskPercent;
      c.maxAggregateRiskMoney = 0.0;

      const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      c.globalAccountEquity = equity;

      if(equity <= 0.0)
      {
         c.blockReason = ASTRA_BLOCK_INVALID_RISK;
         c.blockDescription = "Equity invalida para ExposureGate.";
         return false;
      }

      c.maxAggregateRiskMoney =
         equity * m_maxAggregateRiskPercent / 100.0;

      // Recalculate the proposed trade risk independently from RiskManagement.
      // This prevents an inconsistent context riskAmount from understating
      // the real loss to the proposed Stop Loss.
      if(c.symbol == "" ||
         c.lotSize <= 0.0 ||
         c.entryPrice <= 0.0 ||
         c.stopLoss <= 0.0 ||
         (c.decision != DECISION_BUY && c.decision != DECISION_SELL))
      {
         c.blockReason = ASTRA_BLOCK_INVALID_RISK;
         c.blockDescription = "Dados insuficientes para calcular risco proposto.";
         return false;
      }

      bool proposedProtected = false;
      const ENUM_POSITION_TYPE proposedType =
         (c.decision == DECISION_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
      const double independentProposedRisk = CalculatePositionRiskMoney(
         c.symbol,
         proposedType,
         c.lotSize,
         c.entryPrice,
         c.stopLoss,
         proposedProtected
      );

      if(independentProposedRisk < 0.0 || !proposedProtected)
      {
         c.blockReason = ASTRA_BLOCK_INVALID_RISK;
         c.blockDescription = "Nao foi possivel calcular com seguranca o risco da nova operacao.";
         return false;
      }

      c.aggregateProposedRiskMoney = independentProposedRisk;

      const double contextRiskMoney = MathMax(0.0, c.riskAmount);
      if(contextRiskMoney > 0.0)
      {
         const double tolerance = MathMax(5.0, independentProposedRisk * 0.05);
         if(MathAbs(contextRiskMoney - independentProposedRisk) > tolerance)
         {
            PrintFormat(
               "[ExposureGate][Cycle=%I64u] RISK_RECONCILIATION | "
               "RiskManagement=%.2f | Recalculated=%.2f | Delta=%.2f",
               c.cycleId,
               contextRiskMoney,
               independentProposedRisk,
               contextRiskMoney - independentProposedRisk
            );
         }
      }

      const int totalPositions = PositionsTotal();
      for(int i = 0; i < totalPositions; ++i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;

         const ulong magic = (ulong)PositionGetInteger(POSITION_MAGIC);
         if(magic != c.magicNumber)
            continue;

         const string symbol = PositionGetString(POSITION_SYMBOL);
         const ENUM_POSITION_TYPE type =
            (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         const double volume = PositionGetDouble(POSITION_VOLUME);
         const double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         const double stopLoss = PositionGetDouble(POSITION_SL);

         if(stopLoss <= 0.0)
         {
            c.blockReason = ASTRA_BLOCK_UNPROTECTED_POSITION;
            c.blockDescription =
               "Posicao Astra sem Stop Loss; ExposureGate bloqueou novas entradas.";
            return false;
         }

         bool protectedPosition = false;
         const double positionRisk = CalculatePositionRiskMoney(
            symbol,
            type,
            volume,
            openPrice,
            stopLoss,
            protectedPosition
         );

         if(positionRisk < 0.0 || !protectedPosition)
         {
            c.blockReason = ASTRA_BLOCK_UNPROTECTED_POSITION;
            c.blockDescription =
               "Stop Loss invalido ou risco da posicao nao calculavel.";
            return false;
         }

         c.aggregateCurrentRiskMoney += positionRisk;
      }

      c.aggregateCurrentRiskPercent =
         (c.aggregateCurrentRiskMoney / equity) * 100.0;
      c.aggregateRiskMoney =
         c.aggregateCurrentRiskMoney + c.aggregateProposedRiskMoney;
      c.aggregateRiskPercent =
         (c.aggregateRiskMoney / equity) * 100.0;

      c.globalExposureMoney = c.aggregateRiskMoney;
      c.globalExposurePercent = c.aggregateRiskPercent;

      if(c.aggregateRiskPercent > m_maxAggregateRiskPercent + 1e-9)
      {
         c.blockReason = ASTRA_BLOCK_EXPOSURE_LIMIT;
         c.blockDescription = StringFormat(
            "Risco agregado projetado %.3f%% excede limite %.3f%%.",
            c.aggregateRiskPercent,
            m_maxAggregateRiskPercent
         );

         PrintFormat(
            "[ExposureGate][Cycle=%I64u] BLOCKED | CurrentRisk=%.3f%% | "
            "ProposedRisk=%.3f%% | ProjectedRisk=%.3f%% | Max=%.3f%%",
            c.cycleId,
            c.aggregateCurrentRiskPercent,
            (c.aggregateProposedRiskMoney / equity) * 100.0,
            c.aggregateRiskPercent,
            m_maxAggregateRiskPercent
         );
         return false;
      }

      c.aggregateExposureApproved = true;
      PrintFormat(
         "[ExposureGate][Cycle=%I64u] APPROVED | CurrentRisk=%.3f%% | "
         "ProposedRisk=%.3f%% | ProjectedRisk=%.3f%% | Max=%.3f%%",
         c.cycleId,
         c.aggregateCurrentRiskPercent,
         (c.aggregateProposedRiskMoney / equity) * 100.0,
         c.aggregateRiskPercent,
         m_maxAggregateRiskPercent
      );
      return true;
   }
};

#endif
