//+------------------------------------------------------------------+
//| NewsFilterEngine.mqh                                             |
//| Astra Trader AI                                                  |
//+------------------------------------------------------------------+
#ifndef ASTRA_NEWSFILTERENGINE_MQH
#define ASTRA_NEWSFILTERENGINE_MQH

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>


class NewsFilterEngine
{
private:

   bool     m_enabled;
   int      m_minutesBefore;
   int      m_minutesAfter;
   bool     m_blockModerate;

   string   m_countryCodes[];

   datetime m_lastCheck;
   bool     m_lastBlocked;
   string   m_lastReason;

   bool     m_calendarWarned;


   //===============================================================
   // PAISES
   //===============================================================
   void ParseCountries(
      const string csv
   )
   {
      ArrayResize(
         m_countryCodes,
         0
      );


      string parts[];

      const int n =
         StringSplit(
            csv,
            ',',
            parts
         );


      for(int i = 0; i < n; i++)
      {
         string code =
            parts[i];

         StringTrimLeft(code);
         StringTrimRight(code);
         StringToUpper(code);


         if(code == "")
            continue;


         const int size =
            ArraySize(
               m_countryCodes
            );


         ArrayResize(
            m_countryCodes,
            size + 1
         );


         m_countryCodes[size] =
            code;
      }
   }


   //===============================================================
   // EVENTO RELEVANTE
   //===============================================================
   bool EventMatches(
      const MqlCalendarEvent &event
   ) const
   {
      if(event.id <= 0)
         return false;


      if(
         event.importance ==
         CALENDAR_IMPORTANCE_HIGH
      )
      {
         return true;
      }


      if(
         m_blockModerate &&
         event.importance ==
         CALENDAR_IMPORTANCE_MODERATE
      )
      {
         return true;
      }


      return false;
   }


   //===============================================================
   // SCAN RANGE
   //
   // Retorno:
   // true  = evento relevante encontrado
   // false = nenhum evento relevante
   //===============================================================
   bool ScanRange(
      const datetime from,
      const datetime to,
      const string country
   )
   {
      MqlCalendarValue values[];


      ResetLastError();


      const int count =
         CalendarValueHistory(
            values,
            from,
            to,
            country
         );


      if(count < 0)
      {
         if(!m_calendarWarned)
         {
            PrintFormat(
               "[NewsFilterEngine] WARNING: CalendarValueHistory falhou | Error=%d",
               GetLastError()
            );

            m_calendarWarned =
               true;
         }

         return false;
      }


      // count == 0 significa simplesmente:
      // não existem eventos no intervalo.
      if(count == 0)
         return false;


      for(int i = 0; i < count; i++)
      {
         MqlCalendarEvent event;


         if(!CalendarEventById(
               values[i].event_id,
               event
            ))
         {
            continue;
         }


         if(EventMatches(event))
            return true;
      }


      return false;
   }


   //===============================================================
   // EVENTOS NA JANELA
   //===============================================================
   bool HasImpactInWindow(
      const datetime from,
      const datetime to
   )
   {
      const int countryCount =
         ArraySize(
            m_countryCodes
         );


      if(countryCount <= 0)
      {
         return ScanRange(
            from,
            to,
            ""
         );
      }


      for(int i = 0; i < countryCount; i++)
      {
         if(
            ScanRange(
               from,
               to,
               m_countryCodes[i]
            )
         )
         {
            return true;
         }
      }


      return false;
   }


public:

   //===============================================================
   // CONSTRUCTOR
   //===============================================================
   NewsFilterEngine(
      const bool enabled       = true,
      const int minutesBefore  = 30,
      const int minutesAfter   = 30,
      const bool blockModerate = false,
      const string countriesCsv = "US,EU"
   )
   {
      m_enabled =
         enabled;

      m_minutesBefore =
         MathMax(
            0,
            minutesBefore
         );

      m_minutesAfter =
         MathMax(
            0,
            minutesAfter
         );

      m_blockModerate =
         blockModerate;


      ParseCountries(
         countriesCsv
      );


      m_lastCheck =
         0;

      m_lastBlocked =
         false;

      m_lastReason =
         "";

      m_calendarWarned =
         false;
   }


   //===============================================================
   // SETTERS
   //===============================================================

   void SetEnabled(
      const bool value
   )
   {
      m_enabled =
         value;
   }


   void SetBlockModerate(
      const bool value
   )
   {
      m_blockModerate =
         value;
   }


   void SetCountries(
      const string csv
   )
   {
      ParseCountries(
         csv
      );
   }


   void SetWindows(
      const int before,
      const int after
   )
   {
      m_minutesBefore =
         MathMax(
            0,
            before
         );

      m_minutesAfter =
         MathMax(
            0,
            after
         );
   }


   //===============================================================
   // CONSULTA PRINCIPAL
   //===============================================================
   bool IsNewsBlocked(
      string &reason
   )
   {
      reason =
         "";


      if(!m_enabled)
         return false;


      const datetime now =
         TimeGMT();


      // Throttle de 15 segundos.
      if(
         m_lastCheck != 0 &&
         (now - m_lastCheck) < 15
      )
      {
         reason =
            m_lastReason;

         return m_lastBlocked;
      }


      m_lastCheck =
         now;


      const datetime windowFrom =
         now -
         (datetime)(
            MathMax(0, m_minutesBefore) * 60
         );


      const datetime windowTo =
         now +
         (datetime)(
            MathMax(0, m_minutesAfter) * 60
         );


      if(
         HasImpactInWindow(
            windowFrom,
            windowTo
         )
      )
      {
         m_lastBlocked =
            true;

         m_lastReason =
            StringFormat(
               "news_filter_high_impact | "
               "window=-%dmin/+%dmin UTC",
               m_minutesAfter,
               m_minutesBefore
            );

         reason =
            m_lastReason;

         return true;
      }


      m_lastBlocked =
         false;

      m_lastReason =
         "";

      return false;
   }
};


#endif // ASTRA_NEWSFILTERENGINE_MQH