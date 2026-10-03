//+------------------------------------------------------------------+
//| AstraQuantEngine.mqh                                             |
//| Astra Trader AI                                                  |
//|                                                                  |
//| Engine quantitativa auxiliar do pipeline.                       |
//+------------------------------------------------------------------+
#ifndef ASTRA_QUANT_ENGINE_MQH
#define ASTRA_QUANT_ENGINE_MQH

#include <AstraTrader\Analysis\AnalysisContext.mqh>
#define ASTRA_BTC_XAU_HISTORY_CAPACITY 128
#define ASTRA_BTC_XAU_ALIGNMENT_SECONDS 60
#define ASTRA_BTC_XAU_CORRELATION_WINDOW 30
#define ASTRA_BTC_XAU_LAGGED_WINDOW 40

#define ASTRA_BTC_HISTORY_CAPACITY 128
#define ASTRA_BTC_MOMENTUM_FAST    5
#define ASTRA_BTC_MOMENTUM_SLOW    20
#define ASTRA_BTC_VOLATILITY_FAST  20
#define ASTRA_BTC_VOLATILITY_SLOW  60
#define ASTRA_BTC_ZSCORE_WINDOW    20
#define ASTRA_BTC_ZSCORE_EPSILON   1e-12
#define ASTRA_BTC_ZSCORE_HARD_LIMIT 6.0


struct AstraBtcPriceObservation
{
   datetime timestamp;
   double   price;
};

struct AstraBtcXauObservation
{
   datetime timestamp;
   double   btcPrice;
   double   xauPrice;
};


struct AstraQuantResult
{
   bool   valid;
   bool   hasData;
   string error;

   double correlation30D;
   double rSquared;
   double slope;
   double zScore;
   double percentile;
   double velocity;
   double acceleration;
   double divergence;
   double laggedCorrelation;
   double confidence;

   bool   btcQuantDataValid;
   bool   btcReturnValid;
   double btcReturn;
   double btcMomentumFast;
   double btcMomentumSlow;
   double btcAcceleration;
   double btcVolatility20;
   double btcVolatility60;
   double btcVolatilityRatio;
   double btcZScore;
   bool   btcZScoreValid;
   string btcZScoreState;
   int    btcZScoreWindow;
   double btcZScoreMean;
   double btcZScoreStdDev;
   double btcPercentile;
   bool   btcPercentileValid;
   int    btcHistorySize;
   bool   btcXauCorrelationValid;
   double btcXauCorrelation30;
   int    btcXauHistorySize;
   string btcXauError;
   bool   btcXauLaggedCorrelationValid;
   double btcXauCorrLag1;
   double btcXauCorrLag2;
   double btcXauCorrLag3;
   double btcXauCorrLag5;
   int    btcXauBestLag;
   double btcXauBestLagCorrelation;
   bool   btcXauDivergenceValid;
   string btcXauDivergence;
   double btcXauDivergenceBtcReturn;
   double btcXauDivergenceXauReturn;
   double btcXauDivergenceBtcThreshold;
   double btcXauDivergenceXauThreshold;
   bool   btcRegimeValid;
   string btcRegime;
   bool   btcQuantScoreValid;
   double btcMomentumContribution;
   double btcZScoreContribution;
   double btcAccelerationContribution;
   double btcPercentileContribution;
   double btcCorrelationContribution;
   double btcDivergenceContribution;
   double btcQuantScore;

