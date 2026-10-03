//+------------------------------------------------------------------+
//| PositionManager.mqh                                              |
//| Astra Trader AI                                                  |
//|                                                                  |
//| ESTÁGIO: POSITION MANAGEMENT                                     |
//|                                                                  |
//| RESPONSABILIDADES:                                               |
//|   - BreakEven                                                    |
//|   - Trailing Stop                                                |
//|   - Time Exit                                                    |
//|   - adaptação por ATR                                            |
//|   - gerenciamento apenas de posições do Astra                   |
//|                                                                  |
//| NÃO abre novas posições.                                         |
//| NÃO decide BUY/SELL.                                             |
//| NÃO calcula lote.                                                |
//| NÃO recalcula risco.                                             |
//|                                                                  |
//| CONTRATO OPERACIONAL:                                            |
//|   - respeitar Symbol + Magic                                     |
//|   - usar deviation do contexto                                   |
//|   - usar filling por símbolo                                     |
//|   - confirmar retcode                                             |
//|   - registrar request/result                                     |
//+------------------------------------------------------------------+
#ifndef ASTRA_POSITIONMANAGER_MQH
#define ASTRA_POSITIONMANAGER_MQH

#property strict

#include <Trade/Trade.mqh>

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>


class PositionManager
{
private:

   //=================================================================
   // CTRADE
   //=================================================================

   CTrade m_trade;


   //=================================================================
   // CONFIGURAÇÃO BASE
   //=================================================================

   double m_breakEvenTriggerPoints;
   double m_breakEvenOffsetPoints;

   double m_trailingStartPoints;
   double m_trailingStepPoints;

   int    m_maxHoldingSeconds;


   //=================================================================
   // ATR
   //=================================================================

   bool   m_useATR;

   double m_beTriggerATRMult;
   double m_beOffsetATRMult;

   double m_trailStartATRMult;
   double m_trailDistATRMult;

   int    m_atrHandle;

   string m_atrSymbol;

   ENUM_TIMEFRAMES m_atrTF;


   //=================================================================
   // MAGIC EFETIVO
   //=================================================================

   ulong GetEffectiveMagic(
      const AnalysisContext &ctx
   ) const
   {
      if(ctx.magicNumber > 0)
         return (ulong)ctx.magicNumber;

      return (ulong)ASTRA_DEFAULT_MAGIC;
   }


   //=================================================================
   // CONFIGURA CTRADE PARA O SÍMBOLO
   //=================================================================

   void ConfigureTradeForPosition(
      const AnalysisContext &ctx,
      const string symbol
   )
   {
      ulong magic =
         GetEffectiveMagic(ctx);

      int deviation =
         ctx.slippage;

      if(deviation <= 0)
         deviation =
            ASTRA_DEFAULT_SLIPPAGE;

      m_trade.SetExpertMagicNumber(
         magic
      );

      m_trade.SetDeviationInPoints(
         deviation
      );

      if(symbol != "")
      {
         m_trade.SetTypeFillingBySymbol(
            symbol
         );
      }
   }


   //=================================================================
   // RETCODE DE MODIFICAÇÃO
   //=================================================================

   bool IsModificationSuccess() const
   {
      uint retcode =
         m_trade.ResultRetcode();

      return
         (
            retcode == TRADE_RETCODE_DONE ||
            retcode == TRADE_RETCODE_DONE_PARTIAL ||
            retcode == TRADE_RETCODE_NO_CHANGES
         );
   }


   //=================================================================
   // RETCODE DE FECHAMENTO
   //=================================================================

   bool IsCloseSuccess() const
   {
      uint retcode =
         m_trade.ResultRetcode();

      return
         (
            retcode == TRADE_RETCODE_DONE ||
            retcode == TRADE_RETCODE_DONE_PARTIAL
         );
   }


   //=================================================================
   // POSIÇÃO PERTENCE AO ASTRA
   //
   // A posição deve estar previamente selecionada.
   //=================================================================

