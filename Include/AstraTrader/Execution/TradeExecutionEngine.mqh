//+------------------------------------------------------------------+
//| TradeExecutionEngine.mqh                                         |
//| Astra Trader AI                                                  |
//|                                                                  |
//| ESTÁGIO: TRADE EXECUTION                                         |
//|                                                                  |
//| RESPONSABILIDADES:                                               |
//|   - validar contrato final de execução                           |
//|   - configurar CTrade                                             |
//|   - enviar ordem de mercado                                      |
//|   - confirmar retcode                                             |
//|   - localizar posição através do DEAL executado                 |
//|   - registrar preço efetivo de execução                          |
//|   - fechar posição                                                |
//|   - modificar SL/TP                                               |
//|                                                                  |
//| CONTRATO DE EXECUÇÃO:                                            |
//|   referenceEntryPrice = preço observado antes do envio           |
//|   executionPrice      = preço efetivo confirmado                 |
//|   openedTicket        = DEAL_POSITION_ID                         |
//|                                                                  |
//| IMPORTANTE:                                                       |
//|   TradeExecutionEngine NÃO decide política de posições.         |
//|   SINGLE_POSITION / HEDGE_ALLOWED pertencem aos gates anteriores|
//|   e ao TradeValidator.                                           |
//+------------------------------------------------------------------+
#ifndef ASTRA_TRADEEXECUTIONENGINE_MQH
#define ASTRA_TRADEEXECUTIONENGINE_MQH

#property strict

#include <Trade/Trade.mqh>

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>
#include <AstraTrader\Execution\ITradeExecutionEngine.mqh>


class TradeExecutionEngine : public ITradeExecutionEngine
{
private:

   CTrade m_trade;

   string m_status;
   bool   m_operational;


   //=================================================================
   // MAGIC EFETIVO
   //=================================================================
   ulong GetEffectiveMagic(
      const AnalysisContext &ctx
   ) const
   {
      if(ctx.magicNumber > 0)
         return ctx.magicNumber;

      return (ulong)ASTRA_DEFAULT_MAGIC;
   }


   //=================================================================
   // DÍGITOS EFETIVOS
   //=================================================================
   int GetEffectiveDigits(
      const AnalysisContext &ctx
   ) const
   {
      if(ctx.digits > 0)
         return ctx.digits;

      long digits =
         SymbolInfoInteger(
            ctx.symbol,
            SYMBOL_DIGITS
         );

      if(digits < 0)
         return _Digits;

      return (int)digits;
   }


   //=================================================================
   // CONFIGURA CTRADE
   //=================================================================
   void ConfigureTrade(
      const AnalysisContext &ctx
   )
   {
      m_trade.SetExpertMagicNumber(
         GetEffectiveMagic(ctx)
      );


      int deviation =
         ctx.slippage;

      if(deviation <= 0)
         deviation =
            ASTRA_DEFAULT_SLIPPAGE;


      m_trade.SetDeviationInPoints(
         deviation
      );


      m_trade.SetTypeFillingBySymbol(
         ctx.symbol
      );
   }


   //=================================================================
   // RESET DO ESTADO DE EXECUÇÃO
   //=================================================================
   void ResetExecutionState(
      AnalysisContext &ctx
   )
   {
      ctx.orderSent =
         false;

      ctx.executionConfirmed =
         false;

      ctx.openedTicket =
         0;

      ctx.resultRetcode =
         0;

      ctx.referenceEntryPrice =
         0.0;

      ctx.executionPrice =
         0.0;

      ctx.executionRejection =
         "";

      ctx.executionMessage =
         "";
   }


