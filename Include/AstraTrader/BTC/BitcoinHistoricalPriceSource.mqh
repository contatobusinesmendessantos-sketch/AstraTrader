//+------------------------------------------------------------------+
//| BitcoinHistoricalPriceSource.mqh                                 |
//| AstraTrader - deterministic BTC replay source                   |
//+------------------------------------------------------------------+
#ifndef ASTRA_BITCOIN_HISTORICAL_PRICE_SOURCE_MQH
#define ASTRA_BITCOIN_HISTORICAL_PRICE_SOURCE_MQH

#property strict

#include <AstraTrader\BTC\BitcoinPriceClient.mqh>

#define ASTRA_BTC_REPLAY_MAX_AGE_SECONDS 180
#define ASTRA_BTC_REPLAY_DEFAULT_CAPACITY 4096


struct BitcoinHistoricalPriceRow
{
   datetime timestamp;
   double btcUsd;
   double btcEur;
   double btcGbp;
   double btcCad;
   double btcChf;
   double btcAud;
   double btcJpy;
};


class BitcoinHistoricalPriceSource
{
private:

   BitcoinHistoricalPriceRow m_rows[];
   int m_rowCount;
   int m_maxAgeSeconds;
   string m_filename;
   string m_error;
   datetime m_lastCycleTimestamp;


   bool IsValidPrice(const double value) const
   {
      return value > 0.0 && MathIsValidNumber(value);
   }


   bool IsValidRow(const BitcoinHistoricalPriceRow &row) const
   {
      return (
         row.timestamp > 0 &&
         IsValidPrice(row.btcUsd) &&
         IsValidPrice(row.btcEur) &&
         IsValidPrice(row.btcGbp) &&
         IsValidPrice(row.btcCad) &&
         IsValidPrice(row.btcChf) &&
         IsValidPrice(row.btcAud) &&
         IsValidPrice(row.btcJpy)
      );
   }


   bool ReadHeader(const int handle)
   {
      const string expected[] =
      {
         "timestamp",
         "BTCUSD",
         "BTCEUR",
         "BTCGBP",
         "BTCCAD",
         "BTCCHF",
         "BTCAUD",
         "BTCJPY"
      };

      for(int index = 0; index < ArraySize(expected); index++)
      {
         if(FileIsEnding(handle))
         {
            m_error = "BTC_REPLAY_HEADER_INCOMPLETE";
            return false;
         }

         const string actual = FileReadString(handle);

         if(actual != expected[index])
         {
            m_error =
               "BTC_REPLAY_HEADER_INVALID_AT_" +
               IntegerToString(index);
            return false;
         }
      }

      return true;
   }


   bool AppendRow(const BitcoinHistoricalPriceRow &row)
   {
      if(!IsValidRow(row))
      {
         m_error = "BTC_REPLAY_ROW_INVALID";
         return false;
      }

      if(m_rowCount > 0)
      {
         const datetime previousTimestamp =
            m_rows[m_rowCount - 1].timestamp;

         if(row.timestamp <= previousTimestamp)
         {
            m_error = "BTC_REPLAY_TIMESTAMP_NOT_STRICTLY_INCREASING";
            return false;
         }
      }

      if(m_rowCount >= ArraySize(m_rows))
      {
         const int nextCapacity =
            m_rowCount == 0
            ? ASTRA_BTC_REPLAY_DEFAULT_CAPACITY
            : m_rowCount * 2;

         if(ArrayResize(m_rows, nextCapacity) < nextCapacity)
         {
            m_error = "BTC_REPLAY_MEMORY_ALLOCATION_FAILED";
            return false;
         }
      }

      m_rows[m_rowCount] = row;
      m_rowCount++;
      return true;
   }


public:

   BitcoinHistoricalPriceSource(
      const int maxAgeSeconds = ASTRA_BTC_REPLAY_MAX_AGE_SECONDS
   )
   {
      m_rowCount = 0;
      m_maxAgeSeconds = maxAgeSeconds;
      m_filename = "";
      m_error = "";
      m_lastCycleTimestamp = 0;
      ArrayResize(m_rows, 0);
   }


