//+------------------------------------------------------------------+
//| AstraStreamingTypes.mqh                                          |
//+------------------------------------------------------------------+
#ifndef ASTRA_STREAMING_TYPES_MQH
#define ASTRA_STREAMING_TYPES_MQH
#property strict

enum ENUM_ASTRA_STREAM_STATE { ASTRA_STREAM_DISABLED=0, ASTRA_STREAM_READY=1, ASTRA_STREAM_RUNNING=2, ASTRA_STREAM_ERROR=3 };
enum ENUM_ASTRA_STREAM_TOPIC
  {
   ASTRA_STREAM_BTC_TRADE=0,
   ASTRA_STREAM_ORDER_BOOK=1,
   ASTRA_STREAM_NETWORK_EVENT=2,
   ASTRA_STREAM_BTC_PRICE=3
  };
struct AstraBtcTradeEvent
  {
   double price;
   double volume;
   bool buyerInitiated;
   datetime timestamp;
  };
struct AstraOrderBookEvent
  {
   double bestBid;
   double bestAsk;
   double bidVolume;
   double askVolume;
   datetime timestamp;
  };
struct AstraNetworkEvent
  {
   string name;
   double value;
   datetime timestamp;
  };
struct AstraBtcPriceEvent
  {
   double price;
   datetime timestamp;
  };
struct AstraStreamingEvent
  {
   ENUM_ASTRA_STREAM_TOPIC topic;
   string payload;
   datetime timestamp;
   ulong sequence;
  };
struct AstraStreamingStatus
  {
   ENUM_ASTRA_STREAM_STATE state;
   ulong eventsReceived;
   datetime lastEventTime;
   string error;
  };
#endif
