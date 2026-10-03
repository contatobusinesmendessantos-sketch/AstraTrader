//+------------------------------------------------------------------+
//| StatisticsEngine.mqh                                             |
//| Astra Trader AI                                                  |
//|                                                                  |
//| Estágio 17a - Statistics Engine                                  |
//|                                                                  |
//| Responsabilidades:                                               |
//| - registrar resultados de trades                                 |
//| - calcular win rate                                               |
//| - calcular expectancy                                             |
//| - calcular RR médio                                               |
//| - acompanhar lucro acumulado                                      |
//| - acompanhar drawdown                                             |
//| - fornecer score para otimização                                  |
//|                                                                  |
//| IMPORTANTE:                                                       |
//| - NÃO executa ordens                                             |
//| - NÃO decide BUY/SELL                                            |
//| - NÃO altera risco                                                |
//+------------------------------------------------------------------+
#ifndef ASTRA_STATISTICSENGINE_MQH
#define ASTRA_STATISTICSENGINE_MQH

#property strict


//+------------------------------------------------------------------+
//| StatisticsEngine                                                 |
//+------------------------------------------------------------------+
class StatisticsEngine
{
private:

   //=================================================================
   // TRADE COUNTERS
   //=================================================================

   ulong m_totalTrades;
   ulong m_winningTrades;
   ulong m_losingTrades;


   //=================================================================
   // PERFORMANCE
   //=================================================================

   double m_totalProfit;
   double m_totalLoss;

   double m_totalRR;
   double m_averageRR;

   double m_expectancy;


   //=================================================================
   // EQUITY / DRAWDOWN
   //=================================================================

   double m_equityCurve;
   double m_peakEquity;

   double m_currentDrawdown;
   double m_maxDrawdown;


   //=================================================================
   // LAST RESULT
   //=================================================================

   double m_lastProfit;
   double m_lastRR;
   double m_lastDrawdown;


   //=================================================================
   // INITIALIZATION
   //=================================================================

   bool m_initialized;


   //=================================================================
   // RECALCULATE EXPECTANCY
   //=================================================================

   void RecalculateExpectancy()
   {
      if(m_totalTrades == 0)
      {
         m_expectancy =
            0.0;

         return;
      }


      double winRate =
         (
            double)m_winningTrades /
            (double)m_totalTrades;


      double lossRate =
         (
            double)m_losingTrades /
            (double)m_totalTrades;


      double averageWin =
         0.0;

      double averageLoss =
         0.0;


      if(m_winningTrades > 0)
      {
         averageWin =
            m_totalProfit /
            (double)m_winningTrades;
      }


      if(m_losingTrades > 0)
      {
         averageLoss =
            m_totalLoss /
            (double)m_losingTrades;
      }


      m_expectancy =
         (
            winRate *
            averageWin
         ) -
         (
            lossRate *
            averageLoss
         );
   }


public:

   //=================================================================
   // CONSTRUCTOR
   //=================================================================

   StatisticsEngine()
   {
      Reset();
   }


   //=================================================================
   // RESET
   //=================================================================

   void Reset()
   {
      m_totalTrades =
         0;

      m_winningTrades =
         0;

      m_losingTrades =
         0;


      m_totalProfit =
         0.0;

      m_totalLoss =
         0.0;


      m_totalRR =
         0.0;

      m_averageRR =
         0.0;


      m_expectancy =
         0.0;


      m_equityCurve =
         0.0;

      m_peakEquity =
         0.0;

      m_currentDrawdown =
         0.0;

      m_maxDrawdown =
         0.0;


      m_lastProfit =
         0.0;

      m_lastRR =
         0.0;

      m_lastDrawdown =
         0.0;


      m_initialized =
         true;
   }


   //=================================================================
   // REGISTER TRADE RESULT
   //=================================================================

