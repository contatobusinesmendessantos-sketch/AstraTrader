//+------------------------------------------------------------------+
//| RiskManagementEngine.mqh                                         |
//| Astra Trader AI                                                  |
//+------------------------------------------------------------------+
#ifndef ASTRA_RISKMANAGEMENTENGINE_MQH
#define ASTRA_RISKMANAGEMENTENGINE_MQH

#property strict

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>


class RiskManagementEngine
{
private:

   string m_status;

   double m_entry;
   double m_sl;
   double m_tp;
   double m_rr;

   double m_maxRiskPercent;
   double m_minimumRR;

   int m_maxSpreadPoints;

   double m_marginSafetyBuffer;

   bool m_operational;
   bool m_tradeValid;


   //=================================================================
   // CLAMP
   //=================================================================

   double Clamp(
      double v,
      double a,
      double b
   ) const
   {
      return MathMax(
         a,
         MathMin(
            b,
            v
         )
      );
   }


   //=================================================================
   // TIPO DE ORDEM
   //=================================================================

   bool GetOrderType(
      const AnalysisContext &c,
      ENUM_ORDER_TYPE &t
   ) const
   {
      if(
         c.decision ==
         DECISION_BUY
      )
      {
         t =
            ORDER_TYPE_BUY;

         return true;
      }


      if(
         c.decision ==
         DECISION_SELL
      )
      {
         t =
            ORDER_TYPE_SELL;

         return true;
      }


      return false;
   }


   //=================================================================
   // PREÇO PARA CÁLCULO DE MARGEM
   //=================================================================

   double MarginPrice(
      const AnalysisContext &c,
      const MqlTick &t
   ) const
   {
      if(
         c.decision ==
         DECISION_BUY
      )
      {
         return t.ask;
      }


      if(
         c.decision ==
         DECISION_SELL
      )
      {
         return t.bid;
      }


      return c.entryPrice;
   }


   //=================================================================
   // NORMALIZA VOLUME
   //=================================================================

   double NormalizeVolume(
      const string s,
      const double requested
   ) const
   {
      const double minLot =
         SymbolInfoDouble(
            s,
            SYMBOL_VOLUME_MIN
         );

      const double maxLot =
         SymbolInfoDouble(
            s,
            SYMBOL_VOLUME_MAX
         );

      const double step =
         SymbolInfoDouble(
            s,
            SYMBOL_VOLUME_STEP
         );


      if(
         minLot <= 0.0 ||
         maxLot <= 0.0 ||
         step <= 0.0 ||
         requested <= 0.0
      )
      {
         return 0.0;
      }


      double volume =
         MathMin(
            requested,
            maxLot
         );


      volume =
         MathFloor(
            volume / step
         ) * step;


      if(volume < minLot)
         return 0.0;


      volume =
         MathMin(
            volume,
            maxLot
         );


      return NormalizeDouble(
         volume,
         8
      );
   }


   //=================================================================
   // PERDA POR LOTE
   //=================================================================

   double LossPerLot(
      const AnalysisContext &c
   ) const
   {
      ENUM_ORDER_TYPE orderType;


      if(
         !GetOrderType(
            c,
            orderType
         )
      )
      {
         return 0.0;
      }


      double profit = 0.0;


      if(
         OrderCalcProfit(
            orderType,
            c.symbol,
            1.0,
            c.entryPrice,
            c.stopLoss,
            profit
         )
      )
      {
         if(
            MathIsValidNumber(
               profit
            ) &&
            MathAbs(profit) > 0.0
         )
         {
            return MathAbs(
               profit
            );
         }
      }


      const double tickSize =
         SymbolInfoDouble(
            c.symbol,
            SYMBOL_TRADE_TICK_SIZE
         );

      const double tickValue =
         SymbolInfoDouble(
            c.symbol,
            SYMBOL_TRADE_TICK_VALUE
         );

      const double distance =
         MathAbs(
            c.entryPrice -
            c.stopLoss
         );


      if(
         tickSize <= 0.0 ||
         tickValue <= 0.0 ||
         distance <= 0.0
      )
      {
         return 0.0;
      }


      return
         (
            distance /
            tickSize
         ) *
         tickValue;
   }


