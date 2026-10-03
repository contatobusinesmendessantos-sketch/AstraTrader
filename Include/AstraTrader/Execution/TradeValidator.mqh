//+------------------------------------------------------------------+
//| TradeValidator.mqh                                               |
//| Astra Trader AI                                                  |
//|                                                                  |
//| VALIDADOR FINAL ANTES DA EXECUÇÃO                                |
//|                                                                  |
//| POLÍTICA DE POSIÇÃO:                                             |
//|   - o AstraPipeline / POSITION_GATE_FINAL controla o limite      |
//|     de posições por direção (pyramiding).                       |
//|   - este validator NÃO contradiz esse gate bloqueando uma       |
//|     posição na mesma direção quando o gate autorizou.           |
//|                                                                  |
//| A política global de posição é responsabilidade do pipeline.     |
//| O TradeValidator valida somente as condições finais de trade:     |
//| sessão, ambiente, spread, volume, stops, margem e consistência.   |
//+------------------------------------------------------------------+
#ifndef ASTRA_TRADEVALIDATOR_MQH
#define ASTRA_TRADEVALIDATOR_MQH

#property strict

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>


class TradeValidator
{
private:

   //=================================================================
   // REJECT
   //=================================================================

   bool Reject(
      AnalysisContext &c,
      const ENUM_ASTRA_BLOCK_REASON reason,
      const string description
   )
   {
      c.executionAllowed =
         false;

      c.tradeValidationPassed =
         false;

      c.executionConfirmed =
         false;

      c.orderSent =
         false;

      c.blockReason =
         reason;

      c.blockDescription =
         description;

      c.executionRejection =
         description;

      c.executionMessage =
         description;

      c.validationMessage =
         description;

      c.rejectStage =
         "TRADE_VALIDATION";

      c.rejectReason =
         description;

      c.pipelineStage =
         "TRADE_VALIDATION";

      PrintFormat(
         "[TradeValidator][Cycle=%I64u] "
         "BLOCKED | %s",
         c.cycleId,
         description
      );

      return false;
   }


   //=================================================================
   // MESMA DIREÇÃO
   //
   // Retorna true somente quando existe posição do mesmo símbolo,
   // mesmo magic e mesma direção da nova decisão.
   //
   // BUY novo:
   //   posição BUY -> bloqueia
   //   posição SELL -> permite hedge
   //
   // SELL novo:
   //   posição SELL -> bloqueia
   //   posição BUY -> permite hedge
   //=================================================================

   bool HasSameDirectionPosition(
      const ulong magic,
      const string symbol,
      const ENUM_DECISION decision,
      ulong &sameDirectionTicket,
      double &sameDirectionVolume
   )
   {
      sameDirectionTicket =
         0;

      sameDirectionVolume =
         0.0;


      if(
         magic == 0 ||
         symbol == "" ||
         (
            decision != DECISION_BUY &&
            decision != DECISION_SELL
         )
      )
      {
         return false;
      }


      const ENUM_POSITION_TYPE desiredType =
         (
            decision == DECISION_BUY
            ? POSITION_TYPE_BUY
            : POSITION_TYPE_SELL
         );


      const int total =
         PositionsTotal();


      for(
         int i = total - 1;
         i >= 0;
         i--
      )
      {
         const ulong ticket =
            PositionGetTicket(i);


         if(ticket == 0)
            continue;


         if(!PositionSelectByTicket(ticket))
            continue;


         const string positionSymbol =
            PositionGetString(
               POSITION_SYMBOL
            );


         if(positionSymbol != symbol)
            continue;


         const long positionMagic =
            PositionGetInteger(
               POSITION_MAGIC
            );


         if(
            positionMagic !=
            (long)magic
         )
         {
            continue;
         }


         const ENUM_POSITION_TYPE positionType =
            (ENUM_POSITION_TYPE)
            PositionGetInteger(
               POSITION_TYPE
            );


         if(positionType != desiredType)
            continue;


         sameDirectionTicket =
            ticket;

         sameDirectionVolume =
            PositionGetDouble(
               POSITION_VOLUME
            );

         return true;
      }


      return false;
   }


   //=================================================================
   // EXISTE POSIÇÃO OPOSTA?
   //
   // Apenas diagnóstico.
   // A existência de posição oposta NÃO é erro neste validator.
   //=================================================================