   //=================================================================
   // REGISTRA FALHA
   //=================================================================
   bool RegisterExecutionFailure(
      AnalysisContext &ctx,
      const string reason
   )
   {
      ctx.orderSent =
         false;

      ctx.executionConfirmed =
         false;

      ctx.executionAllowed =
         false;

      ctx.openedTicket =
         0;


      ulong retcode =
         m_trade.ResultRetcode();


      ctx.resultRetcode =
         (long)retcode;


      string description =
         m_trade.ResultRetcodeDescription();


      if(description == "")
         description =
            "unknown_execution_error";


      ctx.executionRejection =
         StringFormat(
            "%s | retcode=%I64u | %s",
            reason,
            retcode,
            description
         );


      ctx.executionMessage =
         ctx.executionRejection;


      m_status =
         "EXECUTION_FAILED";


      PrintFormat(
         "[TradeExecutionEngine] FALHA | "
         "Cycle=%I64u | "
         "Symbol=%s | "
         "Decision=%s | "
         "Lot=%.8f | "
         "Retcode=%I64u | "
         "%s",
         ctx.cycleId,
         ctx.symbol,
         ctx.DecisionToString(),
         ctx.lotSize,
         retcode,
         ctx.executionRejection
      );


      return false;
   }


   //=================================================================
   // VALIDA RETCODE DE EXECUÇÃO
   //=================================================================
   bool IsMarketExecutionSuccessful() const
   {
      ulong retcode =
         m_trade.ResultRetcode();


      return
         (
            retcode == TRADE_RETCODE_DONE ||
            retcode == TRADE_RETCODE_DONE_PARTIAL
         );
   }


   //=================================================================
   // RESOLVE EXECUÇÃO PELO DEAL
   //
   // Fluxo determinístico:
   //
   //   ResultDeal()
   //        ↓
   //   HistoryDealSelect()
   //        ↓
   //   DEAL_POSITION_ID
   //        ↓
   //   DEAL_PRICE
   //
   // ResultPrice() é usado como preço confirmado principal.
   // DEAL_PRICE funciona como confirmação/fallback.
   //
   // NÃO usamos ResultOrder() como ticket de posição.
   // NÃO usamos Symbol + Magic para adivinhar a posição criada.
   //=================================================================
   bool ResolveExecutionFromDeal(
      AnalysisContext &ctx
   )
   {
      ctx.openedTicket =
         0;

      ctx.executionPrice =
         0.0;


      ulong dealTicket =
         m_trade.ResultDeal();


      if(dealTicket == 0)
      {
         ctx.executionRejection =
            "execution_deal_ticket_unavailable";

         ctx.executionMessage =
            ctx.executionRejection;

         return false;
      }


      if(
         !HistoryDealSelect(
            dealTicket
         )
      )
      {
         ctx.executionRejection =
            StringFormat(
               "execution_deal_history_select_failed | "
               "deal=%I64u",
               dealTicket
            );

         ctx.executionMessage =
            ctx.executionRejection;

         return false;
      }


      long positionId =
         HistoryDealGetInteger(
            dealTicket,
            DEAL_POSITION_ID
         );


      if(positionId <= 0)
      {
         ctx.executionRejection =
            StringFormat(
               "execution_position_id_unavailable | "
               "deal=%I64u",
               dealTicket
            );

         ctx.executionMessage =
            ctx.executionRejection;

         return false;
      }


      double dealPrice =
         HistoryDealGetDouble(
            dealTicket,
            DEAL_PRICE
         );


      double brokerPrice =
         m_trade.ResultPrice();


      //==============================================================
      // PREÇO EFETIVO
      //
      // Prioridade:
      //   1. CTrade::ResultPrice()
      //   2. DEAL_PRICE do histórico
      //==============================================================

      if(brokerPrice > 0.0)
      {
         ctx.executionPrice =
            brokerPrice;
      }
      else
      if(dealPrice > 0.0)
      {
         ctx.executionPrice =
            dealPrice;
      }
      else
      {
         ctx.executionRejection =
            StringFormat(
               "execution_price_unavailable | "
               "deal=%I64u",
               dealTicket
            );

         ctx.executionMessage =
            ctx.executionRejection;

         return false;
      }


      ctx.openedTicket =
         (ulong)positionId;


      return true;
   }