   //=================================================================
   // LOTE BRUTO CALCULADO PELO RISCO
   //=================================================================

   double CalculateRawRiskLot(
      const AnalysisContext &c
   ) const
   {
      const double equity =
         AccountInfoDouble(
            ACCOUNT_EQUITY
         );


      const double riskMoney =
         equity *
         (
            m_maxRiskPercent /
            100.0
         );


      const double lossPerLot =
         LossPerLot(
            c
         );


      if(
         equity <= 0.0 ||
         riskMoney <= 0.0 ||
         lossPerLot <= 0.0
      )
      {
         return 0.0;
      }


      return
         riskMoney /
         lossPerLot;
   }


   //=================================================================
   // LOTE NORMALIZADO PELO RISCO
   //=================================================================

   double CalcLot(
      const AnalysisContext &c
   ) const
   {
      const double rawLot =
         CalculateRawRiskLot(
            c
         );


      if(rawLot <= 0.0)
         return 0.0;


      return NormalizeVolume(
         c.symbol,
         rawLot
      );
   }


   //=================================================================
   // LOTE SEGURO PELA MARGEM
   //=================================================================

   double SafeLotByMargin(
      const AnalysisContext &c,
      double requested,
      const MqlTick &tick
   ) const
   {
      const double freeMargin =
         AccountInfoDouble(
            ACCOUNT_MARGIN_FREE
         );


      const double allowedMargin =
         freeMargin *
         m_marginSafetyBuffer;


      ENUM_ORDER_TYPE orderType;


      if(
         freeMargin <= 0.0 ||
         !GetOrderType(
            c,
            orderType
         )
      )
      {
         return 0.0;
      }


      const double price =
         MarginPrice(
            c,
            tick
         );


      const double minLot =
         SymbolInfoDouble(
            c.symbol,
            SYMBOL_VOLUME_MIN
         );


      const double step =
         SymbolInfoDouble(
            c.symbol,
            SYMBOL_VOLUME_STEP
         );


      requested =
         NormalizeVolume(
            c.symbol,
            requested
         );


      if(
         requested <= 0.0 ||
         price <= 0.0 ||
         minLot <= 0.0 ||
         step <= 0.0
      )
      {
         return 0.0;
      }


      double margin = 0.0;


      if(
         OrderCalcMargin(
            orderType,
            c.symbol,
            requested,
            price,
            margin
         ) &&
         margin > 0.0 &&
         margin <= allowedMargin
      )
      {
         return requested;
      }


      double candidate =
         requested;


      while(
         candidate >= minLot &&
         candidate > 0.0
      )
      {
         margin = 0.0;


         if(
            OrderCalcMargin(
               orderType,
               c.symbol,
               candidate,
               price,
               margin
            ) &&
            margin > 0.0 &&
            margin <= allowedMargin
         )
         {
            return NormalizeVolume(
               c.symbol,
               candidate
            );
         }


         candidate =
            NormalizeDouble(
               candidate - step,
               8
            );
      }


      return 0.0;
   }


   //=================================================================
   // DISTÂNCIA MÍNIMA DO STOP
   //=================================================================

   double MinStopDistance(
      const string s,
      const double point
   ) const
   {
      const long stopsLevel =
         SymbolInfoInteger(
            s,
            SYMBOL_TRADE_STOPS_LEVEL
         );


      const long freezeLevel =
         SymbolInfoInteger(
            s,
            SYMBOL_TRADE_FREEZE_LEVEL
         );


      return MathMax(
         MathMax(
            (double)stopsLevel *
            point,

            (double)freezeLevel *
            point
         ),
         point
      );
   }


   //=================================================================
   // MODO DE NEGOCIAÇÃO
   //=================================================================

   bool TradeMode(
      const AnalysisContext &c,
      string &reason
   ) const
   {
      reason = "";


      const long mode =
         SymbolInfoInteger(
            c.symbol,
            SYMBOL_TRADE_MODE
         );


      if(
         mode ==
         SYMBOL_TRADE_MODE_DISABLED
      )
      {
         reason =
            "Trading desabilitado.";

         return false;
      }


      if(
         c.decision ==
         DECISION_BUY &&
         mode ==
         SYMBOL_TRADE_MODE_SHORTONLY
      )
      {
         reason =
            "Broker permite somente SELL.";

         return false;
      }


      if(
         c.decision ==
         DECISION_SELL &&
         mode ==
         SYMBOL_TRADE_MODE_LONGONLY
      )
      {
         reason =
            "Broker permite somente BUY.";

         return false;
      }


      return true;
   }