   void Reset()
   {
      valid = false;
      hasData = false;
      error = "";

      correlation30D = 0.0;
      rSquared = 0.0;
      slope = 0.0;
      zScore = 0.0;
      percentile = 0.0;
      velocity = 0.0;
      acceleration = 0.0;
      divergence = 0.0;
      laggedCorrelation = 0.0;
      confidence = 0.0;

      btcQuantDataValid = false;
      btcReturnValid = false;
      btcReturn = 0.0;
      btcMomentumFast = 0.0;
      btcMomentumSlow = 0.0;
      btcAcceleration = 0.0;
      btcVolatility20 = 0.0;
      btcVolatility60 = 0.0;
      btcVolatilityRatio = 0.0;
      btcZScore = 0.0;
      btcZScoreValid = false;
      btcZScoreState = "INVALID";
      btcZScoreWindow = ASTRA_BTC_ZSCORE_WINDOW;
      btcZScoreMean = 0.0;
      btcZScoreStdDev = 0.0;
      btcPercentile = 0.0;
      btcPercentileValid = false;
      btcHistorySize = 0;
      btcXauCorrelationValid = false;
      btcXauCorrelation30 = 0.0;
      btcXauHistorySize = 0;
      btcXauError = "";
      btcXauLaggedCorrelationValid = false;
      btcXauCorrLag1 = 0.0;
      btcXauCorrLag2 = 0.0;
      btcXauCorrLag3 = 0.0;
      btcXauCorrLag5 = 0.0;
      btcXauBestLag = 0;
      btcXauBestLagCorrelation = 0.0;
      btcXauDivergenceValid = false;
      btcXauDivergence = "INVALID";
      btcXauDivergenceBtcReturn = 0.0;
      btcXauDivergenceXauReturn = 0.0;
      btcXauDivergenceBtcThreshold = 0.0;
      btcXauDivergenceXauThreshold = 0.0;
      btcRegimeValid = false;
      btcRegime = "UNAVAILABLE";
      btcQuantScoreValid = false;
      btcMomentumContribution = 0.0;
      btcZScoreContribution = 0.0;
      btcAccelerationContribution = 0.0;
      btcPercentileContribution = 0.0;
      btcCorrelationContribution = 0.0;
      btcDivergenceContribution = 0.0;
      btcQuantScore = 0.0;
   }
};


class AstraQuantEngine
{
private:

   bool m_initialized;
   AstraBtcPriceObservation m_history[];
   AstraBtcXauObservation m_btcXauHistory[];


   bool IsValidPrice(const double price) const
   {
      return (
         price > 0.0 &&
         MathIsValidNumber(price)
      );
   }


   bool AppendObservation(
      const datetime timestamp,
      const double price,
      string &error
   )
   {
      if(timestamp <= 0)
      {
         error = "BTC_TIMESTAMP_INVALID";
         return false;
      }

      if(!IsValidPrice(price))
      {
         error = "BTC_PRICE_INVALID";
         return false;
      }

      int count = ArraySize(m_history);

      if(count > 0)
      {
         const datetime lastTimestamp =
            m_history[count - 1].timestamp;

         if(timestamp < lastTimestamp)
         {
            error = "BTC_TIMESTAMP_OUT_OF_ORDER";
            return false;
         }

         if(timestamp == lastTimestamp)
         {
            if(price != m_history[count - 1].price)
            {
               error = "BTC_TIMESTAMP_DUPLICATE";
               return false;
            }

            return true;
         }
      }

      if(count >= ASTRA_BTC_HISTORY_CAPACITY)
      {
         for(int index = 1; index < count; index++)
            m_history[index - 1] = m_history[index];

         count--;
         ArrayResize(m_history, count);
      }

      ArrayResize(m_history, count + 1);
      m_history[count].timestamp = timestamp;
      m_history[count].price = price;
      return true;
   }


   bool AppendBtcXauObservation(
      const datetime timestamp,
      const double btcPrice,
      const double xauPrice,
      string &error
   )
   {
      if(timestamp <= 0)
      {
         error = "BTC_XAU_TIMESTAMP_INVALID";
         return false;
      }

      if(!IsValidPrice(btcPrice) || !IsValidPrice(xauPrice))
      {
         error = "BTC_XAU_PRICE_INVALID";
         return false;
      }

      int count = ArraySize(m_btcXauHistory);

      if(count > 0)
      {
         const datetime lastTimestamp =
            m_btcXauHistory[count - 1].timestamp;

         if(timestamp < lastTimestamp)
         {
            error = "BTC_XAU_TIMESTAMP_OUT_OF_ORDER";
            return false;
         }

         if(timestamp == lastTimestamp)
            return true;
      }

      if(count >= ASTRA_BTC_XAU_HISTORY_CAPACITY)
      {
         for(int index = 1; index < count; index++)
            m_btcXauHistory[index - 1] = m_btcXauHistory[index];

         count--;
         ArrayResize(m_btcXauHistory, count);
      }

      ArrayResize(m_btcXauHistory, count + 1);
      m_btcXauHistory[count].timestamp = timestamp;
      m_btcXauHistory[count].btcPrice = btcPrice;
      m_btcXauHistory[count].xauPrice = xauPrice;
      return true;
   }