   //=================================================================
   // VALIDA DADOS BÁSICOS DA ORDEM
   //=================================================================
   bool ValidateOrderData(
      AnalysisContext &ctx
   )
   {
      if(ctx.symbol == "")
      {
         ctx.executionRejection =
            "execution_invalid_symbol";

         return false;
      }


      if(
         !MathIsValidNumber(ctx.lotSize) ||
         ctx.lotSize == EMPTY_VALUE ||
         !MathIsValidNumber(ctx.entryPrice) ||
         ctx.entryPrice == EMPTY_VALUE ||
         !MathIsValidNumber(ctx.stopLoss) ||
         ctx.stopLoss == EMPTY_VALUE ||
         !MathIsValidNumber(ctx.takeProfit) ||
         ctx.takeProfit == EMPTY_VALUE ||
         !MathIsValidNumber(ctx.riskReward) ||
         ctx.riskReward == EMPTY_VALUE
      )
      {
         ctx.executionRejection =
            "execution_non_finite_order_data";

         return false;
      }


      if(
         ctx.decision != DECISION_BUY &&
         ctx.decision != DECISION_SELL
      )
      {
         ctx.executionRejection =
            "execution_invalid_decision";

         return false;
      }


      if(ctx.lotSize <= 0.0)
      {
         ctx.executionRejection =
            "execution_invalid_lot_size";

         return false;
      }


      if(ctx.entryPrice <= 0.0)
      {
         ctx.executionRejection =
            "execution_invalid_entry_price";

         return false;
      }


      if(ctx.stopLoss <= 0.0)
      {
         ctx.executionRejection =
            "execution_invalid_stop_loss";

         return false;
      }


      if(ctx.takeProfit <= 0.0)
      {
         ctx.executionRejection =
            "execution_invalid_take_profit";

         return false;
      }


      if(ctx.riskReward <= 0.0)
      {
         ctx.executionRejection =
            "execution_invalid_risk_reward";

         return false;
      }


      return true;
   }


   //=================================================================
   // VALIDA VOLUME
   //=================================================================
   bool ValidateVolume(
      AnalysisContext &ctx
   )
   {
      double volumeMin =
         SymbolInfoDouble(
            ctx.symbol,
            SYMBOL_VOLUME_MIN
         );


      double volumeMax =
         SymbolInfoDouble(
            ctx.symbol,
            SYMBOL_VOLUME_MAX
         );


      double volumeStep =
         SymbolInfoDouble(
            ctx.symbol,
            SYMBOL_VOLUME_STEP
         );


      if(
         !MathIsValidNumber(volumeMin) ||
         volumeMin == EMPTY_VALUE ||
         !MathIsValidNumber(volumeMax) ||
         volumeMax == EMPTY_VALUE ||
         !MathIsValidNumber(volumeStep) ||
         volumeStep == EMPTY_VALUE ||
         volumeMin <= 0.0 ||
         volumeMax <= 0.0 ||
         volumeStep <= 0.0
      )
      {
         ctx.executionRejection =
            "execution_invalid_volume_rules";

         return false;
      }


      if(ctx.lotSize < volumeMin)
      {
         ctx.executionRejection =
            StringFormat(
               "execution_volume_below_minimum | "
               "lot=%.8f | min=%.8f",
               ctx.lotSize,
               volumeMin
            );

         return false;
      }


      if(ctx.lotSize > volumeMax)
      {
         ctx.executionRejection =
            StringFormat(
               "execution_volume_above_maximum | "
               "lot=%.8f | max=%.8f",
               ctx.lotSize,
               volumeMax
            );

         return false;
      }


      double steps =
         ctx.lotSize /
         volumeStep;


      double roundedSteps =
         MathRound(
            steps
         );


      if(
         MathAbs(
            steps -
            roundedSteps
         ) > 0.0000001
      )
      {
         ctx.executionRejection =
            StringFormat(
               "execution_volume_invalid_step | "
               "lot=%.8f | step=%.8f",
               ctx.lotSize,
               volumeStep
            );

         return false;
      }


      return true;
   }


