//+------------------------------------------------------------------+
//|                 ASTRA AI - FVG ENGINE                            |
//|                 Fair Value Gap Detector                          |
//|                                                                  |
//| INTEGRACAO ASTRA TRADER                                          |
//| - Usa AnalysisContext como fonte de dados                        |
//| - Nao usa _Symbol                                                |
//| - Nao usa _Period                                                |
//| - Nao cria uma segunda fonte de dados de mercado                 |
//| - Publica o resultado no AnalysisContext                         |
//| - Nao executa ordens                                             |
//+------------------------------------------------------------------+

#ifndef __FVG_ENGINE_MQH__
#define __FVG_ENGINE_MQH__

#include <AstraTrader\Analysis\AnalysisContext.mqh>

#define ASTRA_FVG_ENGINE_MIN_GAP_POINTS 1.0

class FVGEngine
{
private:

   //=================================================================
   // RESULTADO INTERNO DO DETECTOR
   //=================================================================

   double m_bullishFVGHigh;
   double m_bullishFVGLow;

   double m_bearishFVGHigh;
   double m_bearishFVGLow;

   bool   m_hasBullishFVG;
   bool   m_hasBearishFVG;

   // Score direcional:
   //   +100 = FVG bullish
   //   -100 = FVG bearish
   //      0 = nenhum FVG
   double m_fvgScore;

   ENUM_LAYER_STATE m_fvgState;

   bool   m_dataValid;

   string m_status;


   //=================================================================
   // RESET INTERNO
   //=================================================================

   void ResetInternal()
   {
      m_bullishFVGHigh = 0.0;
      m_bullishFVGLow  = 0.0;

      m_bearishFVGHigh = 0.0;
      m_bearishFVGLow  = 0.0;

      m_hasBullishFVG = false;
      m_hasBearishFVG = false;

      m_fvgScore = 0.0;

      m_fvgState = LAYER_NEUTRAL;

      m_dataValid = false;

      m_status = "NENHUM FVG";
   }


   //=================================================================
   // VALIDACAO DO CONTEXTO
   //=================================================================

   bool ValidateContext(const AnalysisContext &context)
   {
      // O detector precisa de pelo menos os candles:
      // [0] atual
      // [1] ultimo fechado
      // [2] segundo fechado
      // [3] terceiro fechado

      int bars = ArraySize(context.marketBars);

      if(bars < 4)
      {
         m_dataValid = false;
         m_fvgState  = LAYER_INVALID;
         m_status    = "DADOS INSUFICIENTES";

         return false;
      }

      if(context.symbol == "")
      {
         m_dataValid = false;
         m_fvgState  = LAYER_INVALID;
         m_status    = "SYMBOL INVALIDO";

         return false;
      }

      if(context.point <= 0.0)
      {
         m_dataValid = false;
         m_fvgState  = LAYER_INVALID;
         m_status    = "POINT INVALIDO";

         return false;
      }

      m_dataValid = true;

      return true;
   }


   //=================================================================
   // DETECCAO FVG BULLISH
   //
   // Contrato temporal do AnalysisContext:
   //
   // marketBars[0] = candle atual
   // marketBars[1] = ultimo candle fechado
   // marketBars[2] = segundo candle fechado
   // marketBars[3] = terceiro candle fechado
   //
   // Regra original preservada:
   //
   // low do candle [1] > high do candle [3]
   //=================================================================

   void DetectBullishFVG(const AnalysisContext &context)
   {
      const double highOlder =
         context.marketBars[3].high;

      const double lowRecent =
         context.marketBars[1].low;


      if(
         lowRecent - highOlder >=
         ASTRA_FVG_ENGINE_MIN_GAP_POINTS * context.point
      )
      {
         m_bullishFVGHigh = lowRecent;
         m_bullishFVGLow  = highOlder;

         m_hasBullishFVG = true;
      }
   }


   //=================================================================
   // DETECCAO FVG BEARISH
   //
   // Regra original preservada:
   //
   // high do candle [1] < low do candle [3]
   //=================================================================

   void DetectBearishFVG(const AnalysisContext &context)
   {
      const double lowOlder =
         context.marketBars[3].low;

      const double highRecent =
         context.marketBars[1].high;


      if(
         lowOlder - highRecent >=
         ASTRA_FVG_ENGINE_MIN_GAP_POINTS * context.point
      )
      {
         m_bearishFVGHigh = lowOlder;
         m_bearishFVGLow  = highRecent;

         m_hasBearishFVG = true;
      }
   }


   //=================================================================
   // ANALISE
   //=================================================================

   void Analyze()
   {
      // -------------------------------------------------------------
      // FVG BULLISH
      // -------------------------------------------------------------

      if(m_hasBullishFVG)
      {
         m_fvgScore = 100.0;
         m_fvgState = LAYER_VALID;

         m_status = "FVG COMPRA DETECTADO";

         return;
      }


      // -------------------------------------------------------------
      // FVG BEARISH
      // -------------------------------------------------------------

      if(m_hasBearishFVG)
      {
         m_fvgScore = -100.0;
         m_fvgState = LAYER_VALID;

         m_status = "FVG VENDA DETECTADO";

         return;
      }


      // -------------------------------------------------------------
      // NENHUM FVG
      // -------------------------------------------------------------

      m_fvgScore = 0.0;

      // Dados existem, mas nenhum FVG foi encontrado.
      if(m_dataValid)
         m_fvgState = LAYER_NEUTRAL;
      else
         m_fvgState = LAYER_INVALID;

      m_status = "NENHUM FVG";
   }