   bool Load(const string filename)
   {
      m_rowCount = 0;
      m_filename = filename;
      m_error = "";
      m_lastCycleTimestamp = 0;
      ArrayResize(m_rows, 0);

      if(StringLen(filename) <= 0 || m_maxAgeSeconds < 0)
      {
         m_error = "BTC_REPLAY_CONFIGURATION_INVALID";
         return false;
      }

      const int handle = FileOpen(
         filename,
         FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON,
         ','
      );

      if(handle == INVALID_HANDLE)
      {
         m_error = "BTC_REPLAY_FILE_OPEN_FAILED_" + filename;
         return false;
      }

      if(!ReadHeader(handle))
      {
         FileClose(handle);
         return false;
      }

      while(!FileIsEnding(handle))
      {
         BitcoinHistoricalPriceRow row;

         row.timestamp = (datetime)FileReadLong(handle);
         row.btcUsd = FileReadDouble(handle);
         row.btcEur = FileReadDouble(handle);
         row.btcGbp = FileReadDouble(handle);
         row.btcCad = FileReadDouble(handle);
         row.btcChf = FileReadDouble(handle);
         row.btcAud = FileReadDouble(handle);
         row.btcJpy = FileReadDouble(handle);

         if(!AppendRow(row))
         {
            FileClose(handle);
            return false;
         }
      }

      FileClose(handle);

      if(m_rowCount == 0)
      {
         m_error = "BTC_REPLAY_FILE_EMPTY";
         return false;
      }

      return true;
   }


   bool GetAtOrBefore(
      const datetime cycleTimestamp,
      BitcoinPriceContext &context
   )
   {
      context.Reset();

      if(m_rowCount <= 0)
      {
         context.error = "BTC_REPLAY_NOT_LOADED";
         return false;
      }

      if(cycleTimestamp <= 0)
      {
         context.error = "BTC_REPLAY_CYCLE_TIMESTAMP_INVALID";
         return false;
      }

      if(
         m_lastCycleTimestamp > 0 &&
         cycleTimestamp < m_lastCycleTimestamp
      )
      {
         context.error = "BTC_REPLAY_CYCLE_OUT_OF_ORDER";
         return false;
      }

      m_lastCycleTimestamp = cycleTimestamp;

      int selectedIndex = -1;

      for(int index = 0; index < m_rowCount; index++)
      {
         if(m_rows[index].timestamp > cycleTimestamp)
            break;

         selectedIndex = index;
      }

      if(selectedIndex < 0)
      {
         context.error = "BTC_REPLAY_NO_ROW_AT_OR_BEFORE_CYCLE";
         return false;
      }

      const BitcoinHistoricalPriceRow row =
         m_rows[selectedIndex];

      const int ageSeconds =
         (int)(cycleTimestamp - row.timestamp);

      if(ageSeconds < 0)
      {
         context.error = "BTC_REPLAY_LOOKAHEAD_REJECTED";
         return false;
      }

      context.timestamp = row.timestamp;
      context.btcUsd = row.btcUsd;
      context.btcEur = row.btcEur;
      context.btcGbp = row.btcGbp;
      context.btcCad = row.btcCad;
      context.btcChf = row.btcChf;
      context.btcAud = row.btcAud;
      context.btcJpy = row.btcJpy;
      context.ageSeconds = ageSeconds;
      context.valid = true;
      context.stale = ageSeconds > m_maxAgeSeconds;

      if(context.stale)
         context.error = "BTC_REPLAY_PRICE_STALE";

      return true;
   }


   int GetRowCount() const
   {
      return m_rowCount;
   }


   string GetLastError() const
   {
      return m_error;
   }


   string GetFilename() const
   {
      return m_filename;
   }
};

#endif // ASTRA_BITCOIN_HISTORICAL_PRICE_SOURCE_MQH