   void RegisterTradeResult(
      const double profit,
      const double rr,
      const double drawdown
   )
   {
      if(!m_initialized)
         Reset();


      if(!MathIsValidNumber(profit))
         return;


      if(!MathIsValidNumber(rr))
         return;


      if(!MathIsValidNumber(drawdown))
         return;


      //==============================================================
      // TRADE COUNT
      //==============================================================

      m_totalTrades++;


      //==============================================================
      // WIN / LOSS
      //==============================================================

      if(profit > 0.0)
      {
         m_winningTrades++;

         m_totalProfit +=
            profit;
      }
      else
      if(profit < 0.0)
      {
         m_losingTrades++;

         m_totalLoss +=
            MathAbs(profit);
      }


      //==============================================================
      // RR
      //==============================================================

      if(rr > 0.0)
      {
         m_totalRR +=
            rr;
      }

      m_averageRR =
         m_totalRR /
         (double)m_totalTrades;


      //==============================================================
      // EQUITY CURVE
      //==============================================================

      m_equityCurve +=
         profit;


      //==============================================================
      // PEAK EQUITY
      //==============================================================

      if(
         m_totalTrades == 1 ||
         m_equityCurve >
         m_peakEquity
      )
      {
         m_peakEquity =
            m_equityCurve;
      }


      //==============================================================
      // DRAWDOWN DA CURVA
      //==============================================================

      m_currentDrawdown =
         m_peakEquity -
         m_equityCurve;


      if(m_currentDrawdown < 0.0)
         m_currentDrawdown =
            0.0;


      //==============================================================
      // DRAWDOWN EXTERNO
      //==============================================================

      if(drawdown > m_currentDrawdown)
      {
         m_currentDrawdown =
            drawdown;
      }


      if(
         m_currentDrawdown >
         m_maxDrawdown
      )
      {
         m_maxDrawdown =
            m_currentDrawdown;
      }


      //==============================================================
      // LAST RESULT
      //==============================================================

      m_lastProfit =
         profit;

      m_lastRR =
         rr;

      m_lastDrawdown =
         drawdown;


      //==============================================================
      // EXPECTANCY
      //==============================================================

      RecalculateExpectancy();
   }


   //=================================================================
   // WIN RATE
   //=================================================================

   double GetWinRate() const
   {
      if(m_totalTrades == 0)
         return 0.0;

      return
         (
            (
               double)m_winningTrades /
               (double)m_totalTrades
            ) *
         100.0;
   }


   //=================================================================
   // EXPECTANCY
   //=================================================================

   double GetExpectancy() const
   {
      return m_expectancy;
   }


   //=================================================================
   // AVERAGE RR
   //=================================================================

   double GetAverageRR() const
   {
      return m_averageRR;
   }


   //=================================================================
   // TOTAL TRADES
   //=================================================================

   ulong GetTotalTrades() const
   {
      return m_totalTrades;
   }


   //=================================================================
   // WINNING TRADES
   //=================================================================

   ulong GetWinningTrades() const
   {
      return m_winningTrades;
   }


   //=================================================================
   // LOSING TRADES
   //=================================================================

   ulong GetLosingTrades() const
   {
      return m_losingTrades;
   }


   //=================================================================
   // TOTAL PROFIT
   //=================================================================

   double GetTotalProfit() const
   {
      return m_totalProfit;
   }


   //=================================================================
   // TOTAL LOSS
   //=================================================================

   double GetTotalLoss() const
   {
      return m_totalLoss;
   }


   //=================================================================
   // NET PROFIT
   //=================================================================

   double GetNetProfit() const
   {
      return
         m_totalProfit -
         m_totalLoss;
   }


   //=================================================================
   // EQUITY CURVE
   //=================================================================

   double GetEquityCurve() const
   {
      return m_equityCurve;
   }


   //=================================================================
   // PEAK EQUITY
   //=================================================================

   double GetPeakEquity() const
   {
      return m_peakEquity;
   }


   //=================================================================
   // CURRENT DRAWDOWN
   //=================================================================

   double GetCurrentDrawdown() const
   {
      return m_currentDrawdown;
   }


   //=================================================================
   // MAX DRAWDOWN
   //=================================================================

   double GetMaxDrawdown() const
   {
      return m_maxDrawdown;
   }


   //=================================================================
   // LAST PROFIT
   //=================================================================

   double GetLastProfit() const
   {
      return m_lastProfit;
   }


   //=================================================================
   // LAST RR
   //=================================================================

   double GetLastRR() const
   {
      return m_lastRR;
   }


   //=================================================================
   // LAST DRAWDOWN
   //=================================================================

   double GetLastDrawdown() const
   {
      return m_lastDrawdown;
   }


   //=================================================================
   // OPTIMIZATION SCORE
   //=================================================================

   double GetOptimizationScore() const
   {
      if(m_totalTrades == 0)
         return 0.0;


      double score =
         m_expectancy;


      if(m_maxDrawdown > 0.0)
      {
         score =
            score /
            (
               1.0 +
               m_maxDrawdown
            );
      }


      return score;
   }


   //=================================================================
   // STATUS
   //=================================================================

   bool IsInitialized() const
   {
      return m_initialized;
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_STATISTICSENGINE_MQH
//+------------------------------------------------------------------+