//+------------------------------------------------------------------+
//| Interfaces.mqh                                                   |
//| Astra Trader AI                                                  |
//|                                                                  |
//| CONTRATOS AUXILIARES / TELEMETRIA                                |
//|                                                                  |
//| IMPORTANTE:                                                      |
//| AnalysisContext continua sendo a fonte central de verdade       |
//| do pipeline.                                                     |
//|                                                                  |
//| Este arquivo NÃO redeclara ENUM_DECISION, ENUM_BIAS,             |
//| ENUM_REGIME ou outros enums já existentes em Types.mqh.         |
//+------------------------------------------------------------------+
#ifndef ASTRA_INTERFACES_MQH
#define ASTRA_INTERFACES_MQH

#property strict

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>


//==================================================================
// ESTADO DE DECISÃO PARA TELEMETRIA
//
// IMPORTANTE:
// Não utilizar DECISION_BUY / DECISION_SELL aqui.
//
// Esses identificadores pertencem a ENUM_DECISION em Types.mqh.
//==================================================================
enum ENUM_ASTRA_DECISION_STATE
{
   ASTRA_DECISION_NO_SIGNAL = 0,
   ASTRA_DECISION_BUY,
   ASTRA_DECISION_SELL,
   ASTRA_DECISION_BLOCKED_RISK,
   ASTRA_DECISION_BLOCKED_REGIME,
   ASTRA_DECISION_BLOCKED_SPREAD,
   ASTRA_DECISION_BLOCKED_SESSION,
   ASTRA_DECISION_BLOCKED_NEWS
};


//==================================================================
// MARKET CONTEXT
//
// DTO auxiliar para telemetria, logging ou integração futura.
//
// NÃO substitui AnalysisContext.
//
// O pipeline principal continua usando:
//     AnalysisContext
//==================================================================
struct MarketContext
{
   //===============================================================
   // IDENTIDADE
   //===============================================================

   string symbol;

   ENUM_TIMEFRAMES timeframe;


   //===============================================================
   // SAÍDAS DE INTELIGÊNCIA
   //===============================================================

   string bias;
   string state;
   string regime;


   //===============================================================
   // SCORES
   //===============================================================

   double institutionalScore;
   double probability;
   double confidence;

   double bullPower;
   double bearPower;


   //===============================================================
   // DECISÃO / RISCO
   //===============================================================

   ENUM_ASTRA_DECISION_STATE decisionState;

   string riskStatus;

   bool isRiskAllowed;


   //===============================================================
   // FLAGS ESTRUTURAIS
   //===============================================================

   bool hasBOS;
   bool hasCHOCH;
   bool hasLiquiditySweep;
   bool hasFVG;
};


//==================================================================
// RESET MARKET CONTEXT
//
// Função auxiliar externa ao struct para manter compatibilidade
// com o modelo estrutural do MQL5.
//==================================================================
void ResetMarketContext(
   MarketContext &context
)
{
   context.symbol =
      "";

   context.timeframe =
      PERIOD_CURRENT;

   context.bias =
      "NEUTRAL";

   context.state =
      "INDEFINIDO";

   context.regime =
      "TRANSICAO";

   context.institutionalScore =
      0.0;

   context.probability =
      0.0;

   context.confidence =
      0.0;

   context.bullPower =
      0.0;

   context.bearPower =
      0.0;

   context.decisionState =
      ASTRA_DECISION_NO_SIGNAL;

   context.riskStatus =
      "INITIALIZING";

   context.isRiskAllowed =
      false;

   context.hasBOS =
      false;

   context.hasCHOCH =
      false;

   context.hasLiquiditySweep =
      false;

   context.hasFVG =
      false;
}


//==================================================================
// INTERFACE ABSTRATA DOS ENGINES
//
// Esta é a versão compatível com a arquitetura atual.
//
// Os engines devem receber AnalysisContext.
//
// IMPORTANTE:
// Nem todos os engines atuais precisam herdar desta interface.
// Ela pode ser usada gradualmente para padronização futura.
//==================================================================
class IMarketEngine
{
public:

   //===============================================================
   // DESTRUTOR VIRTUAL
   //===============================================================

   virtual ~IMarketEngine()
   {
   }


   //===============================================================
   // ANALYZE
   //
   // O contexto central é passado por referência.
   //===============================================================

   virtual bool Analyze(
      AnalysisContext &context
   ) = 0;


   //===============================================================
   // SCORE
   //
   // Contrato:
   // 0..100
   //
   // Para engines direcionais, o sinal deve ser obtido por GetBias().
   //===============================================================

   virtual double GetScore(
      const AnalysisContext &context
   ) const = 0;


   //===============================================================
   // BIAS
   //===============================================================

   virtual ENUM_BIAS GetBias(
      const AnalysisContext &context
   ) const = 0;


   //===============================================================
   // ESTADO
   //===============================================================

   virtual string GetState(
      const AnalysisContext &context
   ) const = 0;


   //===============================================================
   // MOTIVO
   //===============================================================

   virtual string GetReason(
      const AnalysisContext &context
   ) const = 0;


   //===============================================================
   // VALIDADE
   //===============================================================

   virtual bool IsValid(
      const AnalysisContext &context
   ) const = 0;
};


#endif // ASTRA_INTERFACES_MQH
