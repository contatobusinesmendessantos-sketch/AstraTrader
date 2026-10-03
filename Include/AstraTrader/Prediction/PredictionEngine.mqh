//+------------------------------------------------------------------+
//| PredictionEngine.mqh                                             |
//| Astra Trader AI                                                  |
//|                                                                  |
//| ESTÁGIO 11 - PREDICTION                                         |
//|                                                                  |
//| Quick AI heurística + inferência ONNX opcional.                  |
//|                                                                  |
//| Responsabilidade futura:                                         |
//| - carregar modelo ONNX                                           |
//| - construir vetor de features                                    |
//| - executar inferência                                            |
//| - escrever predictionScore / confidence                          |
//|                                                                  |
//| IMPORTANTE:                                                      |
//| - nunca cria BUY / SELL                                          |
//| - nunca altera decision                                          |
//| - nunca libera executionAllowed                                  |
//+------------------------------------------------------------------+
#ifndef ASTRA_PREDICTIONENGINE_MQH
#define ASTRA_PREDICTIONENGINE_MQH

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>

// IMPORTANTE:
// IPredictionEngine.mqh está na mesma pasta deste arquivo.
#include "IPredictionEngine.mqh"


class PredictionEngine : public IPredictionEngine
{
private:

   bool   m_initialized;
   bool   m_modelLoaded;
   long   m_onnxHandle;
   string m_modelPath;
   string m_modelResolvedPath;
   string m_modelArtifactHash;
   string m_status;

   bool HashModelArtifact(const string path, string &hash)
   {
      const int handle = FileOpen(path, FILE_READ | FILE_BIN);
      if(handle == INVALID_HANDLE)
         return false;

      const ulong fileSize = FileSize(handle);
      if(fileSize == 0 || fileSize > 2147483647)
      {
         FileClose(handle);
         return false;
      }

      uchar bytes[];
      const int expectedBytes = (int)fileSize;
      if(ArrayResize(bytes, expectedBytes) != expectedBytes)
      {
         FileClose(handle);
         return false;
      }

      const uint readBytes = FileReadArray(handle, bytes, 0, expectedBytes);
      FileClose(handle);
      if(readBytes != (uint)expectedBytes)
         return false;

      uchar key[];
      uchar digest[];
      const int digestSize = CryptEncode(CRYPT_HASH_SHA256, bytes, key, digest);
      if(digestSize <= 0)
         return false;

      hash = "";
      for(int index = 0; index < digestSize; ++index)
         hash += StringFormat("%02X", (int)digest[index]);
      return true;
   }

#define ASTRA_PREDICTION_FEATURE_COUNT 8
#define ASTRA_PREDICTION_OUTPUT_COUNT 2
#define ASTRA_PREDICTION_PROBABILITY_SUM_TOLERANCE 0.01

// ONNX contract: input [1,8], output [1,2].
// Output[0] and output[1] are BUY and SELL probabilities in [0,1].
// Their sum must be 1.0 within ASTRA_PREDICTION_PROBABILITY_SUM_TOLERANCE.

   double ClampScore(const double value) const
   {
      return MathMax(-100.0, MathMin(100.0, value));
   }

   double NormalizeSpreadScore(const double spreadPoints) const
   {
      if(ASTRA_MAX_SPREAD_POINTS <= 0)
         return 0.0;

      return MathMin(
         100.0,
         MathMax(0.0, spreadPoints) * 100.0 / ASTRA_MAX_SPREAD_POINTS
      );
   }

   bool IsProbabilityOutput(const double value) const
   {
      return MathIsValidNumber(value) && value >= 0.0 && value <= 1.0;
   }

   bool IsProbabilityPair(
      const double probabilityBuy,
      const double probabilitySell
   ) const
   {
      return MathAbs(
         probabilityBuy + probabilitySell - 1.0
      ) <= ASTRA_PREDICTION_PROBABILITY_SUM_TOLERANCE;
   }

   double CalculateQuickScore(const AnalysisContext &ctx) const
   {
      double score =
         ctx.momentumScore * 0.45 +
         ctx.timeframeScore * 0.25 +
         ctx.volumeDirectionalScore * 0.15 +
         ClampScore(ctx.volatilityPercent) * 0.05 -
         NormalizeSpreadScore(ctx.spreadPoints) * 0.05;

      if(ctx.structuralBias == BIAS_BULLISH)
         score += MathAbs(ctx.structuralScore) * 0.15;
      else
      if(ctx.structuralBias == BIAS_BEARISH)
         score -= MathAbs(ctx.structuralScore) * 0.15;

      return ClampScore(score);
   }

