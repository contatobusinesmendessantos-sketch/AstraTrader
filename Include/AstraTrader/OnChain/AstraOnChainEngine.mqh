//+------------------------------------------------------------------+
//| AstraOnChainEngine.mqh                                            |
//| Astra Trader AI                                                  |
//|                                                                  |
//| Contexto On-Chain complementar para o pipeline.                  |
//|                                                                  |
//| Este módulo não substitui a análise principal.                  |
//| Ele apenas expõe dados auxiliares para a decisão institucional. |
//+------------------------------------------------------------------+
#ifndef ASTRA_ONCHAIN_ENGINE_MQH
#define ASTRA_ONCHAIN_ENGINE_MQH

struct AstraOnChainSnapshot
{
   string asset;
   string status;
   string source;
   string error;

   long mempoolTransactions;
   long unconfirmedTransactions;
   long latestBlockHeight;

   double btcPrice;
   double networkHashRate;
   double networkDifficulty;
   double exchangeNetflow;
   double realizedValue;
   double marketCap;
};

#define ASTRA_ONCHAIN_READY    "READY"
#define ASTRA_ONCHAIN_STALE    "STALE"
#define ASTRA_ONCHAIN_ERROR    "ERROR"
#define ASTRA_ONCHAIN_DISABLED "DISABLED"

class AstraOnChainEngine
{
private:
   AstraOnChainSnapshot m_snapshot;
   bool m_initialized;

public:
   AstraOnChainEngine()
   {
      m_initialized = false;
      Reset();
   }

   void Reset()
   {
      m_snapshot.asset = "BTC";
      m_snapshot.status = ASTRA_ONCHAIN_DISABLED;
      m_snapshot.source = "";
      m_snapshot.error = "";

      m_snapshot.mempoolTransactions = 0;
      m_snapshot.unconfirmedTransactions = 0;
      m_snapshot.latestBlockHeight = 0;

      m_snapshot.btcPrice = 0.0;
      m_snapshot.networkHashRate = 0.0;
      m_snapshot.networkDifficulty = 0.0;
      m_snapshot.exchangeNetflow = 0.0;
      m_snapshot.realizedValue = 0.0;
      m_snapshot.marketCap = 0.0;
   }

   bool Init()
   {
      m_initialized = true;
      m_snapshot.status = ASTRA_ONCHAIN_READY;
      m_snapshot.source = "local-context";
      m_snapshot.error = "";
      return true;
   }

   bool IsInitialized() const
   {
      return m_initialized;
   }

   bool Refresh()
   {
      if(!m_initialized)
      {
         Reset();
         return false;
      }

      m_snapshot.status = ASTRA_ONCHAIN_READY;
      m_snapshot.source = "local-context";
      m_snapshot.error = "";
      return true;
   }

   AstraOnChainSnapshot GetSnapshot() const
   {
      return m_snapshot;
   }
};

#endif // ASTRA_ONCHAIN_ENGINE_MQH