   bool IsOwnPosition(
      const ulong magic
   ) const
   {
      long positionMagic =
         PositionGetInteger(
            POSITION_MAGIC
         );

      return
         (
            positionMagic ==
            (long)magic
         );
   }


   //=================================================================
   // POSIÇÃO PERTENCE AO SÍMBOLO DO CONTEXTO
   //=================================================================

   bool IsOwnPositionForContext(
      const AnalysisContext &ctx
   ) const
   {
      string symbol =
         PositionGetString(
            POSITION_SYMBOL
         );

      if(symbol == "")
         return false;

      if(ctx.symbol == "")
         return false;

      return
         (
            symbol ==
            ctx.symbol
         );
   }


   //=================================================================
   // ATR HANDLE
   //=================================================================

   bool EnsureATR(
      const string symbol,
      const ENUM_TIMEFRAMES timeframe
   )
   {
      if(symbol == "")
         return false;

      if(timeframe == PERIOD_CURRENT)
         return false;


      //==============================================================
      // HANDLE JÁ COMPATÍVEL
      //==============================================================

      if(
         m_atrHandle != INVALID_HANDLE &&
         m_atrSymbol == symbol &&
         m_atrTF == timeframe
      )
      {
         return true;
      }


      //==============================================================
      // LIBERA HANDLE ANTIGO
      //==============================================================

      if(
         m_atrHandle != INVALID_HANDLE
      )
      {
         IndicatorRelease(
            m_atrHandle
         );

         m_atrHandle =
            INVALID_HANDLE;
      }


      m_atrSymbol =
         "";

      m_atrTF =
         PERIOD_CURRENT;


      //==============================================================
      // CRIA NOVO ATR
      //==============================================================

      ResetLastError();

      m_atrHandle =
         iATR(
            symbol,
            timeframe,
            14
         );


      if(
         m_atrHandle ==
         INVALID_HANDLE
      )
      {
         PrintFormat(
            "[PositionManager] "
            "ATR HANDLE FAILED | "
            "Symbol=%s | TF=%d | Error=%d",
            symbol,
            (int)timeframe,
            GetLastError()
         );

         return false;
      }


      m_atrSymbol =
         symbol;

      m_atrTF =
         timeframe;


      return true;
   }


   //=================================================================
   // ATR EM PONTOS
   //
   // Usa a última barra FECHADA.
   // shift = 1
   //=================================================================

   double GetATRPoints(
      const string symbol
   )
   {
      if(
         m_atrHandle ==
         INVALID_HANDLE
      )
      {
         return 0.0;
      }


      double buffer[];

      ArraySetAsSeries(
         buffer,
         true
      );


      ResetLastError();

      int copied =
         CopyBuffer(
            m_atrHandle,
            0,
            1,
            1,
            buffer
         );


      if(copied < 1)
      {
         return 0.0;
      }


      if(ArraySize(buffer) < 1)
      {
         return 0.0;
      }


      double point =
         SymbolInfoDouble(
            symbol,
            SYMBOL_POINT
         );


      if(point <= 0.0)
      {
         return 0.0;
      }


      double atr =
         buffer[0];


      if(atr <= 0.0)
      {
         return 0.0;
      }


      return
         atr / point;
   }


   //=================================================================
   // DISTÂNCIAS EFETIVAS
   //=================================================================

   void GetEffectiveDistances(
      const string symbol,
      double &beTrigger,
      double &beOffset,
      double &trailStart,
      double &trailDist
   )
   {
      beTrigger =
         m_breakEvenTriggerPoints;

      beOffset =
         m_breakEvenOffsetPoints;

      trailStart =
         m_trailingStartPoints;

      trailDist =
         m_trailingStepPoints;


      if(!m_useATR)
         return;


      double atrPoints =
         GetATRPoints(
            symbol
         );


      if(atrPoints <= 0.0)
         return;


      //==============================================================
      // ATR NÃO REDUZ CONFIGURAÇÃO BASE
      //==============================================================

      beTrigger =
         MathMax(
            beTrigger,
            atrPoints *
            m_beTriggerATRMult
         );


      beOffset =
         MathMax(
            beOffset,
            atrPoints *
            m_beOffsetATRMult
         );


      trailStart =
         MathMax(
            trailStart,
            atrPoints *
            m_trailStartATRMult
         );


      trailDist =
         MathMax(
            trailDist,
            atrPoints *
            m_trailDistATRMult
         );
   }


