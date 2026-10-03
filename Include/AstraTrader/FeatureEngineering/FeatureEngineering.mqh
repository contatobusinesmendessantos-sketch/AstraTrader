//+------------------------------------------------------------------+
//| FeatureEngineering.mqh                                           |
//| Astra Trader AI                                                  |
//|                                                                  |
//| Engenharia e normalizacao de features para os motores de IA.     |
//|                                                                  |
//| Este modulo NAO decide BUY/SELL.                                 |
//| Este modulo NAO executa ordens.                                  |
//| Este modulo NAO calcula risco ou lote.                           |
//+------------------------------------------------------------------+
#ifndef ASTRA_FEATUREENGINEERING_MQH
#define ASTRA_FEATUREENGINEERING_MQH

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>
#include <AstraTrader\Core\Config.mqh>

class FeatureEngineering
{
private:

   double m_features[32];

   bool m_initialized;
   bool m_valid;

   //===============================================================
   // CLAMP
   //===============================================================
   double Clamp(const double value,
                const double minValue,
                const double maxValue) const
   {
      return MathMax(minValue,MathMin(maxValue,value));
   }

   //===============================================================
   // NORMALIZA SCORE
   // -100 ... +100
   // para
   // -1 ... +1
   //===============================================================
   double NormalizeScore(const double value) const
   {
      return Clamp(value / 100.0,-1.0,1.0);
   }

   //===============================================================
   // NORMALIZA PROBABILIDADE
   // 0 ... 1
   //===============================================================
   double NormalizeProbability(const double value) const
   {
      return Clamp(value,0.0,1.0);
   }

   //===============================================================
   // BOOLEANO PARA FEATURE
   //===============================================================
   double BoolFeature(const bool value) const
   {
      if(value)
         return 1.0;

      return 0.0;
   }

   //===============================================================
   // RESET
   //===============================================================
   void ResetFeatures()
   {
      for(int i=0;i<32;i++)
         m_features[i]=0.0;

      m_valid=false;
   }

public:

   //===============================================================
   // CONSTRUCTOR
   //===============================================================
   FeatureEngineering()
   {
      m_initialized=true;
      m_valid=false;

      ResetFeatures();
   }

   //===============================================================
   // RESET PUBLICO
   //===============================================================
   void Reset()
   {
      ResetFeatures();
   }