   bool HasOppositeDirectionPosition(
      const ulong magic,
      const string symbol,
      const ENUM_DECISION decision,
      ulong &oppositeTicket,
      double &oppositeVolume
   )
   {
      oppositeTicket =
         0;

      oppositeVolume =
         0.0;


      if(
         magic == 0 ||
         symbol == "" ||
         (
            decision != DECISION_BUY &&
            decision != DECISION_SELL
         )
      )
      {
         return false;
      }


      const ENUM_POSITION_TYPE oppositeType =
         (
            decision == DECISION_BUY
            ? POSITION_TYPE_SELL
            : POSITION_TYPE_BUY
         );


      const int total =
         PositionsTotal();


      for(
         int i = total - 1;
         i >= 0;
         i--
      )
      {
         const ulong ticket =
            PositionGetTicket(i);


         if(ticket == 0)
            continue;


         if(!PositionSelectByTicket(ticket))
            continue;


         const string positionSymbol =
            PositionGetString(
               POSITION_SYMBOL
            );


         if(positionSymbol != symbol)
            continue;


         const long positionMagic =
            PositionGetInteger(
               POSITION_MAGIC
            );


         if(
            positionMagic !=
            (long)magic
         )
         {
            continue;
         }


         const ENUM_POSITION_TYPE positionType =
            (ENUM_POSITION_TYPE)
            PositionGetInteger(
               POSITION_TYPE
            );


         if(positionType != oppositeType)
            continue;


         oppositeTicket =
            ticket;

         oppositeVolume =
            PositionGetDouble(
               POSITION_VOLUME
            );

         return true;
      }


      return false;
   }


public:

   //=================================================================
   // CONSTRUCTOR
   //=================================================================

   TradeValidator()
   {
   }


   //=================================================================
   // VALIDATE
   //=================================================================

   bool Validate(
      AnalysisContext &c
   )
   {
      //==============================================================
      // RESET DE ESTADO
      //==============================================================

      c.pipelineStage =
         "TRADE_VALIDATION";

      c.executionAllowed =
         false;

      c.tradeValidationPassed =
         false;

      c.executionConfirmed =
         false;

      c.orderSent =
         false;

      c.executionRejection =
         "";

      c.executionMessage =
         "";

      c.spreadValid =
         false;

      c.sessionValid =
         false;

      c.marketOpen =
         false;

      c.symbolValid =
         false;

      c.tradingAllowed =
         false;

      c.marginValid =
         false;


      //==============================================================
      // CONTEXT
      //==============================================================

      if(!c.contextValid)
      {
         return Reject(
            c,
            ASTRA_BLOCK_INVALID_DATA,
            "trade_validation_context_invalid"
         );
      }


      //==============================================================
      // STRATEGIC APPROVAL
      //==============================================================

      if(
         !c.isValid ||
         !c.decisionApproved
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_NO_DECISION,
            "trade_validation_strategy_not_approved"
         );
      }


      //==============================================================
      // RISK
      //==============================================================

      if(!c.riskApproved)
      {
         return Reject(
            c,
            ASTRA_BLOCK_INVALID_RISK,
            "trade_validation_risk_not_approved"
         );
      }


      //==============================================================
      // DECISION
      //==============================================================

