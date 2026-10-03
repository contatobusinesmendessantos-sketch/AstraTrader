//+------------------------------------------------------------------+
//| IPredictionEngine.mqh                                            |
//| Astra Trader AI                                                  |
//|                                                                  |
//| INTERFACE OFICIAL DO ESTÁGIO 11 - PREDICTION                    |
//|                                                                  |
//| RESPONSABILIDADES DO IMPLEMENTADOR:                              |
//| - carregar o modelo                                              |
//| - produzir probabilidades                                        |
//| - produzir score direcional                                      |
//| - produzir confiança da previsão                                 |
//|                                                                  |
//| NÃO RESPONSABILIDADES:                                           |
//| - decisão BUY/SELL                                               |
//| - aprovação estratégica                                          |
//| - opportunity grade                                              |
//| - SL/TP                                                          |
//| - lote                                                            |
//| - execução                                                        |
//|                                                                  |
//| CONTRATO:                                                        |
//| aiProbabilityBuy     = 0..1                                      |
//| aiProbabilitySell    = 0..1                                      |
//| aiDeepProbability*  = raw ONNX outputs when available            |
//| aiDeepAvailable     = true only after valid ONNX inference       |
//| ONNX BUY + SELL     = 1.0 +/- defined tolerance                  |
//| aiConsensusScore     = -100..100                                 |
//| predictionConfidence = 0..1                                      |
//| confidenceAdjustment = consenso direcional assinado -100..100    |
//| expectedMove         = reservado; requer contrato de preço       |
//| aiVolatilityScore    = telemetria de volatilidade da IA          |
//+------------------------------------------------------------------+
#ifndef ASTRA_IPREDICTIONENGINE_MQH
#define ASTRA_IPREDICTIONENGINE_MQH

#property strict

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>


//+------------------------------------------------------------------+
//| IPredictionEngine                                                 |
//+------------------------------------------------------------------+
class IPredictionEngine
{
public:

   //=================================================================
   // DESTRUCTOR
   //=================================================================
   virtual ~IPredictionEngine()
   {
   }


   //=================================================================
   // INIT
   //
   // modelPath:
   // caminho lógico/físico do modelo.
   //
   // O contrato não obriga um formato específico.
   // Pode ser ONNX, modelo estatístico, ML etc.
   //=================================================================
   virtual bool Init(
      const string modelPath
   ) = 0;


   //=================================================================
   // PREDICT
   //
   // Atualiza SOMENTE os campos pertencentes ao Prediction Engine:
   //
   // aiProbabilityBuy
   // aiProbabilitySell
   // aiDeepProbabilityBuy
   // aiDeepProbabilitySell
   // aiDeepAvailable
   // confidenceAdjustment
   // expectedMove (reserved until a price-unit model contract exists)
   // aiVolatilityScore (telemetry only; not decision evidence)
   // aiConsensusScore
   // predictionConfidence
   //
   // NÃO pode alterar:
   //
   // decision
   // decisionApproved
   // opportunityGrade
   // entryPrice
   // stopLoss
   // takeProfit
   // riskReward
   // lotSize
   // executionAllowed
   // executionConfirmed
   // orderSent
   //=================================================================
   virtual bool Predict(
      AnalysisContext &ctx
   ) = 0;


   //=================================================================
   // RELEASE
   //=================================================================
   virtual void Release() = 0;
};

#endif // ASTRA_IPREDICTIONENGINE_MQH
//+------------------------------------------------------------------+
