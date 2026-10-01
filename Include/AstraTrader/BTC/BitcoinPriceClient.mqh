//+------------------------------------------------------------------+
//| BitcoinPriceClient.mqh                                           |
//| AstraTrader - BTC Price Client                                  |
//+------------------------------------------------------------------+
#ifndef ASTRA_BITCOIN_PRICE_CLIENT_MQH
#define ASTRA_BITCOIN_PRICE_CLIENT_MQH

#property strict

#define ASTRA_BTC_PRICE_DEFAULT_URL          "https://mempool.space/api/v1/prices"
#define ASTRA_BTC_PRICE_DEFAULT_TIMEOUT_MS   3000
#define ASTRA_BTC_PRICE_DEFAULT_MAX_AGE_SEC  360


//==================================================================
// BTC PRICE CONTEXT
//==================================================================

struct BitcoinPriceContext
{
   datetime timestamp;

   double btcUsd;
   double btcEur;
   double btcGbp;
   double btcCad;
   double btcChf;
   double btcAud;
   double btcJpy;

   bool   valid;
   bool   stale;
   int    ageSeconds;
   string error;

   void Reset()
   {
      timestamp = 0;

      btcUsd = 0.0;
      btcEur = 0.0;
      btcGbp = 0.0;
      btcCad = 0.0;
      btcChf = 0.0;
      btcAud = 0.0;
      btcJpy = 0.0;

      valid = false;
      stale = true;
      ageSeconds = -1;
      error = "";
   }
};


class BitcoinPriceClient
{
private:

   string m_url;
   int    m_timeoutMs;
   int    m_maxAgeSeconds;

   int    m_httpStatus;
   BitcoinPriceContext m_context;


   bool ExtractNumber(
      const string json,
      const string key,
      double &value
   )
   {
      string pattern = "\"" + key + "\"";
      int keyPos = StringFind(json, pattern);

      if(keyPos < 0)
         return false;

      int colonPos = StringFind(
         json,
         ":",
         keyPos + StringLen(pattern)
      );

      if(colonPos < 0)
         return false;

      int start = colonPos + 1;
      int length = StringLen(json);

      while(start < length)
      {
         ushort character = StringGetCharacter(json, start);

         if(
            character == ' ' ||
            character == '\t' ||
            character == '\r' ||
            character == '\n'
         )
         {
            start++;
            continue;
         }

         break;
      }

      int end = start;

      while(end < length)
      {
         ushort character = StringGetCharacter(json, end);

         if(
            (character >= '0' && character <= '9') ||
            character == '-' ||
            character == '+' ||
            character == '.' ||
            character == 'e' ||
            character == 'E'
         )
         {
            end++;
            continue;
         }

         break;
      }

      if(end <= start)
         return false;

      value = StringToDouble(
         StringSubstr(json, start, end - start)
      );

      return MathIsValidNumber(value);
   }


   bool ReadRequiredPrice(
      const string json,
      const string key,
      double &value
   )
   {
      if(!ExtractNumber(json, key, value))
      {
         m_context.error =
            "Campo BTC ausente ou invalido: " + key;

         return false;
      }

      if(value <= 0.0 || !MathIsValidNumber(value))
      {
         m_context.error =
            "Preco BTC invalido: " + key;

         return false;
      }

      return true;
   }


   bool ParseResponse(
      const string json
   )
   {
      m_context.Reset();

      double timestampValue = 0.0;

      if(!ExtractNumber(json, "time", timestampValue))
      {
         m_context.error =
            "Campo timestamp ausente ou invalido.";

         return false;
      }

      if(
         timestampValue <= 0.0 ||
         !MathIsValidNumber(timestampValue) ||
         timestampValue != MathFloor(timestampValue)
      )
      {
         m_context.error =
            "Timestamp BTC invalido.";

         return false;
      }

      m_context.timestamp = (datetime)timestampValue;

      if(!ReadRequiredPrice(json, "USD", m_context.btcUsd))
         return false;

      if(!ReadRequiredPrice(json, "EUR", m_context.btcEur))
         return false;

      if(!ReadRequiredPrice(json, "GBP", m_context.btcGbp))
         return false;

      if(!ReadRequiredPrice(json, "CAD", m_context.btcCad))
         return false;

      if(!ReadRequiredPrice(json, "CHF", m_context.btcChf))
         return false;

      if(!ReadRequiredPrice(json, "AUD", m_context.btcAud))
         return false;

      if(!ReadRequiredPrice(json, "JPY", m_context.btcJpy))
         return false;

      datetime now = TimeGMT();

      if(now <= 0 || m_context.timestamp > now)
      {
         m_context.error =
            "Timestamp BTC futuro ou hora local invalida.";

         return false;
      }

      m_context.ageSeconds =
         (int)(now - m_context.timestamp);

      if(m_context.ageSeconds < 0)
      {
         m_context.error =
            "Idade BTC negativa.";

         m_context.ageSeconds = -1;
         return false;
      }

      m_context.valid = true;
      m_context.stale =
         (m_context.ageSeconds > m_maxAgeSeconds);

      if(m_context.stale)
      {
         m_context.error =
            "Preco BTC stale.";
      }

      return true;
   }


public:

   BitcoinPriceClient(
      const string url = ASTRA_BTC_PRICE_DEFAULT_URL,
      const int timeoutMs = ASTRA_BTC_PRICE_DEFAULT_TIMEOUT_MS,
      const int maxAgeSeconds = ASTRA_BTC_PRICE_DEFAULT_MAX_AGE_SEC
   )
   {
      m_url = url;
      m_timeoutMs = timeoutMs;
      m_maxAgeSeconds = maxAgeSeconds;
      m_httpStatus = 0;

      m_context.Reset();
   }


   bool Fetch()
   {
      m_context.Reset();
      m_httpStatus = 0;

      if(StringLen(m_url) <= 0)
      {
         m_context.error =
            "URL BTC invalida.";

         return false;
      }

      if(m_timeoutMs < 1 || m_maxAgeSeconds < 0)
      {
         m_context.error =
            "Configuracao BTC invalida.";

         return false;
      }

      uchar requestData[];
      uchar responseData[];
      string responseHeaders = "";

      ResetLastError();

      int status = WebRequest(
         "GET",
         m_url,
         "",
         "",
         m_timeoutMs,
         requestData,
         ArraySize(requestData),
         responseData,
         responseHeaders
      );

      m_httpStatus = status;

      if(status == -1)
      {
         m_context.error =
            "WebRequest BTC falhou. Erro MT5=" +
            IntegerToString(GetLastError());

         return false;
      }

      if(status != 200)
      {
         m_context.error =
            "HTTP BTC inesperado: " +
            IntegerToString(status);

         return false;
      }

      string response = CharArrayToString(responseData);

      if(StringLen(response) <= 0)
      {
         m_context.error =
            "Resposta BTC vazia.";

         return false;
      }

      return ParseResponse(response);
   }


   BitcoinPriceContext GetData() const
   {
      return m_context;
   }


   string GetLastErrorMessage() const
   {
      return m_context.error;
   }


   int GetHttpStatus() const
   {
      return m_httpStatus;
   }


   string GetURL() const
   {
      return m_url;
   }
};

#endif // ASTRA_BITCOIN_PRICE_CLIENT_MQH
