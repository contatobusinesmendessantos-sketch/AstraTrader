//+------------------------------------------------------------------+
//| ElliottEngine.mqh                                                |
//| Astra Trader AI                                                  |
//| Estágio 10 - Elliott Wave Analysis                               |
//|                                                                  |
//| Responsabilidades:                                               |
//| - Detectar estrutura provável de Elliott                         |
//| - Identificar impulso/correção                                   |
//| - Avaliar ondas 1/2/3/4/5                                        |
//| - Avaliar estruturas A/B/C                                       |
//| - Produzir score estrutural                                     |
//|                                                                  |
//| IMPORTANTE:                                                      |
//| - Não executa ordens                                             |
//| - Não calcula lote                                               |
//| - Não define SL/TP                                                |
//| - Não toma decisão final                                         |
//+------------------------------------------------------------------+
#ifndef ASTRA_ELLIOTTENGINE_MQH
#define ASTRA_ELLIOTTENGINE_MQH

#include <AstraTrader\Analysis\AnalysisContext.mqh>

//==================================================================
// ENUMS
//==================================================================
enum ENUM_ASTRA_ELLIOTT_WAVE
{
   ASTRA_WAVE_NONE = 0,

   ASTRA_WAVE_1,
   ASTRA_WAVE_2,
   ASTRA_WAVE_3,
   ASTRA_WAVE_4,
   ASTRA_WAVE_5,

   ASTRA_WAVE_A,
   ASTRA_WAVE_B,
   ASTRA_WAVE_C,

   ASTRA_WAVE_UNKNOWN
};

//==================================================================
// CLASSE
//==================================================================
class ElliottEngine
{
private:

   bool   m_operational;
   string m_status;

   ENUM_ASTRA_ELLIOTT_WAVE m_wave;

   double m_confidence;
   double m_impulseScore;
   double m_correctionScore;

   bool m_impulsive;
   bool m_corrective;

   //===============================================================
   // CLAMP
   //===============================================================
   double ClampScore(const double value)
   {
      if(value < 0.0)
         return 0.0;

      if(value > 100.0)
         return 100.0;

      return value;
   }

   //===============================================================
   // CANDLE BODY
   //===============================================================
   double Body(const MqlRates &candle)
   {
      return MathAbs(candle.close - candle.open);
   }

   //===============================================================
   // RANGE
   //===============================================================
   double Range(const MqlRates &candle)
   {
      return candle.high - candle.low;
   }

   //===============================================================
   // DIRECTION
   //===============================================================
   int Direction(const MqlRates &candle)
   {
      if(candle.close > candle.open)
         return 1;

      if(candle.close < candle.open)
         return -1;

      return 0;
   }

   //===============================================================
   // RESET
   //===============================================================
   void ResetInternal()
   {
      m_wave            = ASTRA_WAVE_NONE;

      m_confidence      = 0.0;
      m_impulseScore    = 0.0;
      m_correctionScore = 0.0;

      m_impulsive       = false;
      m_corrective      = false;

      m_status          = "RESET";
   }

