//+------------------------------------------------------------------+
//| AstraMempoolIndicator.mqh                                       |
//| AstraTrader - Mempool Pressure Indicator                        |
//| Version: 1.2.1                                                   |
//+------------------------------------------------------------------+
#ifndef __ASTRA_MEMPOOL_INDICATOR_MQH__
#define __ASTRA_MEMPOOL_INDICATOR_MQH__

#include <AstraTrader\Mempool\MempoolPressureClient.mqh>
#include <AstraTrader\Mempool\AstraMempoolPanel.mqh>

#define ASTRA_MEMPOOL_DEFAULT_URL        "http://127.0.0.1:8765/pressure"
#define ASTRA_MEMPOOL_DEFAULT_TIMEOUT    3000
#define ASTRA_MEMPOOL_DEFAULT_INTERVAL   60
#define ASTRA_MEMPOOL_STALE_MULTIPLIER   2

class CAstraMempoolIndicator
{
private:

   MempoolPressureClient *m_client;
   AstraMempoolPanel     *m_panel;

   bool     m_initialized;
   bool     m_last_connected;
   bool     m_last_stale;

   datetime m_last_update;
   datetime m_last_attempt;

   int      m_update_interval;

   MempoolPressureData m_data;

   string m_url;
   int    m_timeout_ms;


   bool ValidateConfiguration()
   {
      if(StringLen(m_url) <= 0)
      {
         Print("[ASTRA MEMPOOL] URL invalida.");
         return false;
      }

      if(m_timeout_ms < 500)
      {
         Print("[ASTRA MEMPOOL] Timeout invalido.");
         return false;
      }

      if(m_update_interval < 1)
      {
         Print("[ASTRA MEMPOOL] Intervalo de atualizacao invalido.");
         return false;
      }

      return true;
   }


   int GetLocalAgeSeconds()
   {
      if(m_last_update <= 0)
         return -1;

      datetime now = TimeCurrent();

      int age =
         (int)(now - m_last_update);

      if(age < 0)
         age = 0;

      return age;
   }


   int CalculateEffectiveAgeSeconds()
   {
      int localAge =
         GetLocalAgeSeconds();

      int apiAge =
         m_data.age_seconds;

      if(apiAge >= 0 && localAge >= 0)
      {
         return MathMax(
            apiAge,
            localAge
         );
      }

      if(apiAge >= 0)
         return apiAge;

      return localAge;
   }


   bool IsDataStale()
   {
      if(!m_initialized)
         return true;

      if(!m_data.valid)
         return true;

      if(!m_data.api_success)
         return true;

      if(m_last_update <= 0)
         return true;

      int effectiveAge =
         CalculateEffectiveAgeSeconds();

      if(effectiveAge < 0)
         return true;

      int staleThreshold =
         m_update_interval *
         ASTRA_MEMPOOL_STALE_MULTIPLIER;

      return (
         effectiveAge >
         staleThreshold
      );
   }


   string GetDisplayTimestamp()
   {
      if(StringLen(m_data.timestamp_utc) > 0)
         return m_data.timestamp_utc;

      if(m_last_update > 0)
      {
         return TimeToString(
            m_last_update,
            TIME_DATE | TIME_SECONDS
         );
      }

      return "--";
   }


   void Render()
   {
      if(m_panel == NULL)
         return;

      bool connected =
         (
            m_data.valid &&
            m_data.api_success
         );

      bool stale =
         IsDataStale();

      m_panel.Update(
         m_data.pressure_index,
         m_data.state,
         m_data.zscore,
         m_data.percentile,
         m_data.momentum,
         m_data.acceleration,
         m_data.analysis_ready,
         connected,
         stale,
         GetDisplayTimestamp()
      );

      m_last_connected =
         connected;

      m_last_stale =
         stale;
   }


   void RenderError(
      const string message
   )
   {
      if(m_panel == NULL)
         return;

      m_panel.ShowError(
         message
      );

      m_last_connected =
         false;

      m_last_stale =
         true;
   }


