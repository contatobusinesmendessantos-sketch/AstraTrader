//+------------------------------------------------------------------+
//| AstraMempoolPanel.mqh                                            |
//| AstraTrader - Mempool Pressure Visualization                     |
//| Version: 1.0.1                                                    |
//+------------------------------------------------------------------+
#property strict

#ifndef __ASTRA_MEMPOOL_PANEL_MQH__
#define __ASTRA_MEMPOOL_PANEL_MQH__

//+------------------------------------------------------------------+
//| CONFIGURAÇÃO                                                      |
//+------------------------------------------------------------------+

#define ASTRA_MEMPOOL_PANEL_PREFIX "ASTRA_MEMPOOL_PANEL_"

//+------------------------------------------------------------------+
//| CLASSE                                                             |
//+------------------------------------------------------------------+

class AstraMempoolPanel
{
private:

   string m_prefix;

   int m_x;
   int m_y;
   int m_width;
   int m_height;

   color m_background;
   color m_border;

   color m_text;
   color m_positive;
   color m_negative;
   color m_neutral;
   color m_warning;

   //+----------------------------------------------------------------+
   //| Nome completo do objeto                                        |
   //+----------------------------------------------------------------+

   string Name(const string suffix)
   {
      return m_prefix + suffix;
   }

   //+----------------------------------------------------------------+
   //| Criar retângulo                                                 |
   //+----------------------------------------------------------------+

   bool CreateRectangle(
      const string name,
      const int x,
      const int y,
      const int width,
      const int height,
      const color background,
      const color border
   )
   {
      if(ObjectFind(0,name) >= 0)
         ObjectDelete(0,name);

      ResetLastError();

      if(!ObjectCreate(
         0,
         name,
         OBJ_RECTANGLE_LABEL,
         0,
         0,
         0
      ))
      {
         Print(
            "[ASTRA MEMPOOL PANEL] Falha ao criar retângulo: ",
            name,
            " | erro=",
            GetLastError()
         );

         return false;
      }

      ObjectSetInteger(
         0,
         name,
         OBJPROP_CORNER,
         CORNER_LEFT_UPPER
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_XDISTANCE,
         x
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_YDISTANCE,
         y
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_XSIZE,
         width
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_YSIZE,
         height
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_BGCOLOR,
         background
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_COLOR,
         border
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_BORDER_TYPE,
         BORDER_FLAT
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_SELECTABLE,
         false
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_SELECTED,
         false
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_HIDDEN,
         false
      );

      return true;
   }

   //+----------------------------------------------------------------+
   //| Criar label                                                     |
   //+----------------------------------------------------------------+

   bool CreateLabel(
      const string name,
      const string text,
      const int x,
      const int y,
      const int font_size,
      const color text_color
   )
   {
      if(ObjectFind(0,name) >= 0)
         ObjectDelete(0,name);

      ResetLastError();

      if(!ObjectCreate(
         0,
         name,
         OBJ_LABEL,
         0,
         0,
         0
      ))
      {
         Print(
            "[ASTRA MEMPOOL PANEL] Falha ao criar label: ",
            name,
            " | erro=",
            GetLastError()
         );

         return false;
      }

      ObjectSetInteger(
         0,
         name,
         OBJPROP_CORNER,
         CORNER_LEFT_UPPER
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_XDISTANCE,
         x
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_YDISTANCE,
         y
      );

      ObjectSetString(
         0,
         name,
         OBJPROP_TEXT,
         text
      );

      ObjectSetString(
         0,
         name,
         OBJPROP_FONT,
         "Arial"
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_FONTSIZE,
         font_size
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_COLOR,
         text_color
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_ANCHOR,
         ANCHOR_LEFT_UPPER
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_SELECTABLE,
         false
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_SELECTED,
         false
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_HIDDEN,
         false
      );

      return true;
   }

   //+----------------------------------------------------------------+
   //| Atualizar label                                                 |
   //+----------------------------------------------------------------+