   //=================================================================
   // DISTÂNCIA MÍNIMA DO BROKER
   //
   // Proteção conservadora:
   //
   // max(
   //    stops level,
   //    freeze level,
   //    1 point
   // )
   //
   // O resultado é expresso em preço.
   //=================================================================

   double GetMinStopDistance(
      const string symbol
   ) const
   {
      if(symbol == "")
         return 0.0;


      double point =
         SymbolInfoDouble(
            symbol,
            SYMBOL_POINT
         );


      if(point <= 0.0)
         return 0.0;


      long stopsLevel =
         0;

      long freezeLevel =
         0;


      ResetLastError();


      if(
         !SymbolInfoInteger(
            symbol,
            SYMBOL_TRADE_STOPS_LEVEL,
            stopsLevel
         )
      )
      {
         stopsLevel =
            0;
      }


      if(
         !SymbolInfoInteger(
            symbol,
            SYMBOL_TRADE_FREEZE_LEVEL,
            freezeLevel
         )
      )
      {
         freezeLevel =
            0;
      }


      if(stopsLevel < 0)
         stopsLevel = 0;

      if(freezeLevel < 0)
         freezeLevel = 0;


      double stopsDistance =
         (double)stopsLevel *
         point;


      double freezeDistance =
         (double)freezeLevel *
         point;


      return
         MathMax(
            MathMax(
               stopsDistance,
               freezeDistance
            ),
            point
         );
   }


   //=================================================================
   // NORMALIZA PREÇO
   //=================================================================

   double NormalizePrice(
      const string symbol,
      const double price
   ) const
   {
      if(price <= 0.0)
         return 0.0;


      int digits =
         (int)SymbolInfoInteger(
            symbol,
            SYMBOL_DIGITS
         );


      if(digits < 0)
         digits = 0;


      return
         NormalizeDouble(
            price,
            digits
         );
   }


   //=================================================================
   // VALIDA SL BUY
   //=================================================================

   bool IsValidBuySL(
      const string symbol,
      const double bid,
      const double sl,
      const double minimumDistance
   ) const
   {
      if(bid <= 0.0)
         return false;

      if(sl <= 0.0)
         return false;

      if(sl >= bid)
         return false;

      if(
         (bid - sl) <
         minimumDistance
      )
      {
         return false;
      }

      return true;
   }


   //=================================================================
   // VALIDA SL SELL
   //=================================================================

   bool IsValidSellSL(
      const string symbol,
      const double ask,
      const double sl,
      const double minimumDistance
   ) const
   {
      if(ask <= 0.0)
         return false;

      if(sl <= 0.0)
         return false;

      if(sl <= ask)
         return false;

      if(
         (sl - ask) <
         minimumDistance
      )
      {
         return false;
      }

      return true;
   }


   //=================================================================
   // BREAKEVEN
   //=================================================================