   void ReleaseObjects()
   {
      if(m_panel != NULL)
      {
         delete m_panel;
         m_panel = NULL;
      }

      if(m_client != NULL)
      {
         delete m_client;
         m_client = NULL;
      }
   }


public:

   CAstraMempoolIndicator()
   {
      m_client = NULL;
      m_panel  = NULL;

      m_initialized = false;

      m_last_connected = false;
      m_last_stale = true;

      m_last_update = 0;
      m_last_attempt = 0;

      m_update_interval =
         ASTRA_MEMPOOL_DEFAULT_INTERVAL;

      m_url =
         ASTRA_MEMPOOL_DEFAULT_URL;

      m_timeout_ms =
         ASTRA_MEMPOOL_DEFAULT_TIMEOUT;

      m_data.Reset();
   }


   ~CAstraMempoolIndicator()
   {
      Shutdown();
   }


   bool Init(
      const string url = ASTRA_MEMPOOL_DEFAULT_URL,
      const int timeout_ms = ASTRA_MEMPOOL_DEFAULT_TIMEOUT,
      const int update_interval = ASTRA_MEMPOOL_DEFAULT_INTERVAL
   )
   {
      if(m_initialized)
         Shutdown();

      ReleaseObjects();

      m_initialized = false;

      m_last_connected = false;
      m_last_stale = true;

      m_last_update = 0;
      m_last_attempt = 0;

      m_data.Reset();

      m_url =
         url;

      m_timeout_ms =
         timeout_ms;

      if(m_timeout_ms < 500)
         m_timeout_ms = 500;

      m_update_interval =
         update_interval;

      if(m_update_interval < 1)
         m_update_interval = 1;

      if(!ValidateConfiguration())
         return false;

      m_client =
         new MempoolPressureClient(
            m_url,
            m_timeout_ms
         );

      if(m_client == NULL)
      {
         Print(
            "[ASTRA MEMPOOL] Falha ao criar MempoolPressureClient."
         );

         ReleaseObjects();
         return false;
      }

      m_panel =
         new AstraMempoolPanel();

      if(m_panel == NULL)
      {
         Print(
            "[ASTRA MEMPOOL] Falha ao criar AstraMempoolPanel."
         );

         ReleaseObjects();
         return false;
      }

      if(!m_panel.Create(20,20))
      {
         Print(
            "[ASTRA MEMPOOL] Falha ao criar painel."
         );

         ReleaseObjects();
         return false;
      }

      m_initialized = true;

      Print(
         "[ASTRA MEMPOOL] Indicador inicializado."
      );

      Print(
         "[ASTRA MEMPOOL] URL: ",
         m_url
      );

      Print(
         "[ASTRA MEMPOOL] Intervalo: ",
         IntegerToString(m_update_interval),
         " segundos."
      );

      Print(
         "[ASTRA MEMPOOL] Timeout: ",
         IntegerToString(m_timeout_ms),
         " ms."
      );

      Update();

      return true;
   }