   void SetLabel(
      const string name,
      const string text,
      const color text_color
   )
   {
      if(ObjectFind(0,name) < 0)
         return;

      ObjectSetString(
         0,
         name,
         OBJPROP_TEXT,
         text
      );

      ObjectSetInteger(
         0,
         name,
         OBJPROP_COLOR,
         text_color
      );
   }

public:

   //+----------------------------------------------------------------+
   //| Construtor                                                       |
   //+----------------------------------------------------------------+

   AstraMempoolPanel()
   {
      m_prefix = ASTRA_MEMPOOL_PANEL_PREFIX;

      m_x = 20;
      m_y = 20;

      m_width = 300;
      m_height = 225;

      m_background = C'20,24,30';
      m_border     = C'70,80,95';

      m_text       = clrWhite;
      m_positive   = C'50,220,120';
      m_negative   = C'255,80,80';
      m_neutral    = C'180,190,205';
      m_warning    = C'255,190,60';
   }

   //+----------------------------------------------------------------+
   //| Destrutor                                                        |
   //+----------------------------------------------------------------+

   ~AstraMempoolPanel()
   {
      Destroy();
   }

   //+----------------------------------------------------------------+
   //| Criar painel                                                     |
   //+----------------------------------------------------------------+

   bool Create(
      const int x = 20,
      const int y = 20
   )
   {
      m_x = x;
      m_y = y;

      bool result = true;

      result = CreateRectangle(
         Name("BACKGROUND"),
         m_x,
         m_y,
         m_width,
         m_height,
         m_background,
         m_border
      ) && result;

      result = CreateLabel(
         Name("TITLE"),
         "ASTRA MEMPOOL PRESSURE",
         m_x + 12,
         m_y + 10,
         11,
         m_text
      ) && result;

      result = CreateLabel(
         Name("STATUS"),
         "Status: CONNECTING...",
         m_x + 12,
         m_y + 34,
         9,
         m_warning
      ) && result;

      result = CreateLabel(
         Name("PRESSURE"),
         "Pressure: -- / 100",
         m_x + 12,
         m_y + 60,
         13,
         m_text
      ) && result;

      result = CreateLabel(
         Name("STATE"),
         "State: --",
         m_x + 12,
         m_y + 87,
         10,
         m_neutral
      ) && result;

      result = CreateLabel(
         Name("ZSCORE"),
         "Z-Score: --",
         m_x + 12,
         m_y + 111,
         9,
         m_neutral
      ) && result;

      result = CreateLabel(
         Name("PERCENTILE"),
         "Percentile: --",
         m_x + 12,
         m_y + 132,
         9,
         m_neutral
      ) && result;

      result = CreateLabel(
         Name("MOMENTUM"),
         "Momentum: --",
         m_x + 12,
         m_y + 153,
         9,
         m_neutral
      ) && result;

      result = CreateLabel(
         Name("ACCELERATION"),
         "Acceleration: --",
         m_x + 12,
         m_y + 174,
         9,
         m_neutral
      ) && result;

      result = CreateLabel(
         Name("UPDATED"),
         "Analysis: --",
         m_x + 12,
         m_y + 195,
         8,
         m_neutral
      ) && result;

      ChartRedraw();

      return result;
   }

   //+----------------------------------------------------------------+
   //| Atualizar painel                                                 |
   //+----------------------------------------------------------------+