   //=================================================================
   // VALIDA SÍMBOLO
   //=================================================================
   bool ValidateSymbol(
      AnalysisContext &ctx
   )
   {
      ResetLastError();


      if(
         !SymbolSelect(
            ctx.symbol,
            true
         )
      )
      {
         int error =
            GetLastError();


         ctx.executionRejection =
            StringFormat(
               "execution_symbol_select_failed | "
               "symbol=%s | error=%d",
               ctx.symbol,
               error
            );


         return false;
      }


      long tradeMode =
         SymbolInfoInteger(
            ctx.symbol,
            SYMBOL_TRADE_MODE
         );


      if(
         tradeMode ==
         SYMBOL_TRADE_MODE_DISABLED
      )
      {
         ctx.executionRejection =
            "execution_symbol_trading_disabled";

         return false;
      }


      if(
         ctx.decision == DECISION_BUY &&
         tradeMode != SYMBOL_TRADE_MODE_FULL &&
         tradeMode != SYMBOL_TRADE_MODE_LONGONLY
      )
      {
         ctx.executionRejection =
            "execution_buy_not_allowed";

         return false;
      }


      if(
         ctx.decision == DECISION_SELL &&
         tradeMode != SYMBOL_TRADE_MODE_FULL &&
         tradeMode != SYMBOL_TRADE_MODE_SHORTONLY
      )
      {
         ctx.executionRejection =
            "execution_sell_not_allowed";

         return false;
      }


      return true;
   }


   //=================================================================
   // VALIDA PREÇO ATUAL
   //=================================================================
   bool ValidateCurrentPrice(
      AnalysisContext &ctx,
      MqlTick &tick
   )
   {
      ZeroMemory(
         tick
      );


      if(
         !SymbolInfoTick(
            ctx.symbol,
            tick
         )
      )
      {
         ctx.executionRejection =
            "execution_current_tick_unavailable";

         return false;
      }


      if(
         !MathIsValidNumber(tick.bid) ||
         tick.bid == EMPTY_VALUE ||
         !MathIsValidNumber(tick.ask) ||
         tick.ask == EMPTY_VALUE ||
         tick.bid <= 0.0 ||
         tick.ask <= 0.0 ||
         tick.ask < tick.bid
      )
      {
         ctx.executionRejection =
            "execution_invalid_current_price";

         return false;
      }


      return true;
   }


   //=================================================================
   // VALIDA STOPS
   //
   // Para ordem a mercado:
   //
   // BUY  -> execução pelo ASK
   // SELL -> execução pelo BID
   //
   // O preço real poderá diferir.
   // Esta validação verifica se os níveis são válidos em relação
   // ao preço de mercado no momento do envio.
   //=================================================================
   bool ValidateStops(
      AnalysisContext &ctx,
      const MqlTick &tick
   )
   {
      double point =
         SymbolInfoDouble(
            ctx.symbol,
            SYMBOL_POINT
         );


      if(point <= 0.0)
      {
         ctx.executionRejection =
            "execution_invalid_point";

         return false;
      }


      double marketExecutionReference =
         (
            ctx.decision == DECISION_BUY
            ? tick.ask
            : tick.bid
         );


      if(marketExecutionReference <= 0.0)
      {
         ctx.executionRejection =
            "execution_invalid_execution_price";

         return false;
      }


      //==============================================================
      // DIREÇÃO DOS NÍVEIS
      //==============================================================

      if(ctx.decision == DECISION_BUY)
      {
         if(ctx.stopLoss >= marketExecutionReference)
         {
            ctx.executionRejection =
               "execution_buy_invalid_stop";

            return false;
         }


         if(ctx.takeProfit <= marketExecutionReference)
         {
            ctx.executionRejection =
               "execution_buy_invalid_take";

            return false;
         }
      }
      else
      if(ctx.decision == DECISION_SELL)
      {
         if(ctx.stopLoss <= marketExecutionReference)
         {
            ctx.executionRejection =
               "execution_sell_invalid_stop";

            return false;
         }


         if(ctx.takeProfit >= marketExecutionReference)
         {
            ctx.executionRejection =
               "execution_sell_invalid_take";

            return false;
         }
      }


      //==============================================================
      // DISTÂNCIA MÍNIMA
      //==============================================================

      long stopsLevel =
         SymbolInfoInteger(
            ctx.symbol,
            SYMBOL_TRADE_STOPS_LEVEL
         );


      long freezeLevel =
         SymbolInfoInteger(
            ctx.symbol,
            SYMBOL_TRADE_FREEZE_LEVEL
         );


      if(stopsLevel < 0)
         stopsLevel = 0;


      if(freezeLevel < 0)
         freezeLevel = 0;


      double minimumDistance =
         MathMax(
            MathMax(
               (double)stopsLevel * point,
               (double)freezeLevel * point
            ),
            point
         );


      if(
         MathAbs(
            marketExecutionReference -
            ctx.stopLoss
         ) < minimumDistance
      )
      {
         ctx.executionRejection =
            "execution_stop_too_close";

         return false;
      }


      if(
         MathAbs(
            ctx.takeProfit -
            marketExecutionReference
         ) < minimumDistance
      )
      {
         ctx.executionRejection =
            "execution_take_too_close";

         return false;
      }


      return true;
   }


