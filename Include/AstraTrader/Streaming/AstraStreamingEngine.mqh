//+------------------------------------------------------------------+
//| AstraStreamingEngine.mqh                                         |
//| Phase 3 preparation; no sockets or timers are started here.      |
//+------------------------------------------------------------------+
#ifndef ASTRA_STREAMING_ENGINE_MQH
#define ASTRA_STREAMING_ENGINE_MQH
#property strict

#include <AstraTrader\Streaming\AstraStreamingTypes.mqh>

class AstraStreamingEngine
  {
  private:
   AstraStreamingStatus m_status;

   bool IsValidEvent(const AstraStreamingEvent &event) const
     {
      if(event.timestamp==0) return false;
      if(event.sequence==0 && event.payload=="") return false;
      return true;
     }

  public:
   AstraStreamingEngine() { Reset(); }

   void Reset()
     {
      m_status.state=ASTRA_STREAM_DISABLED;
      m_status.eventsReceived=0;
      m_status.lastEventTime=0;
      m_status.error="";
     }

   bool Prepare()
     {
      m_status.error="";
      m_status.state=ASTRA_STREAM_READY;
      return true;
     }

   bool Start()
     {
      if(m_status.state!=ASTRA_STREAM_READY)
        {
         m_status.error="stream_not_prepared";
         return false;
        }

      m_status.state=ASTRA_STREAM_RUNNING;
      m_status.error="";
      return true;
     }

   void Stop()
     {
      m_status.state=ASTRA_STREAM_READY;
      m_status.error="";
     }

   bool IsReady() const
     {
      return m_status.state==ASTRA_STREAM_READY || m_status.state==ASTRA_STREAM_RUNNING;
     }

   bool IsRunning() const
     {
      return m_status.state==ASTRA_STREAM_RUNNING;
     }

   bool Push(const AstraStreamingEvent &event)
     {
      if(!IsValidEvent(event))
        {
         m_status.error="invalid_event";
         m_status.state=ASTRA_STREAM_ERROR;
         return false;
        }

      if(m_status.state!=ASTRA_STREAM_RUNNING)
        {
         m_status.error="stream_not_running";
         return false;
        }

      m_status.eventsReceived++;
      m_status.lastEventTime=event.timestamp;
      m_status.error="";
      return true;
     }

   AstraStreamingStatus GetStatus() const { return m_status; }
  };
#endif
