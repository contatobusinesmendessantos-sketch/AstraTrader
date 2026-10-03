//+------------------------------------------------------------------+
//| LearningEngine.mqh                                               |
//| Astra Trader AI                                                  |
//|                                                                  |
//| Estagio 12 - Learning / Dataset Engine                           |
//|                                                                  |
//| IMPORTANTE:                                                      |
//|   Este modulo NAO treina modelos de IA.                          |
//|   O treinamento deve ocorrer externamente, por exemplo em Python. |
//|                                                                  |
//| Responsabilidades iniciais:                                      |
//|   - registrar decisoes                                            |
//|   - registrar contexto                                            |
//|   - registrar resultados                                          |
//|   - preparar interface para exportacao de datasets                |
//+------------------------------------------------------------------+
#ifndef ASTRA_LEARNINGENGINE_MQH
#define ASTRA_LEARNINGENGINE_MQH

#include <AstraTrader\Analysis\AnalysisContext.mqh>

//==================================================================
// LEARNING ENGINE
//==================================================================
class LearningEngine
{
private:

   //===============================================================
   // ESTATISTICAS BASICAS DA SESSAO
   //===============================================================
   ulong  m_decisionsRecorded;
   ulong  m_outcomesRecorded;

   double m_totalProfit;
   double m_totalDrawdown;
   double m_averageRR;

   bool   m_initialized;

public:

   //===============================================================
   // CONSTRUCTOR
   //===============================================================
   LearningEngine()
   {
      Reset();
   }

   //===============================================================
   // RESET
   //===============================================================
   void Reset()
   {
      m_decisionsRecorded = 0;
      m_outcomesRecorded  = 0;

      m_totalProfit       = 0.0;
      m_totalDrawdown     = 0.0;
      m_averageRR         = 0.0;

      m_initialized       = true;
   }

   //===============================================================
   // RECORD DECISION
   //===============================================================
   bool RecordDecision(const AnalysisContext &ctx)
   {
      if(!m_initialized)
         Reset();

      //===========================================================
      // VALIDACAO MINIMA
      //===========================================================
      if(ctx.symbol=="")
         return false;

      if(ctx.cycleId==0)
         return false;

      //===========================================================
      // Nesta primeira versao o contexto permanece no
      // AnalysisContext.
      //
      // A persistencia real em CSV/database sera adicionada
      // posteriormente sem alterar o contrato do pipeline.
      //===========================================================
      m_decisionsRecorded++;

      return true;
   }

   //===============================================================
   // RECORD OUTCOME
   //===============================================================
   bool RecordOutcome(
      const ulong ticket,
      const double rr,
      const double profit,
      const double drawdown)
   {
      if(!m_initialized)
         Reset();

      if(ticket==0)
         return false;

      if(!MathIsValidNumber(rr))
         return false;

      if(!MathIsValidNumber(profit))
         return false;

      if(!MathIsValidNumber(drawdown))
         return false;

      m_outcomesRecorded++;

      m_totalProfit += profit;
      m_totalDrawdown += MathMax(0.0,drawdown);

      // Media incremental de RR
      if(m_outcomesRecorded==1)
      {
         m_averageRR=rr;
      }
      else
      {
         m_averageRR=
            ((m_averageRR*(double)(m_outcomesRecorded-1))
             +rr)
            /(double)m_outcomesRecorded;
      }

      return true;
   }

   //===============================================================
   // EXPORT DATASET
   //===============================================================
   bool ExportDataset(const string csvPath)
   {
      //===========================================================
      // A exportacao real sera implementada em uma etapa posterior.
      //
      // Nao criamos arquivos automaticamente nesta versao porque
      // o formato definitivo do dataset ainda deve ser definido.
      //===========================================================
      if(csvPath=="")
         return false;

      return false;
   }

   //===============================================================
   // GENERIC ANALYZE
   //===============================================================
   bool Analyze(const AnalysisContext &ctx)
   {
      return RecordDecision(ctx);
   }

   //===============================================================
   // GETTERS
   //===============================================================
   ulong GetDecisionsRecorded() const
   {
      return m_decisionsRecorded;
   }

   ulong GetOutcomesRecorded() const
   {
      return m_outcomesRecorded;
   }

   double GetTotalProfit() const
   {
      return m_totalProfit;
   }

   double GetTotalDrawdown() const
   {
      return m_totalDrawdown;
   }

   double GetAverageRR() const
   {
      return m_averageRR;
   }

   bool IsInitialized() const
   {
      return m_initialized;
   }
};

#endif // ASTRA_LEARNINGENGINE_MQH