   //=================================================================
   // VALIDA MARGEM FINAL
   //=================================================================
   bool ValidateFinalMargin(
      AnalysisContext &ctx,
      const MqlTick &tick
   )
   {
      double freeMargin =
         AccountInfoDouble(
            ACCOUNT_MARGIN_FREE
         );


      if(
         !MathIsValidNumber(freeMargin) ||
         freeMargin == EMPTY_VALUE ||
         freeMargin <= 0.0
      )
      {
         ctx.executionRejection =
            "execution_no_free_margin";

         return false;
      }


      ENUM_ORDER_TYPE type;


      if(ctx.decision == DECISION_BUY)
      {
         type =
            ORDER_TYPE_BUY;
      }
      else
      if(ctx.decision == DECISION_SELL)
      {
         type =
            ORDER_TYPE_SELL;
      }
      else
      {
         ctx.executionRejection =
            "execution_invalid_order_type";

         return false;
      }


      double price =
         (
            ctx.decision == DECISION_BUY
            ? tick.ask
            : tick.bid
         );


      if(
         !MathIsValidNumber(price) ||
         price == EMPTY_VALUE ||
         price <= 0.0
      )
      {
         ctx.executionRejection =
            "execution_invalid_margin_price";

         return false;
      }


      double requiredMargin =
         0.0;


      ResetLastError();


      if(
         !OrderCalcMargin(
            type,
            ctx.symbol,
            ctx.lotSize,
            price,
            requiredMargin
         )
      )
      {
         int error =
            GetLastError();


         ctx.executionRejection =
            StringFormat(
               "execution_margin_calculation_failed | "
               "error=%d",
               error
            );


         return false;
      }

      if(
         !MathIsValidNumber(requiredMargin) ||
         requiredMargin == EMPTY_VALUE
      )
      {
         ctx.executionRejection =
            "execution_non_finite_required_margin";

         return false;
      }


      if(requiredMargin <= 0.0)
      {
         ctx.executionRejection =
            "execution_invalid_required_margin";

         return false;
      }


      if(requiredMargin > freeMargin)
      {
         ctx.executionRejection =
            StringFormat(
               "execution_insufficient_margin | "
               "symbol=%s | "
               "lot=%.8f | "
               "required=%.2f | "
               "free=%.2f",
               ctx.symbol,
               ctx.lotSize,
               requiredMargin,
               freeMargin
            );


         return false;
      }


      return true;
   }


public:

   //=================================================================
   // CONSTRUTOR
   //=================================================================
   TradeExecutionEngine()
   {
      m_status =
         "INITIALIZED";

      m_operational =
         true;
   }


   //=================================================================
   // DESTRUTOR
   //=================================================================
   ~TradeExecutionEngine()
   {
      m_operational =
         false;
   }


   //=================================================================
   // OPERACIONAL
   //=================================================================
   bool IsSystemOperational()
   {
      return m_operational;
   }


   //=================================================================
   // STATUS
   //=================================================================
   string GetStatus()
   {
      return m_status;
   }