   bool ApplyBreakEven(
      const ulong ticket,
      const double triggerPoints,
      const double offsetPoints
   )
   {
      if(
         !PositionSelectByTicket(
            ticket
         )
      )
      {
         return false;
      }


      string symbol =
         PositionGetString(
            POSITION_SYMBOL
         );


      if(symbol == "")
         return false;


      long type =
         PositionGetInteger(
            POSITION_TYPE
         );


      double openPrice =
         PositionGetDouble(
            POSITION_PRICE_OPEN
         );


      double currentSL =
         PositionGetDouble(
            POSITION_SL
         );


      double currentTP =
         PositionGetDouble(
            POSITION_TP
         );


      double point =
         SymbolInfoDouble(
            symbol,
            SYMBOL_POINT
         );


      if(point <= 0.0)
         return false;


      if(openPrice <= 0.0)
         return false;


      double minimumDistance =
         GetMinStopDistance(
            symbol
         );


      int digits =
         (int)SymbolInfoInteger(
            symbol,
            SYMBOL_DIGITS
         );


      //==============================================================
      // BUY
      //==============================================================

      if(
         type ==
         POSITION_TYPE_BUY
      )
      {
         double bid =
            SymbolInfoDouble(
               symbol,
               SYMBOL_BID
            );


         if(bid <= 0.0)
            return false;


         double profitPoints =
            (
               bid -
               openPrice
            ) / point;


         if(
            profitPoints <
            triggerPoints
         )
         {
            return false;
         }


         double newSL =
            NormalizeDouble(
               openPrice +
               offsetPoints * point,
               digits
            );


         //===========================================================
         // SL PRECISA ESTAR ABAIXO DO BID
         //===========================================================

         if(
            !IsValidBuySL(
               symbol,
               bid,
               newSL,
               minimumDistance
            )
         )
         {
            return false;
         }


         //===========================================================
         // NÃO PIORAR SL EXISTENTE
         //===========================================================

         if(
            currentSL != 0.0 &&
            newSL <= currentSL + point
         )
         {
            return false;
         }


         ResetLastError();


         bool requestResult =
            m_trade.PositionModify(
               ticket,
               newSL,
               currentTP
            );


         uint retcode =
            m_trade.ResultRetcode();


         if(
            requestResult &&
            IsModificationSuccess()
         )
         {
            PrintFormat(
               "[PositionManager] "
               "BREAKEVEN | "
               "Ticket=%I64u | "
               "Symbol=%s | "
               "SL=%s | "
               "Profit=%.1f pts | "
               "Retcode=%I64u | "
               "%s",
               ticket,
               symbol,
               DoubleToString(
                  newSL,
                  digits
               ),
               profitPoints,
               retcode,
               m_trade.ResultRetcodeDescription()
            );

            return true;
         }


         PrintFormat(
            "[PositionManager] "
            "BREAKEVEN FAILED | "
            "Ticket=%I64u | "
            "Symbol=%s | "
            "SL=%s | "
            "Profit=%.1f pts | "
            "Request=%s | "
            "Retcode=%I64u | "
            "%s | "
            "Error=%d",
            ticket,
            symbol,
            DoubleToString(
               newSL,
               digits
            ),
            profitPoints,
            requestResult ? "true" : "false",
            retcode,
            m_trade.ResultRetcodeDescription(),
            GetLastError()
         );

         return false;
      }


      //==============================================================
      // SELL
      //==============================================================

      if(
         type ==
         POSITION_TYPE_SELL
      )
      {
         double ask =
            SymbolInfoDouble(
               symbol,
               SYMBOL_ASK
            );


         if(ask <= 0.0)
            return false;


         double profitPoints =
            (
               openPrice -
               ask
            ) / point;


         if(
            profitPoints <
            triggerPoints
         )
         {
            return false;
         }


         double newSL =
            NormalizeDouble(
               openPrice -
               offsetPoints * point,
               digits
            );


         //===========================================================
         // SL PRECISA ESTAR ACIMA DO ASK
         //===========================================================

         if(
            !IsValidSellSL(
               symbol,
               ask,
               newSL,
               minimumDistance
            )
         )
         {
            return false;
         }


         //===========================================================
         // NÃO PIORAR SL EXISTENTE
         //===========================================================

         if(
            currentSL != 0.0 &&
            newSL >= currentSL - point
         )
         {
            return false;
         }


         ResetLastError();


         bool requestResult =
            m_trade.PositionModify(
               ticket,
               newSL,
               currentTP
            );


         uint retcode =
            m_trade.ResultRetcode();


         if(
            requestResult &&
            IsModificationSuccess()
         )
         {
            PrintFormat(
               "[PositionManager] "
               "BREAKEVEN | "
               "Ticket=%I64u | "
               "Symbol=%s | "
               "SL=%s | "
               "Profit=%.1f pts | "
               "Retcode=%I64u | "
               "%s",
               ticket,
               symbol,
               DoubleToString(
                  newSL,
                  digits
               ),
               profitPoints,
               retcode,
               m_trade.ResultRetcodeDescription()
            );

            return true;
         }


         PrintFormat(
            "[PositionManager] "
            "BREAKEVEN FAILED | "
            "Ticket=%I64u | "
            "Symbol=%s | "
            "SL=%s | "
            "Profit=%.1f pts | "
            "Request=%s | "
            "Retcode=%I64u | "
            "%s | "
            "Error=%d",
            ticket,
            symbol,
            DoubleToString(
               newSL,
               digits
            ),
            profitPoints,
            requestResult ? "true" : "false",
            retcode,
            m_trade.ResultRetcodeDescription(),
            GetLastError()
         );

         return false;
      }


      return false;
   }