   bool BuildReturns(
      double &returns[],
      string &error
   ) const
   {
      int priceCount = ArraySize(m_history);

      if(priceCount < 2)
      {
         error = "BTC_INSUFFICIENT_PRICES_FOR_RETURN";
         return false;
      }

      ArrayResize(returns, priceCount - 1);

      for(int index = 1; index < priceCount; index++)
      {
         const double previousPrice =
            m_history[index - 1].price;
         const double currentPrice =
            m_history[index].price;

         if(!IsValidPrice(previousPrice) || !IsValidPrice(currentPrice))
         {
            error = "BTC_INVALID_PRICE_IN_RETURN_SERIES";
            return false;
         }

         const double value =
            MathLog(currentPrice / previousPrice);

         if(!MathIsValidNumber(value))
         {
            error = "BTC_INVALID_RETURN";
            return false;
         }

         returns[index - 1] = value;
      }

      return true;
   }


   bool CalculateStdDev(
      const double &values[],
      const int start,
      const int count,
      const bool sample,
      double &mean,
      double &stdDev
   ) const
   {
      if(count < 1 || (sample && count < 2))
         return false;

      mean = 0.0;

      for(int index = start; index < start + count; index++)
         mean += values[index];

      mean /= count;

      double sumSquared = 0.0;

      for(int index = start; index < start + count; index++)
      {
         const double delta = values[index] - mean;
         sumSquared += delta * delta;
      }

      const int denominator = sample ? count - 1 : count;
      stdDev = MathSqrt(sumSquared / denominator);

      return MathIsValidNumber(stdDev);
   }


   bool CalculatePearson(
      const double &btcReturns[],
      const double &xauReturns[],
      const int start,
      const int count,
      double &correlation
   ) const
   {
      if(
         count < ASTRA_BTC_XAU_CORRELATION_WINDOW ||
         ArraySize(btcReturns) < start + count ||
         ArraySize(xauReturns) < start + count
      )
      {
         return false;
      }

      double btcMean = 0.0;
      double xauMean = 0.0;

      for(int index = start; index < start + count; index++)
      {
         btcMean += btcReturns[index];
         xauMean += xauReturns[index];
      }

      btcMean /= count;
      xauMean /= count;

      double covariance = 0.0;
      double btcVariance = 0.0;
      double xauVariance = 0.0;

      for(int index = start; index < start + count; index++)
      {
         const double btcDelta = btcReturns[index] - btcMean;
         const double xauDelta = xauReturns[index] - xauMean;

         covariance += btcDelta * xauDelta;
         btcVariance += btcDelta * btcDelta;
         xauVariance += xauDelta * xauDelta;
      }

      const double denominator =
         MathSqrt(btcVariance * xauVariance);

      if(denominator <= 0.0 || !MathIsValidNumber(denominator))
         return false;

      correlation = covariance / denominator;

      if(!MathIsValidNumber(correlation))
         return false;

      if(correlation > 1.0)
         correlation = 1.0;
      else
      if(correlation < -1.0)
         correlation = -1.0;

      return true;
   }


   bool CalculateLaggedPearson(
      const double &btcReturns[],
      const double &xauReturns[],
      const int lag,
      double &correlation
   ) const
   {
      const int returnCount = ArraySize(btcReturns);

      if(
         lag <= 0 ||
         returnCount < ASTRA_BTC_XAU_LAGGED_WINDOW + lag ||
         ArraySize(xauReturns) != returnCount
      )
      {
         return false;
      }

      const int xauStart =
         returnCount - ASTRA_BTC_XAU_LAGGED_WINDOW;

      double btcMean = 0.0;
      double xauMean = 0.0;

      for(int index = 0; index < ASTRA_BTC_XAU_LAGGED_WINDOW; index++)
      {
         btcMean += btcReturns[xauStart + index - lag];
         xauMean += xauReturns[xauStart + index];
      }

      btcMean /= ASTRA_BTC_XAU_LAGGED_WINDOW;
      xauMean /= ASTRA_BTC_XAU_LAGGED_WINDOW;

      double covariance = 0.0;
      double btcVariance = 0.0;
      double xauVariance = 0.0;

      for(int index = 0; index < ASTRA_BTC_XAU_LAGGED_WINDOW; index++)
      {
         const double btcDelta =
            btcReturns[xauStart + index - lag] - btcMean;
         const double xauDelta =
            xauReturns[xauStart + index] - xauMean;

         covariance += btcDelta * xauDelta;
         btcVariance += btcDelta * btcDelta;
         xauVariance += xauDelta * xauDelta;
      }

      const double denominator =
         MathSqrt(btcVariance * xauVariance);

      if(denominator <= 0.0 || !MathIsValidNumber(denominator))
         return false;

      correlation = covariance / denominator;

      if(!MathIsValidNumber(correlation))
         return false;

      if(correlation > 1.0)
         correlation = 1.0;
      else
      if(correlation < -1.0)
         correlation = -1.0;

      return true;
   }