   //=================================================================
   // ABRIR POSIÇÃO
   //=================================================================
   bool OpenPosition(
      AnalysisContext &ctx
   )
   {
      //==============================================================
      // RESET
      //==============================================================

      ResetExecutionState(
         ctx
      );


      //==============================================================
      // ENGINE
      //==============================================================

      if(!m_operational)
      {
         ctx.executionAllowed =
            false;

         ctx.executionRejection =
            "execution_engine_not_operational";

         ctx.executionMessage =
            ctx.executionRejection;

         m_status =
            "ENGINE_NOT_OPERATIONAL";

         return false;
      }


      //==============================================================
      // GATE 1
      //
      // executionAllowed é responsabilidade do estágio anterior.
      // TradeExecutionEngine respeita o contrato recebido.
      //==============================================================

      if(!ctx.executionAllowed)
      {
         ctx.executionRejection =
            "execution_not_allowed";

         ctx.executionMessage =
            ctx.executionRejection;

         m_status =
            "EXECUTION_NOT_ALLOWED";

         return false;
      }


      //==============================================================
      // GATE 2
      //==============================================================

      if(
         !ctx.isValid ||
         !ctx.decisionApproved
      )
      {
         ctx.executionRejection =
            "execution_decision_not_approved";

         ctx.executionMessage =
            ctx.executionRejection;

         ctx.executionAllowed =
            false;

         m_status =
            "DECISION_NOT_APPROVED";

         return false;
      }


      //==============================================================
      // DADOS DA ORDEM
      //==============================================================

      if(!ValidateOrderData(ctx))
      {
         ctx.executionMessage =
            ctx.executionRejection;

         ctx.executionAllowed =
            false;

         m_status =
            "INVALID_ORDER_DATA";

         return false;
      }


      //==============================================================
      // VOLUME
      //==============================================================

      if(!ValidateVolume(ctx))
      {
         ctx.executionMessage =
            ctx.executionRejection;

         ctx.executionAllowed =
            false;

         m_status =
            "INVALID_VOLUME";

         return false;
      }


      //==============================================================
      // SÍMBOLO
      //==============================================================

      if(!ValidateSymbol(ctx))
      {
         ctx.executionMessage =
            ctx.executionRejection;

         ctx.executionAllowed =
            false;

         m_status =
            "INVALID_SYMBOL";

         return false;
      }


      //==============================================================
      // PREÇO ATUAL
      //==============================================================

      MqlTick tick;


      if(
         !ValidateCurrentPrice(
            ctx,
            tick
         )
      )
      {
         ctx.executionMessage =
            ctx.executionRejection;

         ctx.executionAllowed =
            false;

         m_status =
            "INVALID_MARKET_PRICE";

         return false;
      }


      //==============================================================
      // REFERÊNCIA PRÉ-EXECUÇÃO
      //
      // Esse valor NÃO é o preço confirmado.
      // Serve para auditoria e slippage.
      //==============================================================

      ctx.referenceEntryPrice =
         (
            ctx.decision == DECISION_BUY
            ? tick.ask
            : tick.bid
         );


      //==============================================================
      // STOPS
      //==============================================================

      if(
         !ValidateStops(
            ctx,
            tick
         )
      )
      {
         ctx.executionMessage =
            ctx.executionRejection;

         ctx.executionAllowed =
            false;

         m_status =
            "INVALID_STOPS";

         return false;
      }


      //==============================================================
      // MARGEM
      //==============================================================

      if(
         !ValidateFinalMargin(
            ctx,
            tick
         )
      )
      {
         ctx.executionMessage =
            ctx.executionRejection;

         ctx.executionAllowed =
            false;

         m_status =
            "INSUFFICIENT_MARGIN";

         return false;
      }


      //==============================================================
      // CONFIGURA CTRADE
      //==============================================================

      ConfigureTrade(
         ctx
      );


      //==============================================================
      // ENVIA ORDEM DE MERCADO
      //
      // price = 0.0
      //
      // CTrade determina o preço de mercado apropriado.
      //==============================================================

      bool result =
         false;


      if(
         ctx.decision ==
         DECISION_BUY
      )
      {
         result =
            m_trade.Buy(
               ctx.lotSize,
               ctx.symbol,
               0.0,
               ctx.stopLoss,
               ctx.takeProfit,
               ctx.orderComment
            );
      }
      else
      if(
         ctx.decision ==
         DECISION_SELL
      )
      {
         result =
            m_trade.Sell(
               ctx.lotSize,
               ctx.symbol,
               0.0,
               ctx.stopLoss,
               ctx.takeProfit,
               ctx.orderComment
            );
      }


      //==============================================================
      // FALHA DA REQUEST
      //==============================================================

      if(!result)
      {
         return RegisterExecutionFailure(
            ctx,
            "execution_request_failed"
         );
      }


      //==============================================================
      // RETCODE
      //==============================================================

      if(
         !IsMarketExecutionSuccessful()
      )
      {
         return RegisterExecutionFailure(
            ctx,
            "execution_retcode_rejected"
         );
      }


      ctx.resultRetcode =
         (long)m_trade.ResultRetcode();


      //==============================================================
      // RESOLVE DEAL -> POSITION + PREÇO
      //
      // Não fazemos fallback ambíguo por Symbol + Magic.
      //==============================================================

      if(
         !ResolveExecutionFromDeal(
            ctx
         )
      )
      {
         ctx.orderSent =
            true;

         ctx.executionConfirmed =
            false;

         ctx.executionAllowed =
            false;

         m_status =
            "EXECUTION_CONTRACT_ERROR";


         PrintFormat(
            "[TradeExecutionEngine] "
            "EXECUÇÃO DO SERVIDOR ACEITA, MAS CONTRATO "
            "DE EXECUÇÃO NÃO PÔDE SER RESOLVIDO | "
            "Cycle=%I64u | "
            "Symbol=%s | "
            "Decision=%s | "
            "Deal=%I64u | "
            "Order=%I64u | "
            "Retcode=%I64d | "
            "ReferencePrice=%.8f | "
            "Reason=%s",
            ctx.cycleId,
            ctx.symbol,
            ctx.DecisionToString(),
            m_trade.ResultDeal(),
            m_trade.ResultOrder(),
            ctx.resultRetcode,
            ctx.referenceEntryPrice,
            ctx.executionRejection
         );


         return false;
      }


      //==============================================================
      // CONFIRMAÇÃO FINAL
      //==============================================================

      ctx.orderSent =
         true;

      ctx.executionConfirmed =
         true;

      ctx.executionRejection =
         "";


      int digits =
         GetEffectiveDigits(
            ctx
         );


      ctx.executionMessage =
         StringFormat(
            "execution_success | "
            "ticket=%I64u | "
            "deal=%I64u | "
            "symbol=%s | "
            "lots=%.8f | "
            "referencePrice=%s | "
            "executionPrice=%s | "
            "SL=%s | "
            "TP=%s | "
            "retcode=%I64d",
            ctx.openedTicket,
            m_trade.ResultDeal(),
            ctx.symbol,
            ctx.lotSize,
            DoubleToString(
               ctx.referenceEntryPrice,
               digits
            ),
            DoubleToString(
               ctx.executionPrice,
               digits
            ),
            DoubleToString(
               ctx.stopLoss,
               digits
            ),
            DoubleToString(
               ctx.takeProfit,
               digits
            ),
            ctx.resultRetcode
         );


      m_status =
         "EXECUTION_COMPLETE";


      PrintFormat(
         "[TradeExecutionEngine] EXECUTADO | "
         "Cycle=%I64u | "
         "Decision=%s | "
         "Symbol=%s | "
         "Lots=%.8f | "
         "Ticket=%I64u | "
         "Deal=%I64u | "
         "ReferencePrice=%s | "
         "ExecutionPrice=%s | "
         "Retcode=%I64d",
         ctx.cycleId,
         ctx.DecisionToString(),
         ctx.symbol,
         ctx.lotSize,
         ctx.openedTicket,
         m_trade.ResultDeal(),
         DoubleToString(
            ctx.referenceEntryPrice,
            digits
         ),
         DoubleToString(
            ctx.executionPrice,
            digits
         ),
         ctx.resultRetcode
      );


      return true;
   }