   //=================================================================
   // TRAILING
   //=================================================================

   bool ApplyTrailing(
      const ulong ticket,
      const double startPoints,
      const double distancePoints
   )
   {
      if(
         !PositionSelectByTicket(
            ticket
         )
      )
      {
         return false;
      }


      string symbol =
         PositionGetString(
            POSITION_SYMBOL
         );


      if(symbol == "")
         return false;


      long type =
         PositionGetInteger(
            POSITION_TYPE
         );


      double openPrice =
         PositionGetDouble(
            POSITION_PRICE_OPEN
         );


      double currentSL =
         PositionGetDouble(
            POSITION_SL
         );


      double currentTP =
         PositionGetDouble(
            POSITION_TP
         );


      double point =
         SymbolInfoDouble(
            symbol,
            SYMBOL_POINT
         );


      if(point <= 0.0)
         return false;


      if(openPrice <= 0.0)
         return false;


      if(distancePoints <= 0.0)
         return false;


      double minimumDistance =
         GetMinStopDistance(
            symbol
         );


      int digits =
         (int)SymbolInfoInteger(
            symbol,
            SYMBOL_DIGITS
         );


      //==============================================================
      // BUY
      //==============================================================

      if(
         type ==
         POSITION_TYPE_BUY
      )
      {
         double bid =
            SymbolInfoDouble(
               symbol,
               SYMBOL_BID
            );


         if(bid <= 0.0)
            return false;


         double profitPoints =
            (
               bid -
               openPrice
            ) / point;


         if(
            profitPoints <
            startPoints
         )
         {
            return false;
         }


         double newSL =
            NormalizeDouble(
               bid -
               distancePoints * point,
               digits
            );


         if(
            !IsValidBuySL(
               symbol,
               bid,
               newSL,
               minimumDistance
            )
         )
         {
            return false;
         }


         //===========================================================
         // TRAILING SOMENTE PARA FRENTE
         //===========================================================

         if(
            currentSL != 0.0 &&
            newSL <= currentSL + point
         )
         {
            return false;
         }


         ResetLastError();


         bool requestResult =
            m_trade.PositionModify(
               ticket,
               newSL,
               currentTP
            );


         uint retcode =
            m_trade.ResultRetcode();


         if(
            requestResult &&
            IsModificationSuccess()
         )
         {
            PrintFormat(
               "[PositionManager] "
               "TRAILING | "
               "Ticket=%I64u | "
               "Symbol=%s | "
               "SL=%s | "
               "Profit=%.1f pts | "
               "Retcode=%I64u | "
               "%s",
               ticket,
               symbol,
               DoubleToString(
                  newSL,
                  digits
               ),
               profitPoints,
               retcode,
               m_trade.ResultRetcodeDescription()
            );

            return true;
         }


         PrintFormat(
            "[PositionManager] "
            "TRAILING FAILED | "
            "Ticket=%I64u | "
            "Symbol=%s | "
            "SL=%s | "
            "Profit=%.1f pts | "
            "Request=%s | "
            "Retcode=%I64u | "
            "%s | "
            "Error=%d",
            ticket,
            symbol,
            DoubleToString(
               newSL,
               digits
            ),
            profitPoints,
            requestResult ? "true" : "false",
            retcode,
            m_trade.ResultRetcodeDescription(),
            GetLastError()
         );

         return false;
      }


      //==============================================================
      // SELL
      //==============================================================

      if(
         type ==
         POSITION_TYPE_SELL
      )
      {
         double ask =
            SymbolInfoDouble(
               symbol,
               SYMBOL_ASK
            );


         if(ask <= 0.0)
            return false;


         double profitPoints =
            (
               openPrice -
               ask
            ) / point;


         if(
            profitPoints <
            startPoints
         )
         {
            return false;
         }


         double newSL =
            NormalizeDouble(
               ask +
               distancePoints * point,
               digits
            );


         if(
            !IsValidSellSL(
               symbol,
               ask,
               newSL,
               minimumDistance
            )
         )
         {
            return false;
         }


         //===========================================================
         // TRAILING SOMENTE PARA FRENTE
         //===========================================================

         if(
            currentSL != 0.0 &&
            newSL >= currentSL - point
         )
         {
            return false;
         }


         ResetLastError();


         bool requestResult =
            m_trade.PositionModify(
               ticket,
               newSL,
               currentTP
            );


         uint retcode =
            m_trade.ResultRetcode();


         if(
            requestResult &&
            IsModificationSuccess()
         )
         {
            PrintFormat(
               "[PositionManager] "
               "TRAILING | "
               "Ticket=%I64u | "
               "Symbol=%s | "
               "SL=%s | "
               "Profit=%.1f pts | "
               "Retcode=%I64u | "
               "%s",
               ticket,
               symbol,
               DoubleToString(
                  newSL,
                  digits
               ),
               profitPoints,
               retcode,
               m_trade.ResultRetcodeDescription()
            );

            return true;
         }


         PrintFormat(
            "[PositionManager] "
            "TRAILING FAILED | "
            "Ticket=%I64u | "
            "Symbol=%s | "
            "SL=%s | "
            "Profit=%.1f pts | "
            "Request=%s | "
            "Retcode=%I64u | "
            "%s | "
            "Error=%d",
            ticket,
            symbol,
            DoubleToString(
               newSL,
               digits
            ),
            profitPoints,
            requestResult ? "true" : "false",
            retcode,
            m_trade.ResultRetcodeDescription(),
            GetLastError()
         );

         return false;
      }


      return false;
   }