      if(
         c.decision != DECISION_BUY &&
         c.decision != DECISION_SELL
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_NO_DECISION,
            "trade_validation_invalid_decision"
         );
      }


      //==============================================================
      // SYMBOL
      //==============================================================

      if(c.symbol == "")
      {
         return Reject(
            c,
            ASTRA_BLOCK_SYMBOL,
            "trade_validation_invalid_symbol"
         );
      }


      //==============================================================
      // SYMBOL SELECTION
      //==============================================================

      if(!SymbolSelect(
            c.symbol,
            true
         ))
      {
         return Reject(
            c,
            ASTRA_BLOCK_SYMBOL,
            "trade_validation_symbol_select_failed"
         );
      }


      //==============================================================
      // TRADE MODE
      //==============================================================

      const long tradeMode =
         SymbolInfoInteger(
            c.symbol,
            SYMBOL_TRADE_MODE
         );


      if(
         tradeMode ==
         SYMBOL_TRADE_MODE_DISABLED
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_TRADING_DISABLED,
            "trade_validation_symbol_trading_disabled"
         );
      }


      if(
         c.decision == DECISION_BUY &&
         tradeMode != SYMBOL_TRADE_MODE_FULL &&
         tradeMode != SYMBOL_TRADE_MODE_LONGONLY
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_TRADING_DISABLED,
            "trade_validation_buy_not_allowed"
         );
      }


      if(
         c.decision == DECISION_SELL &&
         tradeMode != SYMBOL_TRADE_MODE_FULL &&
         tradeMode != SYMBOL_TRADE_MODE_SHORTONLY
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_TRADING_DISABLED,
            "trade_validation_sell_not_allowed"
         );
      }


      c.symbolValid =
         true;


      //==============================================================
      // MARKET PRICES
      //==============================================================

      MqlTick tick;


      if(
         !SymbolInfoTick(
            c.symbol,
            tick
         )
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_INVALID_DATA,
            "trade_validation_invalid_market_prices"
         );
      }


      if(
         !c.IsValidNumericValue(tick.bid) ||
         !c.IsValidNumericValue(tick.ask) ||
         tick.bid <= 0.0 ||
         tick.ask <= 0.0 ||
         tick.ask < tick.bid
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_INVALID_DATA,
            "trade_validation_invalid_market_prices"
         );
      }


      c.bid =
         tick.bid;

      c.ask =
         tick.ask;


      c.point =
         SymbolInfoDouble(
            c.symbol,
            SYMBOL_POINT
         );


      if(
         !c.IsValidNumericValue(c.point) ||
         c.point <= 0.0
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_INVALID_DATA,
            "trade_validation_invalid_point"
         );
      }


      c.spreadPoints =
         MathAbs(
            tick.ask -
            tick.bid
         ) /
         c.point;


      if(
         c.spreadPoints >
         ASTRA_MAX_SPREAD_POINTS
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_SPREAD,
            StringFormat(
               "trade_validation_spread_too_high | "
               "%.1f > %.1f",
               c.spreadPoints,
               (double)ASTRA_MAX_SPREAD_POINTS
            )
         );
      }


      c.spreadValid =
         true;

      c.tradingAllowed =
         true;


      //==============================================================
      // TERMINAL
      //==============================================================

      if(
         !TerminalInfoInteger(
            TERMINAL_CONNECTED
         )
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_TRADING_DISABLED,
            "trade_validation_terminal_not_connected"
         );
      }


      if(
         !TerminalInfoInteger(
            TERMINAL_TRADE_ALLOWED
         )
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_TRADING_DISABLED,
            "trade_validation_terminal_trading_disabled"
         );
      }


      if(
         !MQLInfoInteger(
            MQL_TRADE_ALLOWED
         )
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_TRADING_DISABLED,
            "trade_validation_mql_trading_disabled"
         );
      }


      //==============================================================
      // SESSÃO
      //==============================================================

      // Use broker trade-server time for session validation.
      // TimeCurrent() can reflect the last quote time, while the
      // session table is defined in broker/server trading time.
      datetime now =
         TimeTradeServer();

      if(now <= 0)
         now = TimeCurrent();


      MqlDateTime dt;

      ZeroMemory(
         dt
      );


      TimeToStruct(
         now,
         dt
      );


      datetime from =
         0;

      datetime to =
         0;


      bool foundSession =
         false;

      bool marketOpen =
         false;


      const long seconds =
         (
            (long)dt.hour * 3600L +
            (long)dt.min * 60L +
            (long)dt.sec
         );


      for(
         uint i = 0;
         i < 16;
         i++
      )
      {
         if(
            !SymbolInfoSessionTrade(
               c.symbol,
               (ENUM_DAY_OF_WEEK)dt.day_of_week,
               i,
               from,
               to
            )
         )
         {
            break;
         }


         foundSession =
            true;


         // Session values are represented as datetimes; keep only
         // the time-of-day component. Normalise to [0, 86399].
         long sessionFrom =
            (long)(from % 86400);

         long sessionTo =
            (long)(to % 86400);

         if(sessionFrom < 0)
            sessionFrom += 86400;

         if(sessionTo < 0)
            sessionTo += 86400;


         bool insideSession =
            false;

         // Some brokers represent a 24h session as 00:00 -> 00:00.
         if(sessionFrom == sessionTo)
         {
            insideSession = true;
         }
         else
         if(sessionFrom < sessionTo)
         {
            // End boundary is exclusive.
            insideSession =
               (seconds >= sessionFrom && seconds < sessionTo);
         }
         else
         {
            // Session crosses midnight.
            insideSession =
               (seconds >= sessionFrom || seconds < sessionTo);
         }


         if(insideSession)
         {
            marketOpen =
               true;

            break;
         }
      }


      // If the broker exposes no session table for this symbol/day,
      // do not create a false market-closed rejection. The later
      // terminal/symbol trade checks remain authoritative.
      if(!foundSession)
         marketOpen = true;


      if(!marketOpen)
      {
         return Reject(
            c,
            ASTRA_BLOCK_MARKET_CLOSED,
            "trade_validation_market_session_closed"
         );
      }


      c.sessionValid =
         true;

      c.marketOpen =
         true;

      PrintFormat(
         "[TradeValidator][Cycle=%I64u] SESSION_VALID | "
         "Time=%02d:%02d:%02d | Day=%d | BrokerSessionFound=%s",
         c.cycleId,
         dt.hour,
         dt.min,
         dt.sec,
         dt.day_of_week,
         (foundSession ? "true" : "false")
      );


      //==============================================================
      // FINAL TRADE PARAMETERS
      //==============================================================

      if(
         !c.IsValidNumericValue(c.entryPrice) ||
         !c.IsValidNumericValue(c.stopLoss) ||
         !c.IsValidNumericValue(c.takeProfit) ||
         !c.IsValidNumericValue(c.riskReward) ||
         !c.IsValidNumericValue(c.lotSize) ||
         !c.IsValidNumericValue(c.riskPercent) ||
         !c.IsValidNumericValue(c.riskAmount) ||
         c.entryPrice <= 0.0 ||
         c.stopLoss <= 0.0 ||
         c.takeProfit <= 0.0 ||
         c.riskReward <= 0.0 ||
         c.lotSize <= 0.0
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_INVALID_RISK,
            "trade_validation_final_parameters_invalid"
         );
      }


      //==============================================================
      // LEVELS
      //==============================================================

      if(c.decision == DECISION_BUY)
      {
         if(
            c.stopLoss >= c.entryPrice ||
            c.takeProfit <= c.entryPrice
         )
         {
            return Reject(
               c,
               ASTRA_BLOCK_INVALID_RISK,
               "trade_validation_buy_levels_incoherent"
            );
         }
      }


      if(c.decision == DECISION_SELL)
      {
         if(
            c.stopLoss <= c.entryPrice ||
            c.takeProfit >= c.entryPrice
         )
         {
            return Reject(
               c,
               ASTRA_BLOCK_INVALID_RISK,
               "trade_validation_sell_levels_incoherent"
            );
         }
      }


      //==============================================================
      // RR
      //==============================================================

      const double riskDistance =
         MathAbs(
            c.entryPrice -
            c.stopLoss
         );


      const double rewardDistance =
         MathAbs(
            c.takeProfit -
            c.entryPrice
         );


      const double calculatedRR =
         (
            riskDistance > 0.0
            ? rewardDistance / riskDistance
            : 0.0
         );


      if(
         !c.IsValidNumericValue(riskDistance) ||
         !c.IsValidNumericValue(rewardDistance) ||
         !c.IsValidNumericValue(calculatedRR) ||
         riskDistance <= 0.0 ||
         rewardDistance <= 0.0
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_INVALID_RISK,
            "trade_validation_invalid_risk_reward"
         );
      }


      if(
         MathAbs(
            calculatedRR -
            c.riskReward
         ) > 0.02
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_INVALID_RISK,
            "trade_validation_rr_incoherent"
         );
      }


      //==============================================================
      // MARGIN
      //==============================================================

      const double freeMargin =
         AccountInfoDouble(
            ACCOUNT_MARGIN_FREE
         );

      if(
         !c.IsValidNumericValue(freeMargin) ||
         !c.IsValidNumericValue(c.maxAllowedMargin)
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_MARGIN_INSUFFICIENT,
            "trade_validation_non_finite_margin_data"
         );
      }


      const ENUM_ORDER_TYPE orderType =
         (
            c.decision == DECISION_BUY
            ? ORDER_TYPE_BUY
            : ORDER_TYPE_SELL
         );


      const double orderPrice =
         (
            c.decision == DECISION_BUY
            ? tick.ask
            : tick.bid
         );


      double requiredMargin =
         0.0;


      if(
         freeMargin <= 0.0 ||
         !OrderCalcMargin(
            orderType,
            c.symbol,
            c.lotSize,
            orderPrice,
            requiredMargin
         )
      )
      {
         return Reject(
            c,
            ASTRA_BLOCK_MARGIN_INSUFFICIENT,
            "trade_validation_margin_calculation_failed"
         );
      }

      if(!c.IsValidNumericValue(requiredMargin))
      {
         return Reject(
            c,
            ASTRA_BLOCK_MARGIN_INSUFFICIENT,
            "trade_validation_non_finite_required_margin"
         );
      }


      c.marginRequired =
         requiredMargin;


      if(c.maxAllowedMargin > 0.0)
      {
         if(
            requiredMargin >
            c.maxAllowedMargin
         )
         {
            return Reject(
               c,
               ASTRA_BLOCK_MARGIN_INSUFFICIENT,
               StringFormat(
                  "trade_validation_margin_over_contract | "
                  "%.2f > %.2f",
                  requiredMargin,
                  c.maxAllowedMargin
               )
            );
         }
      }
      else
      if(requiredMargin > freeMargin)
      {
         return Reject(
            c,
            ASTRA_BLOCK_MARGIN_INSUFFICIENT,
            "trade_validation_insufficient_margin"
         );
      }


      c.marginValid =
         true;


      //==============================================================
      // POSITION POLICY
      //
      // A decisão sobre permitir nova posição na mesma direção já foi
      // tomada pelo POSITION_GATE_FINAL do AstraPipeline.
      //
      // IMPORTANTE:
      //   Não repetir aqui a regra de "mesma direção = bloqueio".
      //   Isso contradiz a política PYRAMID_LIMITED configurada no EA
      //   (até 2 posições na mesma direção) e impede a execução depois
      //   de RiskManagement ter aprovado o risco.
      //
      // Este validator apenas registra o estado atual para auditoria.
      //==============================================================

      const ulong magic =
         (
            c.magicNumber > 0
            ? c.magicNumber
            : (ulong)ASTRA_DEFAULT_MAGIC
         );

      ulong sameDirectionTicket =
         0;

      double sameDirectionVolume =
         0.0;

      const bool hasSameDirection =
         HasSameDirectionPosition(
            magic,
            c.symbol,
            c.decision,
            sameDirectionTicket,
            sameDirectionVolume
         );

      if(hasSameDirection)
      {
         PrintFormat(
            "[TradeValidator][Cycle=%I64u] "
            "POSITION_GATE_AUTHORIZED_EXISTING_SAME_DIRECTION | "
            "Decision=%s | "
            "Symbol=%s | Magic=%I64u | "
            "ExistingTicket=%I64u | "
            "ExistingVolume=%.8f | "
            "Action=ALLOW_TO_EXECUTION_GATE",
            c.cycleId,
            c.DecisionToString(),
            c.symbol,
            magic,
            sameDirectionTicket,
            sameDirectionVolume
         );
      }
      else
      {
         PrintFormat(
            "[TradeValidator][Cycle=%I64u] "
            "POSITION_CLEAR | "
            "Symbol=%s | Magic=%I64u | "
            "Decision=%s | NoSameDirectionPosition=true",
            c.cycleId,
            c.symbol,
            magic,
            c.DecisionToString()
         );
      }


      //==============================================================
      // POSIÇÃO OPOSTA (AUDITORIA)
      //
      // Não altera a autorização. A política efetiva continua sendo
      // definida pelo POSITION_GATE_FINAL / configuração do pipeline.
      //==============================================================

      ulong oppositeTicket =
         0;

      double oppositeVolume =
         0.0;


      if(
         HasOppositeDirectionPosition(
            magic,
            c.symbol,
            c.decision,
            oppositeTicket,
            oppositeVolume
         )
      )
      {
         const string newDirection =
            (
               c.decision == DECISION_BUY
               ? "BUY"
               : "SELL"
            );


         const string existingDirection =
            (
               c.decision == DECISION_BUY
               ? "SELL"
               : "BUY"
            );


         PrintFormat(
            "[TradeValidator][Cycle=%I64u] "
            "OPPOSITE_POSITION_DETECTED | "
            "New=%s | Existing=%s | "
            "Symbol=%s | Magic=%I64u | "
            "ExistingTicket=%I64u | "
            "ExistingVolume=%.8f",
            c.cycleId,
            newDirection,
            existingDirection,
            c.symbol,
            magic,
            oppositeTicket,
            oppositeVolume
         );
      }
      else
      {
         PrintFormat(
            "[TradeValidator][Cycle=%I64u] "
            "POSITION_CLEAR | "
            "Symbol=%s | Magic=%I64u | "
            "Decision=%s | "
            "NoOppositeDirectionPosition=true",
            c.cycleId,
            c.symbol,
            magic,
            c.DecisionToString()
         );
      }


      //==============================================================
      // APROVAÇÃO FINAL
      //==============================================================

      c.tradeValidationPassed =
         true;

      c.executionAllowed =
         true;

      c.blockReason =
         ASTRA_BLOCK_NONE;

      c.blockDescription =
         "";

      c.executionRejection =
         "";

      c.validationMessage =
         "trade_validation_approved";

      c.pipelineStage =
         "EXECUTION_PENDING";


      PrintFormat(
         "[TradeValidator][Cycle=%I64u] "
         "APPROVED | "
         "Decision=%s | "
         "Lot=%.8f | "
         "Margin=%.2f/%.2f | "
         "PositionPolicy=POSITION_GATE_FINAL | "
         "Execution=AUTHORIZED",
         c.cycleId,
         c.DecisionToString(),
         c.lotSize,
         c.marginRequired,
         c.maxAllowedMargin
      );


      return true;
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_TRADEVALIDATOR_MQH