   //=================================================================
   // FECHAR POSIÇÃO
   //=================================================================
   bool ClosePosition(
      const ulong ticket
   )
   {
      if(!m_operational)
      {
         m_status =
            "ENGINE_NOT_OPERATIONAL";

         return false;
      }


      if(ticket == 0)
      {
         m_status =
            "INVALID_TICKET";

         return false;
      }


      if(
         !PositionSelectByTicket(
            ticket
         )
      )
      {
         m_status =
            "POSITION_NOT_FOUND";

         return false;
      }


      bool result =
         m_trade.PositionClose(
            ticket
         );


      if(!result)
      {
         m_status =
            "CLOSE_FAILED";


         PrintFormat(
            "[TradeExecutionEngine] "
            "Falha ao fechar posição | "
            "Ticket=%I64u | "
            "Retcode=%I64u | "
            "%s",
            ticket,
            m_trade.ResultRetcode(),
            m_trade.ResultRetcodeDescription()
         );


         return false;
      }


      ulong retcode =
         m_trade.ResultRetcode();


      if(
         retcode != TRADE_RETCODE_DONE &&
         retcode != TRADE_RETCODE_DONE_PARTIAL
      )
      {
         m_status =
            "CLOSE_FAILED";


         PrintFormat(
            "[TradeExecutionEngine] "
            "Fechamento rejeitado | "
            "Ticket=%I64u | "
            "Retcode=%I64u | "
            "%s",
            ticket,
            retcode,
            m_trade.ResultRetcodeDescription()
         );


         return false;
      }


      m_status =
         "POSITION_CLOSED";


      PrintFormat(
         "[TradeExecutionEngine] "
         "POSIÇÃO FECHADA | "
         "Ticket=%I64u | "
         "Retcode=%I64u",
         ticket,
         retcode
      );


      return true;
   }


