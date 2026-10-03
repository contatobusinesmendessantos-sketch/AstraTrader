#ifndef ASTRA_ONCHAIN_TYPES_MQH
#define ASTRA_ONCHAIN_TYPES_MQH

struct AstraOnChainHttpResponse
{
   int statusCode;
   string body;
   string headers;
   string error;
   bool success;
};

struct AstraOnChainSnapshot
{
   bool valid;
   bool connected;
   bool stale;
   bool analysisReady;
   datetime timestamp;
   ulong latencyMs;
   string error;
   long mempoolBytes;
   long mempoolTxCount;
   double mempoolUsageRatio;
   double mempoolPressure;
   long latestBlockHeight;
   datetime latestBlockTime;
   string latestBlockHash;
   long latestBlockSize;
   long latestBlockTxCount;
   double btcPrice;
   double btcPriceChange24h;
   double btcVolume24h;
   double networkHashrate;
   double networkDifficulty;
   double networkTxRate;
   double blockIntervalSeconds;
   double txPerBlock;

   void Reset()
   {
      valid=false;
      connected=false;
      stale=true;
      analysisReady=false;
      timestamp=0;
      latencyMs=0;
      error="";
      mempoolBytes=0;
      mempoolTxCount=0;
      mempoolUsageRatio=0.0;
      mempoolPressure=0.0;
      latestBlockHeight=0;
      latestBlockTime=0;
      latestBlockHash="";
      latestBlockSize=0;
      latestBlockTxCount=0;
      btcPrice=0.0;
      btcPriceChange24h=0.0;
      btcVolume24h=0.0;
      networkHashrate=0.0;
      networkDifficulty=0.0;
      networkTxRate=0.0;
      blockIntervalSeconds=0.0;
      txPerBlock=0.0;
   }
};

#endif
