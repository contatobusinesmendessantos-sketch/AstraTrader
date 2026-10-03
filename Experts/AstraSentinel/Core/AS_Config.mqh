#ifndef __AS_CONFIG_MQH__
#define __AS_CONFIG_MQH__

// ============================================================
// ASTRA SENTINEL v1.0
// Static configuration identifiers. User-facing parameters
// remain in the EA input section.
// ============================================================
#define AS_PRODUCT_NAME        "ASTRA SENTINEL"
#define AS_PRODUCT_VERSION     "1.0.0"
#define AS_PROTOCOL_NAME       "ASTRA LINK"
#define AS_PROTOCOL_VERSION    "1.0"
#define AS_BUILD_NAME          "AS_SENTINEL_V1"
#define AS_DEFAULT_STRATEGY_ID  "WIN_M1_LS_RSI"
#define AS_DEFAULT_SOURCE      "ASTRA_SENTINEL"
#define AS_DEFAULT_TARGET      "ASTRA_TRADER"
#define AS_COMMON_OUTBOUND     "AstraLink\\sentinel_to_astra.csv"
#define AS_COMMON_INBOUND      "AstraLink\\astra_to_sentinel.csv"
#define AS_COMMON_TELEMETRY    "AstraSentinel\\sentinel_telemetry.csv"
#define AS_COMMON_HEARTBEAT    "AstraLink\\sentinel_heartbeat.csv"
#define AS_COMMON_LINK_RUNTIME "AstraSentinel\\sentinel_link_runtime_v2.csv"

bool AS_IsValidLinkNamespace(const string value)
  {
   const int length=StringLen(value);
   if(length<1 || length>64)
      return false;

   for(int i=0;i<length;i++)
     {
      const ushort ch=StringGetCharacter(value,i);
      if(!((ch>='A' && ch<='Z') || (ch>='a' && ch<='z') ||
           (ch>='0' && ch<='9') || ch=='_' || ch=='-'))
         return false;
     }
   return true;
  }

bool AS_IsTestLinkNamespace(const string value)
  {
   return(AS_IsValidLinkNamespace(value) &&
          StringFind(value,"ASTRA_SENTINEL_TEST_")==0);
  }

#endif // __AS_CONFIG_MQH__