   void ApplyEvidence(
      AnalysisContext &ctx,
      const double probabilityBuy,
      const double probabilitySell,
      const double confidence,
      const string source
   )
   {
      const double total = probabilityBuy + probabilitySell;
      const double score = total > 0.0
         ? ClampScore((probabilityBuy - probabilitySell) / total * 100.0)
         : 0.0;

      ctx.aiProbabilityBuy = probabilityBuy;
      ctx.aiProbabilitySell = probabilitySell;
      ctx.aiConsensusScore = ClampScore(score);
      ctx.aiVolatilityScore = ClampScore(ctx.volatilityPercent);
      ctx.predictionScore = ClampScore(score);
      ctx.predictionConfidence = MathMax(0.0, MathMin(1.0, confidence));
      ctx.confidenceAdjustment = ClampScore(score);
      ctx.expectedMove = 0.0;
      ctx.aiState = LAYER_VALID;

      m_status = source;
   }


   //=================================================================
   // RESET CAMPOS DE PREDIÇÃO
   //=================================================================
   void ResetPredictionFields(
      AnalysisContext &ctx
   )
   {
      ctx.predictionScore =
         0.0;

      ctx.aiProbabilityBuy =
         0.50;

      ctx.aiProbabilitySell =
         0.50;

      ctx.aiDeepProbabilityBuy =
         0.0;

      ctx.aiDeepProbabilitySell =
         0.0;

      ctx.aiDeepAvailable =
         false;

      ctx.aiConsensusScore =
         0.0;

      ctx.aiVolatilityScore =
         0.0;

      ctx.predictionConfidence =
         0.0;

      ctx.confidenceAdjustment =
         0.0;

      ctx.expectedMove =
         0.0;

   }


public:

   //=================================================================
   // CONSTRUTOR
   //=================================================================
   PredictionEngine()
   {
      m_initialized =
         false;

      m_modelLoaded =
         false;

      m_onnxHandle =
         INVALID_HANDLE;

      m_modelPath =
         "";

      m_modelResolvedPath =
         "";

      m_modelArtifactHash =
         "";

      m_status =
         "INITIALIZED";
   }


   //=================================================================
   // DESTRUTOR
   //=================================================================
   virtual ~PredictionEngine()
   {
      Release();
   }


   //=================================================================
   // INIT
   //=================================================================
   bool Init(
      const string modelPath
   ) override
   {
      m_initialized =
         false;

      m_modelLoaded =
         false;

      m_modelPath =
         modelPath;

      m_modelResolvedPath = modelPath;
      m_modelArtifactHash = "";

      if(modelPath == "")
      {
         m_initialized = true;
         m_status = "QUICK_AI_ONLY";
         return true;
      }

      if(!FileIsExist(m_modelResolvedPath) && FileIsExist(modelPath + ".onnx"))
         m_modelResolvedPath = modelPath + ".onnx";

      ResetLastError();
      m_onnxHandle = OnnxCreate(modelPath, ONNX_DEFAULT);

      if(m_onnxHandle == INVALID_HANDLE)
      {
         m_initialized = true;
         m_status = "PREDICTION_QUICK_ONNX_FALLBACK";
         return true;
      }

      ulong inputShape[] = {1, ASTRA_PREDICTION_FEATURE_COUNT};
      ulong outputShape[] = {1, ASTRA_PREDICTION_OUTPUT_COUNT};

      if(!OnnxSetInputShape(m_onnxHandle, 0, inputShape) ||
         !OnnxSetOutputShape(m_onnxHandle, 0, outputShape))
      {
         OnnxRelease(m_onnxHandle);
         m_onnxHandle = INVALID_HANDLE;
         m_initialized = true;
         m_status = "PREDICTION_QUICK_ONNX_FALLBACK";
         return true;
      }

      m_modelLoaded = true;
      m_initialized = true;
      m_status = "QUICK_AI_ONNX_READY";
      if(!HashModelArtifact(m_modelResolvedPath, m_modelArtifactHash))
      {
         m_modelArtifactHash = "";
         PrintFormat("[PREDICTION][IDENTITY][WARNING] model active but artifact hash unavailable | Path=%s",
               m_modelResolvedPath);
      }
      return true;
   }