   //=================================================================
   // RESET DE RISCO
   //=================================================================

   void ResetRisk(
      AnalysisContext &c
   )
   {
      c.entryPrice =
         0.0;

      c.stopLoss =
         0.0;

      c.takeProfit =
         0.0;

      c.referenceEntryPrice =
         0.0;

      c.executionPrice =
         0.0;

      c.stopDistancePoints =
         0.0;

      c.takeProfitDistance =
         0.0;

      c.riskPercent =
         0.0;

      c.riskAmount =
         0.0;

      c.riskReward =
         0.0;

      c.lotSize =
         0.0;

      c.maxAllowedRisk =
         0.0;

      c.marginRequired =
         0.0;

      c.maxAllowedMargin =
         0.0;

      c.marginSafetyBuffer =
         m_marginSafetyBuffer;

      c.riskApproved =
         false;

      c.marginValid =
         false;
   }


public:

   //=================================================================
   // CONSTRUCTOR
   //=================================================================

   RiskManagementEngine()
   {
      m_status =
         "INITIALIZING";

      m_entry =
         0.0;

      m_sl =
         0.0;

      m_tp =
         0.0;

      m_rr =
         0.0;

      m_maxRiskPercent =
         ASTRA_DEFAULT_RISK_PERCENT;

      m_minimumRR =
         ASTRA_MIN_RISK_REWARD_DEFAULT;

      m_maxSpreadPoints =
         ASTRA_MAX_SPREAD_POINTS;

      m_marginSafetyBuffer =
         ASTRA_DEFAULT_MARGIN_BUFFER;

      m_operational =
         false;

      m_tradeValid =
         false;
   }


   //=================================================================
   // SISTEMA OPERACIONAL
   //=================================================================

   bool IsSystemOperational()
   {
      MqlTick tick;


      if(
         !SymbolInfoTick(
            _Symbol,
            tick
         )
      )
      {
         m_status =
            "BLOCKED_INVALID_TICK";

         m_operational =
            false;

         return false;
      }


      const double point =
         SymbolInfoDouble(
            _Symbol,
            SYMBOL_POINT
         );


      const double spreadPoints =
         (
            point > 0.0
            ? MathAbs(
                 tick.ask -
                 tick.bid
              ) /
              point
            : 999999.0
         );


      const long mode =
         SymbolInfoInteger(
            _Symbol,
            SYMBOL_TRADE_MODE
         );


      m_operational =
         (
            point > 0.0 &&
            spreadPoints <=
               m_maxSpreadPoints &&
            mode !=
               SYMBOL_TRADE_MODE_DISABLED &&
            AccountInfoDouble(
               ACCOUNT_MARGIN_FREE
            ) > 0.0
         );


      m_status =
         (
            m_operational
            ? "SYSTEM_READY"
            : "SYSTEM_BLOCKED"
         );


      return m_operational;
   }


   //=================================================================
   // ANALYZE RISK
   //=================================================================