   //===============================================================
   // ANALISA ESTRUTURA DE IMPULSO
   //===============================================================
   void AnalyzeImpulse(
      MqlRates &rates[],
      const int count
   )
   {
      if(count < 5)
         return;

      int bullish = 0;
      int bearish = 0;

      double totalBody = 0.0;
      double totalRange = 0.0;

      for(int i = 0; i < 5; i++)
      {
         int dir = Direction(rates[i]);

         if(dir > 0)
            bullish++;

         if(dir < 0)
            bearish++;

         totalBody  += Body(rates[i]);
         totalRange += Range(rates[i]);
      }

      if(totalRange <= 0.0)
         return;

      double bodyRatio = totalBody / totalRange;

      // Estrutura predominantemente bullish
      if(bullish >= 3)
      {
         m_impulseScore += 25.0;

         if(bullish >= 4)
            m_impulseScore += 15.0;
      }

      // Estrutura predominantemente bearish
      if(bearish >= 3)
      {
         m_impulseScore += 25.0;

         if(bearish >= 4)
            m_impulseScore += 15.0;
      }

      // Corpos relativamente fortes
      if(bodyRatio >= 0.45)
         m_impulseScore += 20.0;

      // Consistência estrutural
      double firstBody  = Body(rates[4]);
      double middleBody = Body(rates[2]);
      double lastBody   = Body(rates[0]);

      if(middleBody > firstBody &&
         middleBody > lastBody)
      {
         m_impulseScore += 20.0;
      }

      m_impulseScore =
         ClampScore(m_impulseScore);

      if(m_impulseScore >= 60.0)
      {
         m_impulsive = true;

         // A identificação exata da onda é mantida conservadora.
         // O engine primeiro confirma a existência de uma estrutura
         // impulsiva antes de classificar a onda.
         m_wave = ASTRA_WAVE_UNKNOWN;
      }
   }

   //===============================================================
   // ANALISA ESTRUTURA CORRETIVA
   //===============================================================
   void AnalyzeCorrection(
      MqlRates &rates[],
      const int count
   )
   {
      if(count < 5)
         return;

      int directionChanges = 0;

      int previousDirection =
         Direction(rates[count - 1]);

      for(int i = count - 2; i >= 0; i--)
      {
         int currentDirection =
            Direction(rates[i]);

         if(currentDirection == 0)
            continue;

         if(previousDirection != 0 &&
            currentDirection != previousDirection)
         {
            directionChanges++;
         }

         previousDirection = currentDirection;
      }

      // Correções normalmente apresentam maior alternância
      // de direção que uma sequência impulsiva simples.
      if(directionChanges >= 2)
         m_correctionScore += 35.0;

      if(directionChanges >= 3)
         m_correctionScore += 20.0;

      // Avaliação de retração relativa
      double high = rates[0].high;
      double low  = rates[0].low;

      for(int i = 1; i < count; i++)
      {
         if(rates[i].high > high)
            high = rates[i].high;

         if(rates[i].low < low)
            low = rates[i].low;
      }

      double range = high - low;

      if(range > 0.0)
      {
         double lastPrice = rates[0].close;

         double position =
            (lastPrice - low) / range;

         if(position > 0.20 &&
            position < 0.80)
         {
            m_correctionScore += 20.0;
         }
      }

      // Corpo médio menor favorece cenário corretivo.
      double bodySum  = 0.0;
      double rangeSum = 0.0;

      for(int i = 0; i < count; i++)
      {
         bodySum  += Body(rates[i]);
         rangeSum += Range(rates[i]);
      }

      if(rangeSum > 0.0)
      {
         double ratio =
            bodySum / rangeSum;

         if(ratio < 0.45)
            m_correctionScore += 25.0;
      }

      m_correctionScore =
         ClampScore(m_correctionScore);

      if(m_correctionScore >= 60.0)
      {
         m_corrective = true;

         m_wave = ASTRA_WAVE_UNKNOWN;
      }
   }

   //===============================================================
   // CLASSIFICA PROVAVEL ESTRUTURA
   //===============================================================
   void Classify()
   {
      if(m_impulsive &&
         !m_corrective)
      {
         m_confidence =
            m_impulseScore;

         return;
      }

      if(m_corrective &&
         !m_impulsive)
      {
         m_confidence =
            m_correctionScore;

         return;
      }

      if(m_impulsive &&
         m_corrective)
      {
         m_confidence =
            MathMax(
               m_impulseScore,
               m_correctionScore
            );

         return;
      }

      m_wave       = ASTRA_WAVE_NONE;
      m_confidence = 0.0;
   }

public:

   //===============================================================
   // CONSTRUTOR
   //===============================================================
   ElliottEngine()
   {
      m_operational = true;

      ResetInternal();

      m_status = "INITIALIZED";
   }