   //===============================================================
   // BUILD
   //===============================================================
   bool Build(const AnalysisContext &ctx)
   {
      ResetFeatures();

      if(!m_initialized)
         return false;

      if(!ctx.contextValid)
         return false;

      if(ctx.dataQuality==ASTRA_DATA_INVALID)
         return false;

      //============================================================
      // 00 - STRUCTURAL BIAS
      //============================================================
      if(ctx.structuralBias==BIAS_BULLISH)
         m_features[0]=1.0;
      else
      if(ctx.structuralBias==BIAS_BEARISH)
         m_features[0]=-1.0;
      else
         m_features[0]=0.0;

      //============================================================
      // 01 - STRUCTURAL SCORE
      //============================================================
      m_features[1]=NormalizeScore(ctx.structuralScore);

      //============================================================
      // 02 - BOS
      //============================================================
      m_features[2]=BoolFeature(ctx.bos);

      //============================================================
      // 03 - CHOCH
      //============================================================
      m_features[3]=BoolFeature(ctx.choch);

      //============================================================
      // 04 - HIGHER HIGH
      //============================================================
      m_features[4]=BoolFeature(ctx.higherHigh);

      //============================================================
      // 05 - LOWER LOW
      //============================================================
      m_features[5]=BoolFeature(ctx.lowerLow);

      //============================================================
      // 06 - LIQUIDITY SCORE
      //============================================================
      m_features[6]=NormalizeScore(ctx.liquidityScore);

      //============================================================
      // 07 - LIQUIDITY SWEEP
      //============================================================
      m_features[7]=BoolFeature(ctx.liquiditySweep);

      //============================================================
      // 08 - LIQUIDITY GRAB
      //============================================================
      m_features[8]=BoolFeature(ctx.liquidityGrab);

      //============================================================
      // 09 - SMART MONEY SCORE
      //============================================================
      m_features[9]=NormalizeScore(ctx.smartMoneyScore);

      //============================================================
      // 10 - ORDER BLOCK STRENGTH
      //============================================================
      m_features[10]=NormalizeScore(ctx.orderBlockStrength);

      //============================================================
      // 11 - BREAKER STRENGTH
      //============================================================
      m_features[11]=NormalizeScore(ctx.breakerStrength);

      //============================================================
      // 12 - INSTITUTIONAL FLOW
      //============================================================
      m_features[12]=NormalizeScore(ctx.institutionalFlowScore);

      //============================================================
      // 13 - ABSORPTION
      //============================================================
      m_features[13]=NormalizeScore(ctx.absorptionScore);

      //============================================================
      // 14 - WYCKOFF SCORE
      //============================================================
      m_features[14]=NormalizeScore(ctx.wyckoffScore);

      //============================================================
      // 15 - SPRING
      //============================================================
      m_features[15]=BoolFeature(ctx.springDetected);

      //============================================================
      // 16 - UPTHRUST
      //============================================================
      m_features[16]=BoolFeature(ctx.upthrustDetected);

      //============================================================
      // 17 - SOS
      //============================================================
      m_features[17]=BoolFeature(ctx.sosDetected);

      //============================================================
      // 18 - SOW
      //============================================================
      m_features[18]=BoolFeature(ctx.sowDetected);

      //============================================================
      // 19 - ELLIOTT SCORE
      //============================================================
      m_features[19]=NormalizeScore(ctx.elliottScore);

      //============================================================
      // 20 - WAVE B
      //============================================================
      m_features[20]=BoolFeature(ctx.waveBDetected);

      //============================================================
      // 21 - WAVE C
      //============================================================
      m_features[21]=BoolFeature(ctx.waveCDetected);

      //============================================================
      // 22 - COMPLEX CORRECTION
      //============================================================
      m_features[22]=BoolFeature(ctx.complexCorrection);

      //============================================================
      // 23 - WAVE X
      //============================================================
      m_features[23]=BoolFeature(ctx.waveXDetected);

      //============================================================
      // 24 - WAVE CONFIDENCE
      //============================================================
      m_features[24]=NormalizeProbability(ctx.waveConfidence);

      //============================================================
      // 25 - REGIME SCORE
      //============================================================
      m_features[25]=NormalizeScore(ctx.regimeScore);

      //============================================================
      // 26 - TREND STRENGTH
      //============================================================
      m_features[26]=NormalizeScore(ctx.trendStrength);

      //============================================================
      // 27 - RANGE STRENGTH
      //============================================================
      m_features[27]=NormalizeScore(ctx.rangeStrength);

      //============================================================
      // 28 - MULTI TIMEFRAME
      //============================================================
      m_features[28]=NormalizeScore(ctx.timeframeScore);

      //============================================================
      // 29 - STRUCTURE AI SCORE
      //============================================================
      m_features[29]=NormalizeScore(ctx.structureAIScore);

      //============================================================
      // 30 - STRUCTURE AI CONFIDENCE
      //============================================================
      m_features[30]=NormalizeProbability(ctx.structureAIConfidence);

      //============================================================
      // 31 - CONFLUENCE
      //============================================================
      m_features[31]=NormalizeScore(ctx.confluenceScore);

      m_valid=true;

      return true;
   }

   //===============================================================
   // GET FEATURE
   //===============================================================
   double GetFeature(const int index) const
   {
      if(index<0 || index>=32)
         return 0.0;

      return m_features[index];
   }

   //===============================================================
   // GET COUNT
   //===============================================================
   int GetFeatureCount() const
   {
      return 32;
   }

   //===============================================================
   // COPIA FEATURES
   //===============================================================
   bool GetFeatures(double &output[]) const
   {
      if(!m_valid)
         return false;

      ArrayResize(output,32);

      for(int i=0;i<32;i++)
         output[i]=m_features[i];

      return true;
   }

   //===============================================================
   // VALIDACAO
   //===============================================================
   bool IsValid() const
   {
      return m_valid;
   }

   //===============================================================
   // DEBUG
   //===============================================================
   string ToString() const
   {
      string result="[FeatureEngineering] ";

      result+="Valid=";
      result+=(m_valid ? "true" : "false");

      result+=" Count=32";

      return result;
   }
};

#endif // ASTRA_FEATUREENGINEERING_MQH