   //=================================================================
   // PREDICT
   //=================================================================
   bool Predict(
      AnalysisContext &ctx
   ) override
   {
      //==============================================================
      // A PredictionEngine NÃO pode alterar:
      //
      // decision
      // decisionApproved
      // opportunityGrade
      // entryPrice
      // stopLoss
      // takeProfit
      // lotSize
      // executionAllowed
      //==============================================================

      ResetPredictionFields(
         ctx
      );


      //==============================================================
      // VALIDAR CONTEXTO
      //==============================================================

      if(ctx.symbol == "")
      {
         ctx.aiState =
            LAYER_INVALID;

         m_status =
            "INVALID_CONTEXT";

         return false;
      }

      if(!m_initialized)
      {
         ctx.aiState = LAYER_INVALID;
         m_status = "PREDICTION_NOT_INITIALIZED";
         return false;
      }


      if(!ctx.contextValid)
      {
         // Sem contexto validado, o motor continua neutro e
         // não sobe um erro de decisão para a Fase 1.
         ctx.aiState =
            LAYER_NEUTRAL;

         m_status =
            "PREDICTION_NEUTRAL_CONTEXT_NOT_READY";

         return true;
      }


      //==============================================================
      // MODELO AINDA NÃO DISPONÍVEL
      //
      // Mantemos a camada neutra.
      //==============================================================

      const double quickScore = CalculateQuickScore(ctx);
      const double quickProbabilityBuy = MathMax(0.0, MathMin(1.0, 0.50 + quickScore / 200.0));
      const double quickProbabilitySell = MathMax(0.0, MathMin(1.0, 0.50 - quickScore / 200.0));
      double probabilityBuy = quickProbabilityBuy;
      double probabilitySell = quickProbabilitySell;
      double confidence = MathMin(1.0, 0.50 + MathAbs(quickScore) / 200.0);
      string source = "PREDICTION_QUICK";
      bool onnxFallback = false;

      if(m_modelLoaded)
      {
         vectorf features(ASTRA_PREDICTION_FEATURE_COUNT);
         vectorf output(ASTRA_PREDICTION_OUTPUT_COUNT);

         features[0] = (float)(ctx.momentumScore / 100.0);
         features[1] = (float)(ctx.structuralScore / 100.0);
         features[2] = (float)(ctx.timeframeScore / 100.0);
         features[3] = (float)(ctx.volumeDirectionalScore / 100.0);
         features[4] = (float)(ctx.volatilityPercent / 100.0);
         features[5] = (float)(NormalizeSpreadScore(ctx.spreadPoints) / 100.0);
         features[6] = ctx.momentumBullish ? 1.0f : 0.0f;
         features[7] = ctx.momentumBearish ? 1.0f : 0.0f;

         if(OnnxRun(m_onnxHandle, ONNX_NO_CONVERSION, features, output))
         {
            const double buy = (double)output[0];
            const double sell = (double)output[1];

            if(
               IsProbabilityOutput(buy) &&
               IsProbabilityOutput(sell) &&
               IsProbabilityPair(buy, sell)
            )
            {
               ctx.aiDeepProbabilityBuy = buy;
               ctx.aiDeepProbabilitySell = sell;
               ctx.aiDeepAvailable = true;

               const double total = buy + sell;

               if(total <= 0.0)
               {
                  onnxFallback = true;
               }
               else
               {
               probabilityBuy = (quickProbabilityBuy + buy) * 0.50;
               probabilitySell = (quickProbabilitySell + sell) * 0.50;
               const double deepConfidence = MathAbs(buy - sell) / total;
               confidence = (MathMin(1.0, 0.50 + MathAbs(quickScore) / 200.0) + deepConfidence) * 0.50;
               source = "PREDICTION_QUICK_DEEP_CONSENSUS";
               }
            }
            else
            {
               onnxFallback = true;
            }
         }
         else
         {
            onnxFallback = true;
         }
      }

      const double blendedTotal =
         probabilityBuy + probabilitySell;

      if(blendedTotal > 0.0)
      {
         probabilityBuy /= blendedTotal;
         probabilitySell /= blendedTotal;
      }

      ApplyEvidence(ctx, probabilityBuy, probabilitySell, confidence, source);

      if(onnxFallback)
      {
         m_status = "PREDICTION_QUICK_ONNX_FALLBACK";

         // A heurística permanece disponível para telemetria, mas não é
         // tratada como evidência AI válida quando o modelo não confirmou
         // uma inferência real.
         ctx.aiState = LAYER_NEUTRAL;
      }
      else
      if(!m_modelLoaded)
      {
         m_status = "PREDICTION_QUICK_OBSERVER";
         ctx.aiState = LAYER_NEUTRAL;
      }

      return true;
   }


   //=================================================================
   // RELEASE
   //=================================================================
   void Release() override
   {
      if(m_onnxHandle != INVALID_HANDLE)
         OnnxRelease(m_onnxHandle);

      m_onnxHandle = INVALID_HANDLE;
      m_modelLoaded =
         false;

      m_initialized =
         false;

      m_modelPath =
         "";

      m_modelResolvedPath =
         "";

      m_modelArtifactHash =
         "";

      m_status =
         "RELEASED";
   }


   //=================================================================
   // STATUS
   //=================================================================
   bool IsInitialized() const
   {
      return m_initialized;
   }


   bool IsModelLoaded() const
   {
      return m_modelLoaded;
   }


   string GetModelPath() const
   {
      return m_modelPath;
   }

   string GetResolvedModelPath() const
   {
      return m_modelResolvedPath;
   }

   string GetModelArtifactHash() const
   {
      return m_modelArtifactHash;
   }


   string GetStatus() const
   {
      return m_status;
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_PREDICTIONENGINE_MQH