   //=================================================================
   // TIME EXIT
   //=================================================================

   bool ApplyTimeExit(
      const ulong ticket
   )
   {
      if(
         m_maxHoldingSeconds <= 0
      )
      {
         return false;
      }


      if(
         !PositionSelectByTicket(
            ticket
         )
      )
      {
         return false;
      }


      datetime openTime =
         (datetime)PositionGetInteger(
            POSITION_TIME
         );


      if(openTime <= 0)
         return false;


      datetime now =
         TimeCurrent();


      if(now <= 0)
         return false;


      long holdingSeconds =
         (long)(
            now -
            openTime
         );


      if(
         holdingSeconds <
         m_maxHoldingSeconds
      )
      {
         return false;
      }


      string symbol =
         PositionGetString(
            POSITION_SYMBOL
         );


      long type =
         PositionGetInteger(
            POSITION_TYPE
         );


      double openPrice =
         PositionGetDouble(
            POSITION_PRICE_OPEN
         );


      ResetLastError();


      bool requestResult =
         m_trade.PositionClose(
            ticket
         );


      uint retcode =
         m_trade.ResultRetcode();


      if(
         requestResult &&
         IsCloseSuccess()
      )
      {
         PrintFormat(
            "[PositionManager] "
            "TIME EXIT | "
            "Ticket=%I64u | "
            "Symbol=%s | "
            "Type=%s | "
            "Open=%s | "
            "Holding=%d sec | "
            "Retcode=%I64u | "
            "%s",
            ticket,
            symbol,
            (
               type == POSITION_TYPE_BUY
               ? "BUY"
               : "SELL"
            ),
            DoubleToString(
               openPrice,
               (int)SymbolInfoInteger(
                  symbol,
                  SYMBOL_DIGITS
               )
            ),
            (int)holdingSeconds,
            retcode,
            m_trade.ResultRetcodeDescription()
         );

         return true;
      }


      PrintFormat(
         "[PositionManager] "
         "TIME EXIT FAILED | "
         "Ticket=%I64u | "
         "Symbol=%s | "
         "Holding=%d sec | "
         "Request=%s | "
         "Retcode=%I64u | "
         "%s | "
         "Error=%d",
         ticket,
         symbol,
         (int)holdingSeconds,
         requestResult ? "true" : "false",
         retcode,
         m_trade.ResultRetcodeDescription(),
         GetLastError()
      );


      return false;
   }


public:

   //=================================================================
   // CONSTRUCTOR
   //=================================================================

   PositionManager(
      const double breakEvenTriggerPoints = 150.0,
      const double breakEvenOffsetPoints  = 10.0,
      const double trailingStartPoints    = 200.0,
      const double trailingStepPoints     = 100.0,
      const int    maxHoldingSeconds      = 86400,
      const bool   useATR                 = true,
      const double beTriggerATRMult       = 1.0,
      const double beOffsetATRMult        = 0.25,
      const double trailStartATRMult      = 1.0,
      const double trailDistATRMult       = 1.0
   )
   {
      m_breakEvenTriggerPoints =
         MathMax(
            0.0,
            breakEvenTriggerPoints
         );


      m_breakEvenOffsetPoints =
         MathMax(
            0.0,
            breakEvenOffsetPoints
         );


      m_trailingStartPoints =
         MathMax(
            0.0,
            trailingStartPoints
         );


      m_trailingStepPoints =
         MathMax(
            0.0,
            trailingStepPoints
         );


      m_maxHoldingSeconds =
         MathMax(
            0,
            maxHoldingSeconds
         );


      m_useATR =
         useATR;


      m_beTriggerATRMult =
         MathMax(
            0.0,
            beTriggerATRMult
         );


      m_beOffsetATRMult =
         MathMax(
            0.0,
            beOffsetATRMult
         );


      m_trailStartATRMult =
         MathMax(
            0.0,
            trailStartATRMult
         );


      m_trailDistATRMult =
         MathMax(
            0.0,
            trailDistATRMult
         );


      m_atrHandle =
         INVALID_HANDLE;


      m_atrSymbol =
         "";


      m_atrTF =
         PERIOD_CURRENT;
   }


   //=================================================================
   // DESTRUCTOR
   //=================================================================

   ~PositionManager()
   {
      if(
         m_atrHandle !=
         INVALID_HANDLE
      )
      {
         IndicatorRelease(
            m_atrHandle
         );

         m_atrHandle =
            INVALID_HANDLE;
      }
   }


   //=================================================================
   // MANAGE OPEN POSITIONS
   //
   // IMPORTANTE:
   //
   // O PositionManager só administra posições existentes.
   //
   // Não abre posição.
   // Não decide direção.
   // Não calcula lote.
   // Não aplica política SINGLE/HEDGE.
   //
   // A filtragem aqui é:
   //
   //     Symbol + Magic
   //
   //=================================================================