   bool CalculatePercentile(
      const double &returns[],
      const int start,
      const int count,
      const double current,
      double &percentile
   ) const
   {
      if(count < ASTRA_BTC_VOLATILITY_SLOW)
         return false;

      int valuesLessOrEqual = 0;

      for(int index = start; index < start + count; index++)
      {
         if(returns[index] <= current)
            valuesLessOrEqual++;
      }

      percentile =
         100.0 * valuesLessOrEqual / count;

      return MathIsValidNumber(percentile);
   }


   string ClassifyZScore(const double zScore) const
   {
      const double absolute = MathAbs(zScore);

      if(absolute > ASTRA_BTC_ZSCORE_HARD_LIMIT)
         return "EXTREME_OUTLIER";

      if(absolute < 1.0)
         return "NORMAL";

      if(absolute < 2.0)
         return "ELEVATED";

      return "EXTREME";
   }


public:

   AstraQuantEngine()
   {
      m_initialized = false;
      ArrayResize(m_history, 0);
      ArrayResize(m_btcXauHistory, 0);
   }


   bool Init()
   {
      m_initialized = true;
      return true;
   }


   bool IsInitialized() const
   {
      return m_initialized;
   }


   bool Calculate(
      const AnalysisContext &context,
      AstraQuantResult &result
   )
   {
      result.Reset();

      if(!m_initialized)
      {
         result.error =
            "AstraQuantEngine not initialized";
         return false;
      }

      if(!context.btcPrice.valid)
      {
         result.error = "BTC_PRICE_INVALID";
         return true;
      }

      if(context.btcPrice.stale)
      {
         result.error = "BTC_PRICE_STALE";
         return true;
      }

      string appendError = "";

      if(!AppendObservation(
         context.btcPrice.timestamp,
         context.btcPrice.btcUsd,
         appendError
      ))
      {
         result.error = appendError;
         return true;
      }

      result.btcHistorySize = ArraySize(m_history);
      result.hasData = result.btcHistorySize > 0;

      double returns[];
      string returnError = "";

      if(!BuildReturns(returns, returnError))
      {
         result.error = returnError;
         return true;
      }

      const int returnCount = ArraySize(returns);
      const int currentIndex = returnCount - 1;
      const double currentReturn = returns[currentIndex];

      result.btcReturn = currentReturn;
      result.btcReturnValid = true;

      if(result.btcHistorySize > ASTRA_BTC_MOMENTUM_FAST)
      {
         result.btcMomentumFast =
            MathLog(
               m_history[result.btcHistorySize - 1].price /
               m_history[result.btcHistorySize - 1 - ASTRA_BTC_MOMENTUM_FAST].price
            );
      }

      if(result.btcHistorySize > ASTRA_BTC_MOMENTUM_SLOW)
      {
         result.btcMomentumSlow =
            MathLog(
               m_history[result.btcHistorySize - 1].price /
               m_history[result.btcHistorySize - 1 - ASTRA_BTC_MOMENTUM_SLOW].price
            );

         result.velocity =
            result.btcMomentumFast / ASTRA_BTC_MOMENTUM_FAST;

         result.btcAcceleration =
            result.velocity -
            result.btcMomentumSlow / ASTRA_BTC_MOMENTUM_SLOW;

         result.acceleration = result.btcAcceleration;
      }

      double mean20 = 0.0;
      double stdDev20 = 0.0;

      if(returnCount >= ASTRA_BTC_VOLATILITY_FAST)
      {
         CalculateStdDev(
            returns,
            returnCount - ASTRA_BTC_VOLATILITY_FAST,
            ASTRA_BTC_VOLATILITY_FAST,
            false,
            mean20,
            stdDev20
         );

         result.btcVolatility20 = stdDev20;
      }

      double mean60 = 0.0;
      double stdDev60 = 0.0;

      if(returnCount >= ASTRA_BTC_VOLATILITY_SLOW)
      {
         CalculateStdDev(
            returns,
            returnCount - ASTRA_BTC_VOLATILITY_SLOW,
            ASTRA_BTC_VOLATILITY_SLOW,
            false,
            mean60,
            stdDev60
         );

         result.btcVolatility60 = stdDev60;

         CalculatePercentile(
            returns,
            returnCount - ASTRA_BTC_VOLATILITY_SLOW,
            ASTRA_BTC_VOLATILITY_SLOW,
            currentReturn,
            result.btcPercentile
         );

         result.btcPercentileValid =
            MathIsValidNumber(result.btcPercentile);

         if(stdDev60 > 0.0)
         {
            result.btcVolatilityRatio =
               result.btcVolatility20 / stdDev60;
         }
      }

      result.btcZScoreWindow = ASTRA_BTC_ZSCORE_WINDOW;

      if(returnCount >= ASTRA_BTC_ZSCORE_WINDOW + 1)
      {
         const int referenceStart =
            currentIndex - ASTRA_BTC_ZSCORE_WINDOW;

         double zMean = 0.0;
         double zStdDev = 0.0;

         if(CalculateStdDev(
            returns,
            referenceStart,
            ASTRA_BTC_ZSCORE_WINDOW,
            true,
            zMean,
            zStdDev
         ))
         {
            result.btcZScoreMean = zMean;
            result.btcZScoreStdDev = zStdDev;

            if(zStdDev > ASTRA_BTC_ZSCORE_EPSILON)
            {
               result.btcZScore =
                  (currentReturn - zMean) / zStdDev;

               result.btcZScoreValid =
                  MathIsValidNumber(result.btcZScore);

               if(result.btcZScoreValid)
               {
                  result.btcZScoreState =
                     ClassifyZScore(result.btcZScore);
               }
            }
         }
      }

      result.btcXauHistorySize =
         ArraySize(m_btcXauHistory);

      if(
         context.barTime <= 0 ||
         !IsValidPrice(context.close)
      )
      {
         result.btcXauError =
            "BTC_XAU_MARKET_DATA_INVALID";
      }
      else
      {
         const int alignmentSeconds =
            (int)MathAbs(
               (double)(context.btcPrice.timestamp - context.barTime)
            );

         if(alignmentSeconds > ASTRA_BTC_XAU_ALIGNMENT_SECONDS)
         {
            result.btcXauError =
               "BTC_XAU_TIMESTAMP_OUTSIDE_ALIGNMENT";
         }
         else
         {
            string pairError = "";

            if(!AppendBtcXauObservation(
               context.barTime,
               context.btcPrice.btcUsd,
               context.close,
               pairError
            ))
            {
               result.btcXauError = pairError;
            }
         }
      }

      result.btcXauHistorySize =
         ArraySize(m_btcXauHistory);

      const int pairCount =
         ArraySize(m_btcXauHistory);

      if(pairCount >= ASTRA_BTC_XAU_CORRELATION_WINDOW + 1)
      {
         double btcReturns[];
         double xauReturns[];

         ArrayResize(btcReturns, pairCount - 1);
         ArrayResize(xauReturns, pairCount - 1);

         bool pairReturnsValid = true;

         for(int index = 1; index < pairCount; index++)
         {
            const double btcPrevious =
               m_btcXauHistory[index - 1].btcPrice;
            const double btcCurrent =
               m_btcXauHistory[index].btcPrice;
            const double xauPrevious =
               m_btcXauHistory[index - 1].xauPrice;
            const double xauCurrent =
               m_btcXauHistory[index].xauPrice;

            if(
               !IsValidPrice(btcPrevious) ||
               !IsValidPrice(btcCurrent) ||
               !IsValidPrice(xauPrevious) ||
               !IsValidPrice(xauCurrent)
            )
            {
               pairReturnsValid = false;
               break;
            }

            btcReturns[index - 1] =
               MathLog(btcCurrent / btcPrevious);

            xauReturns[index - 1] =
               MathLog(xauCurrent / xauPrevious);

            if(
               !MathIsValidNumber(btcReturns[index - 1]) ||
               !MathIsValidNumber(xauReturns[index - 1])
            )
            {
               pairReturnsValid = false;
               break;
            }
         }

         if(pairReturnsValid)
         {
            double correlation = 0.0;

            if(CalculatePearson(
               btcReturns,
               xauReturns,
               pairCount - 1 - ASTRA_BTC_XAU_CORRELATION_WINDOW,
               ASTRA_BTC_XAU_CORRELATION_WINDOW,
               correlation
            ))
            {
               result.btcXauCorrelation30 = correlation;
               result.correlation30D = correlation;
               result.btcXauCorrelationValid = true;
            }
            else
            {
               result.btcXauError =
                  "BTC_XAU_CORRELATION_INVALID";
            }

            double lagCorrelation = 0.0;
            bool anyLagValid = false;
            double bestAbsoluteCorrelation = -1.0;

            if(CalculateLaggedPearson(
               btcReturns,
               xauReturns,
               1,
               lagCorrelation
            ))
            {
               result.btcXauCorrLag1 = lagCorrelation;
               anyLagValid = true;
               bestAbsoluteCorrelation = MathAbs(lagCorrelation);
               result.btcXauBestLag = 1;
               result.btcXauBestLagCorrelation = lagCorrelation;
            }

            if(CalculateLaggedPearson(
               btcReturns,
               xauReturns,
               2,
               lagCorrelation
            ))
            {
               result.btcXauCorrLag2 = lagCorrelation;
               anyLagValid = true;

               if(MathAbs(lagCorrelation) > bestAbsoluteCorrelation)
               {
                  bestAbsoluteCorrelation = MathAbs(lagCorrelation);
                  result.btcXauBestLag = 2;
                  result.btcXauBestLagCorrelation = lagCorrelation;
               }
            }

            if(CalculateLaggedPearson(
               btcReturns,
               xauReturns,
               3,
               lagCorrelation
            ))
            {
               result.btcXauCorrLag3 = lagCorrelation;
               anyLagValid = true;

               if(MathAbs(lagCorrelation) > bestAbsoluteCorrelation)
               {
                  bestAbsoluteCorrelation = MathAbs(lagCorrelation);
                  result.btcXauBestLag = 3;
                  result.btcXauBestLagCorrelation = lagCorrelation;
               }
            }

            if(CalculateLaggedPearson(
               btcReturns,
               xauReturns,
               5,
               lagCorrelation
            ))
            {
               result.btcXauCorrLag5 = lagCorrelation;
               anyLagValid = true;

               if(MathAbs(lagCorrelation) > bestAbsoluteCorrelation)
               {
                  bestAbsoluteCorrelation = MathAbs(lagCorrelation);
                  result.btcXauBestLag = 5;
                  result.btcXauBestLagCorrelation = lagCorrelation;
               }
            }

            result.btcXauLaggedCorrelationValid = anyLagValid;
            result.laggedCorrelation =
               result.btcXauBestLagCorrelation;

            double btcMean = 0.0;
            double btcStdDev = 0.0;
            double xauMean = 0.0;
            double xauStdDev = 0.0;

            const int divergenceStart =
               ArraySize(btcReturns) - ASTRA_BTC_XAU_CORRELATION_WINDOW;

            if(
               CalculateStdDev(
                  btcReturns,
                  divergenceStart,
                  ASTRA_BTC_XAU_CORRELATION_WINDOW,
                  false,
                  btcMean,
                  btcStdDev
               ) &&
               CalculateStdDev(
                  xauReturns,
                  divergenceStart,
                  ASTRA_BTC_XAU_CORRELATION_WINDOW,
                  false,
                  xauMean,
                  xauStdDev
               )
            )
            {
               double btcAccumulatedReturn = 0.0;
               double xauAccumulatedReturn = 0.0;

               for(
                  int index = divergenceStart;
                  index < divergenceStart + ASTRA_BTC_XAU_CORRELATION_WINDOW;
                  index++
               )
               {
                  btcAccumulatedReturn += btcReturns[index];
                  xauAccumulatedReturn += xauReturns[index];
               }

               result.btcXauDivergenceBtcReturn =
                  btcAccumulatedReturn;
               result.btcXauDivergenceXauReturn =
                  xauAccumulatedReturn;
               result.btcXauDivergenceBtcThreshold =
                  0.5 * btcStdDev;
               result.btcXauDivergenceXauThreshold =
                  0.5 * xauStdDev;
               result.btcXauDivergence = "NONE";
               result.btcXauDivergenceValid = true;

               if(
                  btcAccumulatedReturn > result.btcXauDivergenceBtcThreshold &&
                  xauAccumulatedReturn < -result.btcXauDivergenceXauThreshold
               )
               {
                  result.btcXauDivergence =
                     "BTC_BULL_XAU_BEAR";
               }
               else
               if(
                  btcAccumulatedReturn < -result.btcXauDivergenceBtcThreshold &&
                  xauAccumulatedReturn > result.btcXauDivergenceXauThreshold
               )
               {
                  result.btcXauDivergence =
                     "BTC_BEAR_XAU_BULL";
               }
            }
         }
         else
         {
            result.btcXauError =
               "BTC_XAU_INVALID_RETURN_SERIES";
         }
      }
      else
      if(result.btcXauError == "")
      {
         result.btcXauError =
            "BTC_XAU_INSUFFICIENT_DATA";
      }

      const bool btcMetricsValid =
         result.btcReturnValid &&
         result.btcZScoreValid &&
         result.btcPercentileValid &&
         result.btcVolatility60 > 0.0 &&
         result.btcVolatilityRatio >= 0.0;

      if(btcMetricsValid)
      {
         result.btcRegimeValid = true;

         if(result.btcVolatilityRatio >= 1.50)
         {
            result.btcRegime = "STRESS";
         }
         else
         if(
            result.btcMomentumSlow > 0.0 &&
            result.btcZScore > 0.0
         )
         {
            result.btcRegime = "BULLISH";
         }
         else
         if(
            result.btcMomentumSlow < 0.0 &&
            result.btcZScore < 0.0
         )
         {
            result.btcRegime = "BEARISH";
         }
         else
         {
            result.btcRegime = "NEUTRAL";
         }

         const double momentumNormalized =
            MathMax(-1.0, MathMin(1.0, result.btcMomentumSlow));
         const double zScoreNormalized =
            MathMax(-1.0, MathMin(1.0, result.btcZScore / 3.0));
         const double accelerationNormalized =
            MathMax(-1.0, MathMin(1.0, result.btcAcceleration));
         const double percentileNormalized =
            MathMax(
               -1.0,
               MathMin(1.0, (result.btcPercentile - 50.0) / 50.0)
            );

         result.btcMomentumContribution =
            momentumNormalized * 30.0;
         result.btcZScoreContribution =
            zScoreNormalized * 20.0;
         result.btcAccelerationContribution =
            accelerationNormalized * 15.0;
         result.btcPercentileContribution =
            percentileNormalized * 15.0;

         if(result.btcXauCorrelationValid)
         {
            result.btcCorrelationContribution =
               result.btcXauCorrelation30 * 10.0;
         }

         if(result.btcXauDivergenceValid)
         {
            if(result.btcXauDivergence == "BTC_BULL_XAU_BEAR")
               result.btcDivergenceContribution = 10.0;
            else
            if(result.btcXauDivergence == "BTC_BEAR_XAU_BULL")
               result.btcDivergenceContribution = -10.0;
         }

         result.btcQuantScoreValid =
            result.btcXauCorrelationValid &&
            result.btcXauDivergenceValid;

         if(result.btcQuantScoreValid)
         {
            result.btcQuantScore =
               result.btcMomentumContribution +
               result.btcZScoreContribution +
               result.btcAccelerationContribution +
               result.btcPercentileContribution +
               result.btcCorrelationContribution +
               result.btcDivergenceContribution;

            result.btcQuantScore =
               MathMax(
                  -100.0,
                  MathMin(100.0, result.btcQuantScore)
               );
         }
      }

      result.zScore = result.btcZScore;
      result.percentile = result.btcPercentile;
      result.acceleration = result.btcAcceleration;

      result.btcQuantDataValid =
         result.btcReturnValid &&
         result.btcZScoreValid &&
         result.btcPercentileValid &&
         result.btcVolatility60 > 0.0 &&
         result.btcVolatilityRatio >= 0.0;

      result.valid = result.btcQuantDataValid;

      if(!result.valid)
      {
         result.error =
            "BTC_QUANT_DATA_INSUFFICIENT_OR_INVALID";
      }

      return true;
   }
};

#endif // ASTRA_QUANT_ENGINE_MQH
