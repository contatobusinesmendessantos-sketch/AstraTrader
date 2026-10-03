//+------------------------------------------------------------------+
//| AstraQuantTypes.mqh                                              |
//+------------------------------------------------------------------+
#ifndef ASTRA_QUANT_TYPES_MQH
#define ASTRA_QUANT_TYPES_MQH
#property strict

struct AstraQuantResult
  {
   bool valid;
   bool hasData;
   int barsUsed;
   int window;
   double correlation30D;
   double rSquared;
   double slope;
   double zScore;
   double percentile;
   double velocity;
   double acceleration;
   double divergence;
   double laggedCorrelation;
   double confidence;
   datetime timestamp;
   string error;
  };
#endif