   //=================================================================
   // PUBLICA NO ANALYSISCONTEXT
   //
   // Campos atualmente existentes no contrato:
   //
   // context.fvgPresent
   // context.fairValueGap
   // context.bullishFVG
   // context.bearishFVG
   //
   // Os campos detalhados sao publicados para telemetria e comparacao
   // com a deteccao legada do OrderBlockEngine.
   //=================================================================

   void PublishToContext(AnalysisContext &context)
   {
      context.fvgValid =
         m_dataValid;

      context.bullishFVGHigh =
         m_bullishFVGHigh;

      context.bullishFVGLow =
         m_bullishFVGLow;

      context.bearishFVGHigh =
         m_bearishFVGHigh;

      context.bearishFVGLow =
         m_bearishFVGLow;

      context.fvgScore =
         m_fvgScore;

      context.fvgState =
         m_fvgState;
   }


   void LogTelemetry(const AnalysisContext &context) const
   {
      PrintFormat(
         "[FVGEngine] Symbol=%s | TF=%s | Valid=%s | Bullish=%s | "
         "Bearish=%s | BullHigh=%.8f | BullLow=%.8f | "
         "BearHigh=%.8f | BearLow=%.8f | Score=%.2f | State=%s",
         context.symbol,
         EnumToString(context.primaryTF),
         m_dataValid ? "true" : "false",
         m_hasBullishFVG ? "true" : "false",
         m_hasBearishFVG ? "true" : "false",
         m_bullishFVGHigh,
         m_bullishFVGLow,
         m_bearishFVGHigh,
         m_bearishFVGLow,
         m_fvgScore,
         EnumToString(m_fvgState)
      );
   }


public:


   //=================================================================
   // CONSTRUTOR
   //=================================================================

   FVGEngine()
   {
      ResetInternal();
   }


   //=================================================================
   // UPDATE PRINCIPAL
   //
   // O novo contrato recebe explicitamente o AnalysisContext.
   //
   // Isso elimina a dependencia de:
   //   _Symbol
   //   _Period
   //
   // e faz o FVG trabalhar sobre a mesma fonte temporal do AstraTrader.
   //=================================================================

   bool Update(AnalysisContext &context)
   {
      ResetInternal();


      // -------------------------------------------------------------
      // 1. VALIDAR CONTEXTO
      // -------------------------------------------------------------

      if(!ValidateContext(context))
      {
         PublishToContext(context);
         LogTelemetry(context);

         return false;
      }


      // -------------------------------------------------------------
      // 2. DETECTAR FVG
      // -------------------------------------------------------------

      DetectBullishFVG(context);

      DetectBearishFVG(context);


      // -------------------------------------------------------------
      // 3. ANALISAR
      // -------------------------------------------------------------

      Analyze();


      // -------------------------------------------------------------
      // 4. PUBLICAR RESULTADO
      // -------------------------------------------------------------

      PublishToContext(context);
      LogTelemetry(context);


      return true;
   }


   //=================================================================
   // STATUS DOS DADOS
   //=================================================================

   bool IsDataValid() const
   {
      return m_dataValid;
   }


   //=================================================================
   // PRESENCA DE FVG BULLISH
   //=================================================================

   bool IsBullishFVG() const
   {
      return m_hasBullishFVG;
   }


   //=================================================================
   // PRESENCA DE FVG BEARISH
   //=================================================================

   bool IsBearishFVG() const
   {
      return m_hasBearishFVG;
   }


   //=================================================================
   // FVG BULLISH - LIMITE SUPERIOR
   //=================================================================

   double GetBullishHigh() const
   {
      return m_bullishFVGHigh;
   }


   //=================================================================
   // FVG BULLISH - LIMITE INFERIOR
   //=================================================================

   double GetBullishLow() const
   {
      return m_bullishFVGLow;
   }


   //=================================================================
   // FVG BEARISH - LIMITE SUPERIOR
   //=================================================================

   double GetBearishHigh() const
   {
      return m_bearishFVGHigh;
   }


   //=================================================================
   // FVG BEARISH - LIMITE INFERIOR
   //=================================================================

   double GetBearishLow() const
   {
      return m_bearishFVGLow;
   }


   //=================================================================
   // SCORE DIRECIONAL
   //
   // +100 = bullish
   // -100 = bearish
   //   0  = neutral
   //=================================================================

   double GetScore() const
   {
      return m_fvgScore;
   }


   //=================================================================
   // ESTADO DA CAMADA
   //=================================================================

   ENUM_LAYER_STATE GetState() const
   {
      return m_fvgState;
   }


   //=================================================================
   // STATUS TEXTUAL
   //=================================================================

   string GetStatus() const
   {
      return m_status;
   }


   //=================================================================
   // POSSUI QUALQUER FVG?
   //=================================================================

   bool HasFVG() const
   {
      return
         m_hasBullishFVG ||
         m_hasBearishFVG;
   }
};


#endif