   bool AnalyzeRisk(
      AnalysisContext &c
   )
   {
      ResetRisk(
         c
      );


      m_tradeValid =
         false;


      c.pipelineStage =
         "RISK_MANAGEMENT";

      c.rejectStage =
         "";

      c.rejectReason =
         "";


      //==============================================================
      // CONTEXTO
      //==============================================================

      if(
         !c.Validate()
      )
      {
         return Reject(
            c,
            "AnalysisContext inválido.",
            ASTRA_BLOCK_INVALID_DATA
         );
      }


      //==============================================================
      // DECISÃO ESTRATÉGICA
      //==============================================================

      if(
         !c.isValid ||
         !c.decisionApproved
      )
      {
         return Reject(
            c,
            "Sinal estratégico não aprovado.",
            ASTRA_BLOCK_NO_DECISION
         );
      }


      //==============================================================
      // DECISÃO BUY / SELL
      //==============================================================

      if(
         c.decision != DECISION_BUY &&
         c.decision != DECISION_SELL
      )
      {
         return Reject(
            c,
            "Sem decisão BUY/SELL.",
            ASTRA_BLOCK_NO_DECISION
         );
      }


      //==============================================================
      // SYMBOL
      //==============================================================

      if(c.symbol == "")
      {
         return Reject(
            c,
            "Symbol inválido.",
            ASTRA_BLOCK_SYMBOL
         );
      }


      //==============================================================
      // TICK
      //==============================================================

      MqlTick tick;


      if(
         !SymbolInfoTick(
            c.symbol,
            tick
         ) ||
         tick.bid <= 0.0 ||
         tick.ask <= 0.0 ||
         tick.ask < tick.bid
      )
      {
         return Reject(
            c,
            "Tick inválido.",
            ASTRA_BLOCK_INVALID_DATA
         );
      }


      //==============================================================
      // POINT / SPREAD
      //==============================================================

      const double point =
         SymbolInfoDouble(
            c.symbol,
            SYMBOL_POINT
         );


      if(point <= 0.0)
      {
         return Reject(
            c,
            "Point inválido.",
            ASTRA_BLOCK_INVALID_DATA
         );
      }


      c.point =
         point;

      c.bid =
         tick.bid;

      c.ask =
         tick.ask;


      c.spreadPoints =
         MathAbs(
            tick.ask -
            tick.bid
         ) /
         point;


      if(
         c.spreadPoints >
         m_maxSpreadPoints
      )
      {
         return Reject(
            c,
            StringFormat(
               "Spread acima do permitido %.1f > %d.",
               c.spreadPoints,
               m_maxSpreadPoints
            ),
            ASTRA_BLOCK_SPREAD
         );
      }


      c.spreadValid =
         true;


      //==============================================================
      // TRADE MODE
      //==============================================================

      string reason;


      if(
         !TradeMode(
            c,
            reason
         )
      )
      {
         return Reject(
            c,
            reason,
            ASTRA_BLOCK_TRADING_DISABLED
         );
      }


      c.tradingAllowed =
         true;


      //==============================================================
      // ENTRY
      //==============================================================

      const int digits =
         (int)SymbolInfoInteger(
            c.symbol,
            SYMBOL_DIGITS
         );


      const double entry =
         (
            c.decision ==
            DECISION_BUY
            ? tick.ask
            : tick.bid
         );


      c.entryPrice =
         NormalizeDouble(
            entry,
            digits
         );


      c.referenceEntryPrice =
         c.entryPrice;


      if(
         c.entryPrice <= 0.0
      )
      {
         return Reject(
            c,
            "Entry inválido.",
            ASTRA_BLOCK_INVALID_RISK
         );
      }


      //==============================================================
      // STOP LOSS
      //==============================================================

      double sl =
         (
            c.decision ==
            DECISION_BUY
            ? c.lastSwingLowPrice
            : c.lastSwingHighPrice
         );


      const double minDist =
         MinStopDistance(
            c.symbol,
            point
         );


      if(
         sl <= 0.0 ||
         (
            c.decision ==
            DECISION_BUY &&
            sl >= c.entryPrice
         ) ||
         (
            c.decision ==
            DECISION_SELL &&
            sl <= c.entryPrice
         )
      )
      {
         sl =
            (
               c.decision ==
               DECISION_BUY
               ? c.entryPrice -
                 c.atr *
                 1.5
               : c.entryPrice +
                 c.atr *
                 1.5
            );
      }


      if(sl <= 0.0)
      {
         sl =
            (
               c.decision ==
               DECISION_BUY
               ? c.entryPrice -
                 100.0 *
                 point
               : c.entryPrice +
                 100.0 *
                 point
            );
      }


      //==============================================================
      // TICK SIZE / PRICE STEP
      //==============================================================

      const double tickSize =
         SymbolInfoDouble(
            c.symbol,
            SYMBOL_TRADE_TICK_SIZE
         );


      const double priceStep =
         MathMax(
            point,
            (
               tickSize > 0.0
               ? tickSize
               : point
            )
         );


      //==============================================================
      // BUILD SL / TP
      //==============================================================

      if(
         c.decision ==
         DECISION_BUY
      )
      {
         if(
            sl >= c.entryPrice
         )
         {
            sl =
               c.entryPrice -
               minDist;
         }


         const double stopDistance =
            MathMax(
               c.entryPrice - sl,
               minDist
            );


         c.stopLoss =
            NormalizeDouble(
               c.entryPrice -
               stopDistance,
               digits
            );


         const double finalStopDistance =
            MathAbs(
               c.entryPrice -
               c.stopLoss
            );


         double requiredSteps =
            MathCeil(
               (
                  finalStopDistance *
                  m_minimumRR
               ) /
               priceStep
               - 1e-9
            );


         if(requiredSteps < 1.0)
            requiredSteps = 1.0;


         const double takeProfitDistance =
            requiredSteps *
            priceStep;


         c.takeProfit =
            NormalizeDouble(
               c.entryPrice +
               takeProfitDistance,
               digits
            );
      }
      else
      {
         if(
            sl <= c.entryPrice
         )
         {
            sl =
               c.entryPrice +
               minDist;
         }


         const double stopDistance =
            MathMax(
               sl -
               c.entryPrice,
               minDist
            );


         c.stopLoss =
            NormalizeDouble(
               c.entryPrice +
               stopDistance,
               digits
            );


         const double finalStopDistance =
            MathAbs(
               c.stopLoss -
               c.entryPrice
            );


         double requiredSteps =
            MathCeil(
               (
                  finalStopDistance *
                  m_minimumRR
               ) /
               priceStep
               - 1e-9
            );


         if(requiredSteps < 1.0)
            requiredSteps = 1.0;


         const double takeProfitDistance =
            requiredSteps *
            priceStep;


         c.takeProfit =
            NormalizeDouble(
               c.entryPrice -
               takeProfitDistance,
               digits
            );
      }


      //==============================================================
      // STOP / TP DISTANCES
      //==============================================================

      c.stopDistancePoints =
         MathAbs(
            c.entryPrice -
            c.stopLoss
         ) /
         point;


      c.takeProfitDistance =
         MathAbs(
            c.takeProfit -
            c.entryPrice
         ) /
         point;


      c.riskReward =
         (
            c.stopDistancePoints > 0.0
            ? c.takeProfitDistance /
              c.stopDistancePoints
            : 0.0
         );


      //==============================================================
      // REFORÇA RR MÍNIMO
      //==============================================================

      if(
         c.riskReward <
         m_minimumRR
      )
      {
         const double stopDistance =
            MathAbs(
               c.entryPrice -
               c.stopLoss
            );


         double requiredSteps =
            MathCeil(
               (
                  stopDistance *
                  m_minimumRR
               ) /
               priceStep
               - 1e-9
            );


         if(requiredSteps < 1.0)
            requiredSteps = 1.0;


         const double takeProfitDistance =
            requiredSteps *
            priceStep;


         c.takeProfit =
            (
               c.decision ==
               DECISION_BUY
               ? NormalizeDouble(
                    c.entryPrice +
                    takeProfitDistance,
                    digits
                 )
               : NormalizeDouble(
                    c.entryPrice -
                    takeProfitDistance,
                    digits
                 )
            );


         c.takeProfitDistance =
            MathAbs(
               c.takeProfit -
               c.entryPrice
            ) /
            point;


         c.riskReward =
            (
               c.stopDistancePoints > 0.0
               ? c.takeProfitDistance /
                 c.stopDistancePoints
               : 0.0
            );
      }


      //==============================================================
      // TOLERÂNCIA NUMÉRICA
      //==============================================================

      const double rrTolerance =
         1e-6;


      if(
         c.riskReward +
         rrTolerance <
         m_minimumRR
      )
      {
         return Reject(
            c,
            StringFormat(
               "RR insuficiente %.8f < %.2f",
               c.riskReward,
               m_minimumRR
            ),
            ASTRA_BLOCK_INVALID_RISK
         );
      }


      //==============================================================
      // CONTA
      //==============================================================

      c.accountEquity =
         AccountInfoDouble(
            ACCOUNT_EQUITY
         );


      c.accountBalance =
         AccountInfoDouble(
            ACCOUNT_BALANCE
         );


      if(
         c.accountEquity <= 0.0
      )
      {
         return Reject(
            c,
            "Equity inválido.",
            ASTRA_BLOCK_INVALID_RISK
         );
      }


      c.maxAllowedRisk =
         c.accountEquity *
         (
            m_maxRiskPercent /
            100.0
         );


      c.riskPercent =
         m_maxRiskPercent;


      c.riskLevel =
         (
            m_maxRiskPercent <= 0.5
            ? RISK_LOW
            : (
               m_maxRiskPercent <= 1.0
               ? RISK_MEDIUM
               : (
                  m_maxRiskPercent <= 2.0
                  ? RISK_HIGH
                  : RISK_EXTREME
               )
            )
         );


      //==============================================================
      // CÁLCULO DO LOTE POR RISCO
      //==============================================================

      const double equity =
         c.accountEquity;


      const double riskMoney =
         equity *
         (
            m_maxRiskPercent /
            100.0
         );


      const double lossPerLot =
         LossPerLot(
            c
         );


      const double rawLot =
         (
            lossPerLot > 0.0
            ? riskMoney /
              lossPerLot
            : 0.0
         );


      const double minLot =
         SymbolInfoDouble(
            c.symbol,
            SYMBOL_VOLUME_MIN
         );


      const double maxLot =
         SymbolInfoDouble(
            c.symbol,
            SYMBOL_VOLUME_MAX
         );


      const double lotStep =
         SymbolInfoDouble(
            c.symbol,
            SYMBOL_VOLUME_STEP
         );


      const double normalizedLot =
         CalcLot(
            c
         );


      //==============================================================
      // DIAGNÓSTICO COMPLETO DO LOTE
      //==============================================================

      PrintFormat(
         "[RiskManagement][Cycle=%I64u] "
         "LOT_DIAGNOSTIC | "
         "Equity=%.2f | "
         "RiskMoney=%.2f | "
         "LossPerLot=%.8f | "
         "RawLot=%.8f | "
         "MinLot=%.8f | "
         "MaxLot=%.8f | "
         "LotStep=%.8f | "
         "NormalizedLot=%.8f",
         c.cycleId,
         equity,
         riskMoney,
         lossPerLot,
         rawLot,
         minLot,
         maxLot,
         lotStep,
         normalizedLot
      );


      //==============================================================
      // VALIDAÇÃO DOS PARÂMETROS
      //==============================================================

      if(
         equity <= 0.0 ||
         riskMoney <= 0.0 ||
         lossPerLot <= 0.0 ||
         minLot <= 0.0 ||
         maxLot <= 0.0 ||
         lotStep <= 0.0
      )
      {
         return Reject(
            c,
            "Parâmetros de risco/volume inválidos.",
            ASTRA_BLOCK_INVALID_RISK
         );
      }


      //==============================================================
      // SE O LOTE NORMALIZADO É VÁLIDO
      //==============================================================

      double requestedLot =
         normalizedLot;


      if(
         requestedLot > 0.0
      )
      {
         PrintFormat(
            "[RiskManagement][Cycle=%I64u] "
            "LOT_SELECTED | "
            "Mode=RISK_NORMALIZED | "
            "RequestedLot=%.8f",
            c.cycleId,
            requestedLot
         );
      }
      else
      {
         //===========================================================
         // LOTE ABAIXO DO MÍNIMO
         //
         // Testamos o lote mínimo do ativo.
         // Só será aceito caso o risco efetivo continue <= máximo.
         //===========================================================

         if(
            rawLot <
            minLot
         )
         {
            double minimumLotRisk =
               0.0;


            ENUM_ORDER_TYPE riskOrderType;


            if(
               !GetOrderType(
                  c,
                  riskOrderType
               )
            )
            {
               return Reject(
                  c,
                  "Tipo de ordem inválido para cálculo do lote mínimo.",
                  ASTRA_BLOCK_NO_DECISION
               );
            }


            if(
               !OrderCalcProfit(
                  riskOrderType,
                  c.symbol,
                  minLot,
                  c.entryPrice,
                  c.stopLoss,
                  minimumLotRisk
               )
            )
            {
               return Reject(
                  c,
                  "Falha ao calcular risco do lote mínimo.",
                  ASTRA_BLOCK_INVALID_RISK
               );
            }


            minimumLotRisk =
               MathAbs(
                  minimumLotRisk
               );


            const double minimumLotRiskPercent =
               (
                  equity > 0.0
                  ? 100.0 *
                    minimumLotRisk /
                    equity
                  : 999.0
               );


            PrintFormat(
               "[RiskManagement][Cycle=%I64u] "
               "MIN_LOT_TEST | "
               "RawLot=%.8f | "
               "MinLot=%.8f | "
               "MinLotRisk=%.2f | "
               "MinLotRiskPercent=%.4f%% | "
               "MaxRisk=%.4f%%",
               c.cycleId,
               rawLot,
               minLot,
               minimumLotRisk,
               minimumLotRiskPercent,
               m_maxRiskPercent
            );


            if(
               minimumLotRiskPercent >
               m_maxRiskPercent +
               0.0001
            )
            {
               return Reject(
                  c,
                  StringFormat(
                     "Lote mínimo %.8f excede o risco máximo: "
                     "%.4f%% > %.4f%%.",
                     minLot,
                     minimumLotRiskPercent,
                     m_maxRiskPercent
                  ),
                  ASTRA_BLOCK_INVALID_RISK
               );
            }


            requestedLot =
               minLot;


            PrintFormat(
               "[RiskManagement][Cycle=%I64u] "
               "LOT_SELECTED | "
               "Mode=MIN_LOT_SAFE | "
               "RequestedLot=%.8f | "
               "EffectiveRisk=%.4f%%",
               c.cycleId,
               requestedLot,
               minimumLotRiskPercent
            );
         }
         else
         {
            return Reject(
               c,
               "Lote calculado inválido.",
               ASTRA_BLOCK_INVALID_RISK
            );
         }
      }


      //==============================================================
      // MARGEM
      //==============================================================

      const double safe =
         SafeLotByMargin(
            c,
            requestedLot,
            tick
         );


      if(
         safe <= 0.0
      )
      {
         return Reject(
            c,
            "Margem insuficiente para o lote permitido.",
            ASTRA_BLOCK_MARGIN_INSUFFICIENT
         );
      }


      c.lotSize =
         safe;


      //==============================================================
      // RISCO REAL DA ORDEM
      //==============================================================

      ENUM_ORDER_TYPE orderType;


      if(
         !GetOrderType(
            c,
            orderType
         )
      )
      {
         return Reject(
            c,
            "Tipo de ordem inválido.",
            ASTRA_BLOCK_NO_DECISION
         );
      }


      double realRisk =
         0.0;


      if(
         !OrderCalcProfit(
            orderType,
            c.symbol,
            c.lotSize,
            c.entryPrice,
            c.stopLoss,
            realRisk
         )
      )
      {
         return Reject(
            c,
            "Falha no cálculo do risco real.",
            ASTRA_BLOCK_INVALID_RISK
         );
      }


      c.riskAmount =
         MathAbs(
            realRisk
         );


      c.riskPercent =
         (
            c.accountEquity > 0.0
            ? 100.0 *
              c.riskAmount /
              c.accountEquity
            : 999.0
         );


      //==============================================================
      // VALIDA RISCO MÁXIMO
      //==============================================================

      if(
         c.riskPercent >
         m_maxRiskPercent +
         0.0001
      )
      {
         return Reject(
            c,
            StringFormat(
               "Risco efetivo %.4f%% excede máximo %.4f%%.",
               c.riskPercent,
               m_maxRiskPercent
            ),
            ASTRA_BLOCK_INVALID_RISK
         );
      }


      //==============================================================
      // MARGEM FINAL
      //==============================================================

      const double freeMargin =
         AccountInfoDouble(
            ACCOUNT_MARGIN_FREE
         );


      const double allowedMargin =
         freeMargin *
         m_marginSafetyBuffer;


      const double marginPrice =
         MarginPrice(
            c,
            tick
         );


      double requiredMargin =
         0.0;


      if(
         !OrderCalcMargin(
            orderType,
            c.symbol,
            c.lotSize,
            marginPrice,
            requiredMargin
         ) ||
         requiredMargin <= 0.0
      )
      {
         return Reject(
            c,
            "Falha no cálculo de margem.",
            ASTRA_BLOCK_MARGIN_INSUFFICIENT
         );
      }


      c.marginRequired =
         requiredMargin;


      c.maxAllowedMargin =
         allowedMargin;


      c.marginSafetyBuffer =
         m_marginSafetyBuffer;


      if(
         requiredMargin >
         allowedMargin
      )
      {
         return Reject(
            c,
            StringFormat(
               "Margem %.2f > limite %.2f.",
               requiredMargin,
               allowedMargin
            ),
            ASTRA_BLOCK_MARGIN_INSUFFICIENT
         );
      }


      c.marginValid =
         true;


      //==============================================================
      // APROVAÇÃO
      //==============================================================

      c.riskApproved =
         true;

      c.tradeValidationPassed =
         false;

      c.executionAllowed =
         false;

      c.riskApproved =
         true;


      m_entry =
         c.entryPrice;

      m_sl =
         c.stopLoss;

      m_tp =
         c.takeProfit;

      m_rr =
         c.riskReward;


      m_tradeValid =
         true;

      m_operational =
         true;

      m_status =
         "RISK_APPROVED";


      c.blockReason =
         ASTRA_BLOCK_NONE;

      c.blockDescription =
         "";


      c.pipelineStage =
         "TRADE_VALIDATION_PENDING";


      c.validationMessage =
         "Risk aprovado; aguardando TradeValidator.";


      PrintFormat(
         "[RiskManagement][Cycle=%I64u] "
         "APPROVED | "
         "Decision=%s | "
         "Entry=%.5f | "
         "SL=%.5f | "
         "TP=%.5f | "
         "RR=%.3f | "
         "Lot=%.8f | "
         "Risk=%.3f%% | "
         "Margin=%.2f/%.2f",
         c.cycleId,
         c.DecisionToString(),
         c.entryPrice,
         c.stopLoss,
         c.takeProfit,
         c.riskReward,
         c.lotSize,
         c.riskPercent,
         c.marginRequired,
         c.maxAllowedMargin
      );


      return true;
   }