   void Update()
   {
      if(!m_initialized)
         return;

      if(m_client == NULL)
      {
         RenderError(
            "Cliente Mempool indisponivel."
         );

         return;
      }

      m_last_attempt =
         TimeCurrent();

      bool success =
         m_client.Fetch();

      if(!success)
      {
         string error_message =
            m_client.GetLastErrorMessage();

         if(StringLen(error_message) <= 0)
         {
            error_message =
               "Falha desconhecida na API.";
         }

         Print(
            "[ASTRA MEMPOOL] ",
            error_message
         );

         m_last_connected = false;
         m_last_stale = true;

         RenderError(
            error_message
         );

         return;
      }

      m_data =
         m_client.GetData();

      if(!m_data.valid)
      {
         string error_message =
            m_data.last_error;

         if(StringLen(error_message) <= 0)
         {
            error_message =
               "Dados recebidos sao invalidos.";
         }

         Print(
            "[ASTRA MEMPOOL] ",
            error_message
         );

         m_last_connected = false;
         m_last_stale = true;

         RenderError(
            error_message
         );

         return;
      }

      if(!m_data.api_success)
      {
         string error_message =
            "API retornou success=false.";

         if(StringLen(m_data.last_error) > 0)
            error_message = m_data.last_error;

         Print(
            "[ASTRA MEMPOOL] ",
            error_message
         );

         m_last_connected = false;
         m_last_stale = true;

         RenderError(
            error_message
         );

         return;
      }

      if(
         m_data.pressure_index < 0.0 ||
         m_data.pressure_index > 100.0
      )
      {
         string error_message =
            "Pressure index fora do intervalo 0..100.";

         Print(
            "[ASTRA MEMPOOL] ",
            error_message
         );

         m_last_connected = false;
         m_last_stale = true;

         RenderError(
            error_message
         );

         return;
      }

      m_last_update =
         TimeCurrent();

      m_last_connected = true;

      m_last_stale =
         IsDataStale();

      Print(
         "[ASTRA MEMPOOL] "
         "Pressure=",
         DoubleToString(
            m_data.pressure_index,
            2
         ),
         " | State=",
         m_data.state,
         " | Z=",
         DoubleToString(
            m_data.zscore,
            4
         ),
         " | Percentile=",
         DoubleToString(
            m_data.percentile,
            2
         ),
         "%",
         " | APIAge=",
         IntegerToString(
            m_data.age_seconds
         ),
         " | EffectiveAge=",
         IntegerToString(
            CalculateEffectiveAgeSeconds()
         ),
         " | Stale=",
         m_last_stale
         ? "true"
         : "false"
      );

      Render();
   }


   void OnTimer()
   {
      if(!m_initialized)
         return;

      datetime now =
         TimeCurrent();

      if(m_last_attempt <= 0)
      {
         Update();
         return;
      }

      int elapsed =
         (int)(now - m_last_attempt);

      if(elapsed < 0)
      {
         Update();
         return;
      }

      if(elapsed >= m_update_interval)
      {
         Update();
      }
   }


   void ForceUpdate()
   {
      if(!m_initialized)
         return;

      Update();
   }


   void Shutdown()
   {
      m_initialized = false;

      m_last_connected = false;
      m_last_stale = true;

      ReleaseObjects();

      m_last_update = 0;
      m_last_attempt = 0;

      m_data.Reset();
   }


   bool IsInitialized()
   {
      return m_initialized;
   }


   bool IsConnected()
   {
      return (
         m_initialized &&
         m_last_connected
      );
   }


   bool IsStale()
   {
      if(!m_initialized)
         return true;

      m_last_stale =
         IsDataStale();

      return m_last_stale;
   }


   MempoolPressureData GetData()
   {
      return m_data;
   }


   double GetPressure()
   {
      return m_data.pressure_index;
   }


   double GetZScore()
   {
      return m_data.zscore;
   }


   double GetPercentile()
   {
      return m_data.percentile;
   }


   double GetMomentum()
   {
      return m_data.momentum;
   }


   double GetAcceleration()
   {
      return m_data.acceleration;
   }


   string GetState()
   {
      return m_data.state;
   }


   bool IsAnalysisReady()
   {
      if(!m_initialized)
         return false;

      if(!m_data.valid)
         return false;

      if(!m_data.api_success)
         return false;

      if(IsDataStale())
         return false;

      return m_data.analysis_ready;
   }


   string GetLastErrorMessage()
   {
      return m_data.last_error;
   }


   string GetURL()
   {
      return m_url;
   }


   int GetUpdateInterval()
   {
      return m_update_interval;
   }


   int GetEffectiveAgeSeconds()
   {
      return CalculateEffectiveAgeSeconds();
   }
};


//+------------------------------------------------------------------+

#endif