   void Update(
      const double pressure_index,
      const string state,
      const double zscore,
      const double percentile,
      const double momentum,
      const double acceleration,
      const bool analysis_ready,
      const bool connected,
      const bool stale,
      const string timestamp
   )
   {
      color pressure_color = m_neutral;

      if(pressure_index >= 70.0)
      {
         pressure_color = m_negative;
      }
      else
      if(pressure_index >= 40.0)
      {
         pressure_color = m_warning;
      }
      else
      {
         pressure_color = m_positive;
      }

      // -------------------------------------------------------------
      // STATUS DA CONEXÃO
      // -------------------------------------------------------------

      string connection_text;
      color connection_color;

      if(!connected)
      {
         connection_text = "Status: OFFLINE";
         connection_color = m_negative;
      }
      else
      if(stale)
      {
         connection_text = "Status: STALE DATA";
         connection_color = m_warning;
      }
      else
      {
         connection_text = "Status: LIVE";
         connection_color = m_positive;
      }

      SetLabel(
         Name("STATUS"),
         connection_text,
         connection_color
      );

      // -------------------------------------------------------------
      // PRESSURE
      // -------------------------------------------------------------

      SetLabel(
         Name("PRESSURE"),
         StringFormat(
            "Pressure: %.2f / 100",
            pressure_index
         ),
         pressure_color
      );

      // -------------------------------------------------------------
      // STATE
      // -------------------------------------------------------------

      SetLabel(
         Name("STATE"),
         "State: " + state,
         pressure_color
      );

      // -------------------------------------------------------------
      // Z-SCORE
      // -------------------------------------------------------------

      SetLabel(
         Name("ZSCORE"),
         StringFormat(
            "Z-Score: %.4f",
            zscore
         ),
         m_neutral
      );

      // -------------------------------------------------------------
      // PERCENTIL
      // -------------------------------------------------------------

      SetLabel(
         Name("PERCENTILE"),
         StringFormat(
            "Percentile: %.2f%%",
            percentile
         ),
         m_neutral
      );

      // -------------------------------------------------------------
      // MOMENTUM
      // -------------------------------------------------------------

      SetLabel(
         Name("MOMENTUM"),
         StringFormat(
            "Momentum: %.6f",
            momentum
         ),
         m_neutral
      );

      // -------------------------------------------------------------
      // ACCELERAÇÃO
      // -------------------------------------------------------------

      SetLabel(
         Name("ACCELERATION"),
         StringFormat(
            "Acceleration: %.6f",
            acceleration
         ),
         m_neutral
      );

      // -------------------------------------------------------------
      // ANALYSIS READY
      // -------------------------------------------------------------

      string ready_text;

      if(analysis_ready)
      {
         ready_text = "Analysis: READY";
      }
      else
      {
         ready_text = "Analysis: WARMING UP";
      }

      SetLabel(
         Name("UPDATED"),
         ready_text + " | " + timestamp,
         analysis_ready
            ? m_positive
            : m_warning
      );

      ChartRedraw();
   }

   //+----------------------------------------------------------------+
   //| Mostrar erro                                                     |
   //+----------------------------------------------------------------+

   void ShowError(
      const string message
   )
   {
      SetLabel(
         Name("STATUS"),
         "Status: ERROR",
         m_negative
      );

      SetLabel(
         Name("PRESSURE"),
         message,
         m_negative
      );

      ChartRedraw();
   }

   //+----------------------------------------------------------------+
   //| Destruir painel                                                  |
   //+----------------------------------------------------------------+

   void Destroy()
   {
      ObjectDelete(
         0,
         Name("BACKGROUND")
      );

      ObjectDelete(
         0,
         Name("TITLE")
      );

      ObjectDelete(
         0,
         Name("STATUS")
      );

      ObjectDelete(
         0,
         Name("PRESSURE")
      );

      ObjectDelete(
         0,
         Name("STATE")
      );

      ObjectDelete(
         0,
         Name("ZSCORE")
      );

      ObjectDelete(
         0,
         Name("PERCENTILE")
      );

      ObjectDelete(
         0,
         Name("MOMENTUM")
      );

      ObjectDelete(
         0,
         Name("ACCELERATION")
      );

      ObjectDelete(
         0,
         Name("UPDATED")
      );

      ChartRedraw();
   }
};

//+------------------------------------------------------------------+

#endif

//+------------------------------------------------------------------+