   //=================================================================
   // MODIFICAR POSIÇÃO
   //=================================================================
   bool ModifyPosition(
      const ulong ticket,
      const double stopLoss,
      const double takeProfit
   )
   {
      if(!m_operational)
      {
         m_status =
            "ENGINE_NOT_OPERATIONAL";

         return false;
      }


      if(ticket == 0)
      {
         m_status =
            "INVALID_TICKET";

         return false;
      }


      if(
         stopLoss < 0.0 ||
         takeProfit < 0.0
      )
      {
         m_status =
            "INVALID_STOPS";

         return false;
      }


      if(
         !PositionSelectByTicket(
            ticket
         )
      )
      {
         m_status =
            "POSITION_NOT_FOUND";

         return false;
      }


      bool result =
         m_trade.PositionModify(
            ticket,
            stopLoss,
            takeProfit
         );


      if(!result)
      {
         m_status =
            "MODIFY_FAILED";


         PrintFormat(
            "[TradeExecutionEngine] "
            "Falha ao modificar posição | "
            "Ticket=%I64u | "
            "Retcode=%I64u | "
            "%s",
            ticket,
            m_trade.ResultRetcode(),
            m_trade.ResultRetcodeDescription()
         );


         return false;
      }


      ulong retcode =
         m_trade.ResultRetcode();


      if(
         retcode != TRADE_RETCODE_DONE &&
         retcode != TRADE_RETCODE_DONE_PARTIAL &&
         retcode != TRADE_RETCODE_NO_CHANGES
      )
      {
         m_status =
            "MODIFY_FAILED";


         PrintFormat(
            "[TradeExecutionEngine] "
            "Modificação rejeitada | "
            "Ticket=%I64u | "
            "Retcode=%I64u | "
            "%s",
            ticket,
            retcode,
            m_trade.ResultRetcodeDescription()
         );


         return false;
      }


      m_status =
         "POSITION_MODIFIED";


      string symbol =
         PositionGetString(
            POSITION_SYMBOL
         );


      int digits =
         (int)SymbolInfoInteger(
            symbol,
            SYMBOL_DIGITS
         );


      if(digits < 0)
         digits = _Digits;


      PrintFormat(
         "[TradeExecutionEngine] "
         "POSIÇÃO MODIFICADA | "
         "Ticket=%I64u | "
         "Symbol=%s | "
         "SL=%s | "
         "TP=%s | "
         "Retcode=%I64u",
         ticket,
         symbol,
         DoubleToString(
            stopLoss,
            digits
         ),
         DoubleToString(
            takeProfit,
            digits
         ),
         retcode
      );


      return true;
   }


   //=================================================================
   // ÚLTIMO RETCODE
   //=================================================================
   long GetLastRetcode()
   {
      return
         (long)m_trade.ResultRetcode();
   }


   //=================================================================
   // DESCRIÇÃO DO ÚLTIMO RETCODE
   //=================================================================
   string GetLastRetcodeDescription()
   {
      return
         m_trade.ResultRetcodeDescription();
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_TRADEEXECUTIONENGINE_MQH