#ifndef __ASTRA_MEMPOOL_PRESSURE_CLIENT_MQH__
#define __ASTRA_MEMPOOL_PRESSURE_CLIENT_MQH__

// ============================================================
// ASTRA MEMPOOL PRESSURE CLIENT
// ============================================================
//
// Cliente HTTP MQL5 para:
//
//     Astra Mempool Pressure API
//
// Endpoint:
//
//     http://127.0.0.1:8765/pressure
//
// Contrato:
//
//     Astra Mempool Pressure API v1.0
//
// IMPORTANTE:
//
//     Este módulo NÃO executa decisões de trading.
//     Apenas coleta e valida dados externos.
//
// ============================================================

class MempoolPressureData
{
public:

   bool     valid;
   bool     api_success;
   bool     analysis_ready;

   string   contract_name;
   string   contract_version;

   string   timestamp_utc;
   string   state;

   double   pressure_index;
   double   anomaly_score;
   double   zscore;
   double   percentile;
   double   momentum;
   double   acceleration;

   int      http_status;
   int      age_seconds;

   string   last_error;

   void Reset()
   {
      valid           = false;
      api_success     = false;
      analysis_ready  = false;

      contract_name   = "";
      contract_version= "";

      timestamp_utc   = "";
      state           = "UNKNOWN";

      pressure_index  = 0.0;
      anomaly_score   = 0.0;
      zscore          = 0.0;
      percentile      = 0.0;
      momentum        = 0.0;
      acceleration    = 0.0;

      http_status     = 0;
      age_seconds     = -1;

      last_error      = "";
   }
};


// ============================================================
// CLIENT
// ============================================================

class MempoolPressureClient
{
private:

   string m_url;
   int    m_timeout_ms;

   MempoolPressureData m_data;


   // ---------------------------------------------------------
   // LOCAL STRING EXTRACTION
   // ---------------------------------------------------------

   bool ExtractString(
      const string json,
      const string key,
      string &value
   )
   {
      string pattern = "\"" + key + "\"";

      int key_pos = StringFind(
         json,
         pattern
      );

      if(key_pos < 0)
         return false;

      int colon_pos = StringFind(
         json,
         ":",
         key_pos + StringLen(pattern)
      );

      if(colon_pos < 0)
         return false;

      int quote_start = StringFind(
         json,
         "\"",
         colon_pos + 1
      );

      if(quote_start < 0)
         return false;

      int quote_end = StringFind(
         json,
         "\"",
         quote_start + 1
      );

      if(quote_end < 0)
         return false;

      value = StringSubstr(
         json,
         quote_start + 1,
         quote_end - quote_start - 1
      );

      return true;
   }


   // ---------------------------------------------------------
   // NUMBER EXTRACTION
   // ---------------------------------------------------------