   //=================================================================
   // REJECT
   //=================================================================

   bool Reject(
      AnalysisContext &c,
      const string description,
      const ENUM_ASTRA_BLOCK_REASON reason
   )
   {
      c.riskApproved =
         false;

      c.executionAllowed =
         false;

      c.tradeValidationPassed =
         false;


      c.blockReason =
         reason;

      c.blockDescription =
         description;

      c.validationMessage =
         description;

      c.rejectStage =
         "RISK_MANAGEMENT";

      c.rejectReason =
         description;

      c.pipelineStage =
         "RISK_MANAGEMENT";


      m_status =
         "RISK_BLOCKED";

      m_tradeValid =
         false;


      PrintFormat(
         "[RiskManagement][Cycle=%I64u] "
         "BLOCKED | %s",
         c.cycleId,
         description
      );


      return false;
   }


   //=================================================================
   // GETTERS
   //=================================================================

   string GetStatus() const
   {
      return m_status;
   }


   double GetEntry() const
   {
      return m_entry;
   }


   double GetStopLoss() const
   {
      return m_sl;
   }


   double GetTakeProfit() const
   {
      return m_tp;
   }


   double GetRiskReward() const
   {
      return m_rr;
   }


   bool IsAllowed() const
   {
      return m_tradeValid;
   }


   //=================================================================
   // CONFIG
   //=================================================================

   void SetMinimumRR(
      const double value
   )
   {
      if(value > 0.0)
         m_minimumRR = value;
   }


   void SetMaxRiskPercent(
      const double value
   )
   {
      if(value > 0.0)
         m_maxRiskPercent = value;
   }


   void SetMaxSpreadPoints(
      const int value
   )
   {
      if(value > 0)
         m_maxSpreadPoints = value;
   }


   void SetMarginSafetyBuffer(
      const double value
   )
   {
      if(
         value > 0.0 &&
         value <= 1.0
      )
      {
         m_marginSafetyBuffer =
            value;
      }
   }


   double GetMarginSafetyBuffer() const
   {
      return m_marginSafetyBuffer;
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_RISKMANAGEMENTENGINE_MQH