   void ManageOpenPositions(
      const AnalysisContext &ctx
   )
   {
      string contextSymbol =
         ctx.symbol;


      if(contextSymbol == "")
         return;


      ulong magic =
         GetEffectiveMagic(
            ctx
         );


      //==============================================================
      // TIMEFRAME DO CONTEXTO
      //==============================================================

      ENUM_TIMEFRAMES contextTF =
         ctx.primaryTF;


      if(contextTF == PERIOD_CURRENT)
      {
         contextTF =
            (ENUM_TIMEFRAMES)_Period;
      }


      //==============================================================
      // CONFIGURAÇÃO BASE DO CTRADE
      //==============================================================

      m_trade.SetExpertMagicNumber(
         magic
      );


      int deviation =
         ctx.slippage;


      if(deviation <= 0)
      {
         deviation =
            ASTRA_DEFAULT_SLIPPAGE;
      }


      m_trade.SetDeviationInPoints(
         deviation
      );


      //==============================================================
      // NENHUMA POSIÇÃO
      //==============================================================

      int total =
         PositionsTotal();


      if(total <= 0)
         return;


      //==============================================================
      // PERCORRE POSIÇÕES
      //
      // IMPORTANTE:
      //
      // O ticket é capturado antes de qualquer operação.
      // Isso evita depender do índice após uma modificação/
      // fechamento.
      //==============================================================

      for(
         int i = total - 1;
         i >= 0;
         i--
      )
      {
         ulong ticket =
            PositionGetTicket(i);


         if(ticket == 0)
            continue;


         if(
            !PositionSelectByTicket(
               ticket
            )
         )
         {
            continue;
         }


         //===========================================================
         // MAGIC
         //===========================================================

         if(
            !IsOwnPosition(
               magic
            )
         )
         {
            continue;
         }


         //===========================================================
         // SÍMBOLO
         //
         // PositionManager deve operar somente no símbolo do contexto.
         //===========================================================

         if(
            !IsOwnPositionForContext(
               ctx
            )
         )
         {
            continue;
         }


         string symbol =
            PositionGetString(
               POSITION_SYMBOL
            );


         if(symbol == "")
            continue;


         //===========================================================
         // CONFIGURAÇÃO CTRADE PARA O SÍMBOLO REAL
         //===========================================================

         ConfigureTradeForPosition(
            ctx,
            symbol
         );


         //===========================================================
         // ATR
         //===========================================================

         if(m_useATR)
         {
            EnsureATR(
               symbol,
               contextTF
            );
         }


         //===========================================================
         // TIME EXIT PRIMEIRO
         //
         // Se a posição foi fechada:
         // não executar BE/trailing.
         //===========================================================

         if(
            ApplyTimeExit(
               ticket
            )
         )
         {
            continue;
         }


         //===========================================================
         // RESELECIONA
         //===========================================================

         if(
            !PositionSelectByTicket(
               ticket
            )
         )
         {
            continue;
         }


         //===========================================================
         // GARANTE NOVAMENTE QUE CONTINUA SENDO POSIÇÃO DO ASTRA
         //===========================================================

         if(
            !IsOwnPosition(
               magic
            )
         )
         {
            continue;
         }


         if(
            !IsOwnPositionForContext(
               ctx
            )
         )
         {
            continue;
         }


         //===========================================================
         // DISTÂNCIAS EFETIVAS
         //===========================================================

         double beTrigger =
            0.0;

         double beOffset =
            0.0;

         double trailStart =
            0.0;

         double trailDist =
            0.0;


         GetEffectiveDistances(
            symbol,
            beTrigger,
            beOffset,
            trailStart,
            trailDist
         );


         //===========================================================
         // BREAK EVEN
         //===========================================================

         bool breakEvenApplied =
            ApplyBreakEven(
               ticket,
               beTrigger,
               beOffset
            );


         //===========================================================
         // RESELECIONA APÓS BE
         //
         // A posição pode ter sido modificada ou, em condições
         // excepcionais, alterada pelo servidor.
         //===========================================================

         if(
            !PositionSelectByTicket(
               ticket
            )
         )
         {
            continue;
         }


         if(
            !IsOwnPosition(
               magic
            )
         )
         {
            continue;
         }


         if(
            !IsOwnPositionForContext(
               ctx
            )
         )
         {
            continue;
         }


         //===========================================================
         // TRAILING
         //
         // O trailing possui proteção própria contra regressão de SL.
         // Portanto pode ser chamado após o BE sem risco de piorar
         // a proteção.
         //===========================================================

         ApplyTrailing(
            ticket,
            trailStart,
            trailDist
         );
      }
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_POSITIONMANAGER_MQH