   bool ExtractNumber(
      const string json,
      const string key,
      double &value
   )
   {
      string pattern = "\"" + key + "\"";

      int key_pos = StringFind(
         json,
         pattern
      );

      if(key_pos < 0)
         return false;

      int colon_pos = StringFind(
         json,
         ":",
         key_pos + StringLen(pattern)
      );

      if(colon_pos < 0)
         return false;

      int start = colon_pos + 1;

      int length = StringLen(json);

      while(start < length)
      {
         ushort c = StringGetCharacter(
            json,
            start
         );

         if(
            c == ' ' ||
            c == '\t' ||
            c == '\r' ||
            c == '\n'
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
         ushort c = StringGetCharacter(
            json,
            end
         );

         if(
            (c >= '0' && c <= '9') ||
            c == '-' ||
            c == '+' ||
            c == '.' ||
            c == 'e' ||
            c == 'E'
         )
         {
            end++;
            continue;
         }

         break;
      }

      if(end <= start)
         return false;

      string number_text = StringSubstr(
         json,
         start,
         end - start
      );

      value = StringToDouble(
         number_text
      );

      if(!MathIsValidNumber(value))
         return false;

      return true;
   }


   // ---------------------------------------------------------
   // BOOLEAN
   // ---------------------------------------------------------

   bool ExtractBool(
      const string json,
      const string key,
      bool &value
   )
   {
      string pattern = "\"" + key + "\"";

      int key_pos = StringFind(
         json,
         pattern
      );

      if(key_pos < 0)
         return false;

      int colon_pos = StringFind(
         json,
         ":",
         key_pos + StringLen(pattern)
      );

      if(colon_pos < 0)
         return false;

      int start = colon_pos + 1;

      int length = StringLen(json);

      while(start < length)
      {
         ushort c = StringGetCharacter(
            json,
            start
         );

         if(
            c == ' ' ||
            c == '\t' ||
            c == '\r' ||
            c == '\n'
         )
         {
            start++;
            continue;
         }

         break;
      }

      string tail = StringSubstr(
         json,
         start
      );

      if(StringFind(
         tail,
         "true"
      ) == 0)
      {
         value = true;
         return true;
      }

      if(StringFind(
         tail,
         "false"
      ) == 0)
      {
         value = false;
         return true;
      }

      return false;
   }


   // ---------------------------------------------------------
   // JSON VALIDATION
   // ---------------------------------------------------------

   bool ParseResponse(
      const string json
   )
   {
      m_data.Reset();

      // ------------------------------------------------------
      // CONTRACT
      // ------------------------------------------------------

      ExtractString(
         json,
         "name",
         m_data.contract_name
      );

      ExtractString(
         json,
         "version",
         m_data.contract_version
      );

      // ------------------------------------------------------
      // ROOT SUCCESS
      // ------------------------------------------------------

      bool success = false;

      if(!ExtractBool(
         json,
         "success",
         success
      ))
      {
         m_data.last_error =
            "Campo 'success' ausente.";

         return false;
      }

      m_data.api_success = success;

      if(!success)
      {
         m_data.last_error =
            "API retornou success=false.";

         return false;
      }

      // ------------------------------------------------------
      // PRESSURE
      // ------------------------------------------------------

      if(!ExtractNumber(
         json,
         "pressure_index",
         m_data.pressure_index
      ))
      {
         m_data.last_error =
            "pressure_index ausente.";

         return false;
      }

      ExtractNumber(
         json,
         "anomaly_score",
         m_data.anomaly_score
      );

      ExtractNumber(
         json,
         "zscore",
         m_data.zscore
      );

      ExtractNumber(
         json,
         "percentile",
         m_data.percentile
      );

      ExtractNumber(
         json,
         "momentum",
         m_data.momentum
      );

      ExtractNumber(
         json,
         "acceleration",
         m_data.acceleration
      );

      // ------------------------------------------------------
      // STATE
      // ------------------------------------------------------

      if(!ExtractString(
         json,
         "state",
         m_data.state
      ))
      {
         m_data.last_error =
            "Campo 'state' ausente.";

         return false;
      }

      if(
         m_data.state != "LOW" &&
         m_data.state != "NORMAL" &&
         m_data.state != "HIGH" &&
         m_data.state != "EXTREME"
      )
      {
         m_data.last_error =
            "state fora do contrato LOW/NORMAL/HIGH/EXTREME.";

         return false;
      }

      if(!ExtractNumber(
         json,
         "momentum",
         m_data.momentum
      ))
      {
         m_data.last_error =
            "Campo 'momentum' ausente ou invalido.";

         return false;
      }

      if(!ExtractNumber(
         json,
         "acceleration",
         m_data.acceleration
      ))
      {
         m_data.last_error =
            "Campo 'acceleration' ausente ou invalido.";

         return false;
      }

      // ------------------------------------------------------
      // TIMESTAMP
      // ------------------------------------------------------

      ExtractString(
         json,
         "timestamp_utc",
         m_data.timestamp_utc
      );

      double timestamp_epoch = 0.0;
      if(ExtractNumber(
         json,
         "timestamp",
         timestamp_epoch
      ) && timestamp_epoch > 0.0)
      {
         datetime api_timestamp = (datetime)(long)timestamp_epoch;
         m_data.timestamp_utc = TimeToString(
            api_timestamp,
            TIME_DATE | TIME_SECONDS
         );
         m_data.age_seconds = (int)MathMax(
            0,
            (long)TimeGMT() - (long)api_timestamp
         );
      }

      // ------------------------------------------------------
      // READY
      // ------------------------------------------------------

      bool readiness_available = ExtractBool(
         json,
         "analysis_ready",
         m_data.analysis_ready
      );

      // ------------------------------------------------------
      // BASIC RANGE VALIDATION
      // ------------------------------------------------------

      if(
         m_data.pressure_index < 0.0 ||
         m_data.pressure_index > 100.0 ||
         !MathIsValidNumber(m_data.pressure_index) ||
         !MathIsValidNumber(m_data.momentum) ||
         !MathIsValidNumber(m_data.acceleration)
      )
      {
         m_data.last_error =
            "pressure_index fora do intervalo 0..100.";

         return false;
      }

      // The local API's minimal contract has no analysis_ready field; a
      // successful, validated response is ready for the EA to consume.
      if(!readiness_available)
         m_data.analysis_ready = true;

      m_data.valid = true;

      return true;
   }


public:

   // ---------------------------------------------------------
   // CONSTRUCTOR
   // ---------------------------------------------------------

   MempoolPressureClient(
      const string url = "http://127.0.0.1:8765/pressure",
      const int timeout_ms = 3000
   )
   {
      m_url = url;
      m_timeout_ms = timeout_ms;

      m_data.Reset();
   }


   // ---------------------------------------------------------
   // FETCH
   // ---------------------------------------------------------

   bool Fetch()
   {
      // Preserve the last known-good sample during a failed refresh.
      // A failed HTTP attempt must not erase valid historical data.
      m_data.last_error = "";
      m_data.http_status = 0;

      // WebRequest is not available in the Strategy Tester.
      // Keep the indicator deterministic there and report the reason
      // explicitly instead of generating a misleading 4014 cycle.
      if(MQLInfoInteger(MQL_TESTER))
      {
         m_data.last_error =
            "WebRequest indisponivel no Strategy Tester (MQL_TESTER).";

         return false;
      }

      uchar request_data[];
      uchar response_data[];
      string response_headers = "";

      ResetLastError();

      int status = WebRequest(
         "GET",
         m_url,
         "",
         "",
         m_timeout_ms,
         request_data,
         ArraySize(request_data),
         response_data,
         response_headers
      );

      m_data.http_status = status;

      if(status == -1)
      {
         int error_code = GetLastError();

         if(error_code == 4014)
         {
            m_data.last_error =
               "WebRequest nao permitido (MT5=4014). "
               "Verifique Tools/Options/Expert Advisors e adicione "
               + m_url + " em 'Allow WebRequest for listed URL'.";
         }
         else
         {
            m_data.last_error =
               "WebRequest falhou. Erro MT5=" +
               IntegerToString(error_code);
         }

         return false;
      }

      string response = CharArrayToString(response_data);

      if(status != 200)
      {
         if(status == 1001)
         {
            m_data.last_error =
               "HTTP status 1001 no endpoint local. Verifique se "
               "AstraMempoolService esta iniciado e escutando em " +
               m_url + ".";
         }
         else
         {
            m_data.last_error =
               "HTTP status inesperado: " +
               IntegerToString(status);
         }

         return false;
      }

      if(StringLen(response) <= 0)
      {
         m_data.last_error =
            "Resposta HTTP vazia.";

         return false;
      }

      if(!ParseResponse(response))
         return false;

      return true;
   }


   // ---------------------------------------------------------
   // DATA
   // ---------------------------------------------------------

   MempoolPressureData GetData()
   {
      return m_data;
   }


   // ---------------------------------------------------------
   // LAST ERROR
   // ---------------------------------------------------------

   string GetLastErrorMessage()
   {
      return m_data.last_error;
   }


   // ---------------------------------------------------------
   // URL
   // ---------------------------------------------------------

   string GetURL()
   {
      return m_url;
   }
};

#endif