   //===============================================================
   // DESTRUTOR
   //===============================================================
   ~ElliottEngine()
   {
      m_operational = false;
   }

   //===============================================================
   // RESET
   //===============================================================
   void Reset()
   {
      ResetInternal();

      m_operational = true;
      m_status      = "READY";
   }

   //===============================================================
   // OPERATIONAL
   //===============================================================
   bool IsSystemOperational() const
   {
      return m_operational;
   }

   //===============================================================
   // STATUS
   //===============================================================
   string GetStatus() const
   {
      return m_status;
   }

   //===============================================================
   // ANALYZE
   //
   // Esta assinatura é compatível com:
   //
   // m_elliott.Analyze(Context)
   //===============================================================
   bool Analyze(AnalysisContext &context)
   {
      if(!m_operational)
      {
         m_status = "ENGINE_NOT_OPERATIONAL";
         return false;
      }

      ResetInternal();

      //============================================================
      // VALIDA CONTEXTO
      //============================================================
      if(!context.Validate())
      {
         m_status = "INVALID_CONTEXT";
         return false;
      }

      //============================================================
      // VALIDA DADOS BÁSICOS
      //============================================================
      if(context.symbol == "")
      {
         m_status = "INVALID_SYMBOL";
         return false;
      }

      //============================================================
      // CARREGA HISTÓRICO
      //============================================================
      MqlRates rates[];

      ArraySetAsSeries(rates, true);

      int copied =
         CopyRates(
            context.symbol,
            context.primaryTF,
            0,
            21,
            rates
         );

      if(copied < 10)
      {
         m_status = "INSUFFICIENT_DATA";
         return false;
      }

      //============================================================
      // ANÁLISE IMPULSIVA
      //============================================================
      AnalyzeImpulse(
         rates,
         copied
      );

      //============================================================
      // ANÁLISE CORRETIVA
      //============================================================
      AnalyzeCorrection(
         rates,
         copied
      );

      //============================================================
      // CLASSIFICAÇÃO
      //============================================================
      Classify();

      //============================================================
      // ESTADO FINAL
      //============================================================
      if(m_impulsive || m_corrective)
         m_status = "ANALYSIS_COMPLETE";
      else
         m_status = "NO_CLEAR_WAVE";

      return true;
   }

   //===============================================================
   // WAVE
   //===============================================================
   ENUM_ASTRA_ELLIOTT_WAVE GetWave() const
   {
      return m_wave;
   }

   //===============================================================
   // CONFIDENCE
   //===============================================================
   double GetConfidence() const
   {
      return m_confidence;
   }

   //===============================================================
   // IMPULSE
   //===============================================================
   bool IsImpulsive() const
   {
      return m_impulsive;
   }

   //===============================================================
   // CORRECTION
   //===============================================================
   bool IsCorrective() const
   {
      return m_corrective;
   }

   //===============================================================
   // SCORES
   //===============================================================
   double GetImpulseScore() const
   {
      return m_impulseScore;
   }

   double GetCorrectionScore() const
   {
      return m_correctionScore;
   }

   //===============================================================
   // WAVE TO STRING
   //===============================================================
   string WaveToString() const
   {
      switch(m_wave)
      {
         case ASTRA_WAVE_1:
            return "WAVE_1";

         case ASTRA_WAVE_2:
            return "WAVE_2";

         case ASTRA_WAVE_3:
            return "WAVE_3";

         case ASTRA_WAVE_4:
            return "WAVE_4";

         case ASTRA_WAVE_5:
            return "WAVE_5";

         case ASTRA_WAVE_A:
            return "WAVE_A";

         case ASTRA_WAVE_B:
            return "WAVE_B";

         case ASTRA_WAVE_C:
            return "WAVE_C";

         case ASTRA_WAVE_UNKNOWN:
            return "UNKNOWN";

         default:
            return "NONE";
      }
   }
};

#endif // ASTRA_ELLIOTTENGINE_MQH
