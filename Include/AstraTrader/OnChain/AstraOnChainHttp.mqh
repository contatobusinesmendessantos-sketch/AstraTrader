//+------------------------------------------------------------------+
//| AstraOnChainHttp.mqh                                             |
//| Small, opt-in WebRequest adapter.                                |
//+------------------------------------------------------------------+
#ifndef ASTRA_ONCHAIN_HTTP_MQH
#define ASTRA_ONCHAIN_HTTP_MQH
#property strict

#include <AstraTrader\OnChain\AstraOnChainTypes.mqh>

class AstraOnChainHttp
  {
  private:
   int m_timeout;
  public:
   AstraOnChainHttp() { m_timeout=5000; }
   void SetTimeout(const int milliseconds) { if(milliseconds>0) m_timeout=milliseconds; }

   bool Get(const string url,AstraOnChainHttpResponse &response)
     {
      response.statusCode=-1;
      response.body="";
      response.headers="";
      response.error="";
      response.success=false;

      if(url=="")
        {
         response.error="empty_url";
         return false;
        }

      string requestHeaders="";
      uchar requestData[];
      uchar responseData[];
      string responseHeaders="";

      ResetLastError();

      const int code=WebRequest(
        "GET",
        url,
        requestHeaders,
        m_timeout,
        requestData,
        responseData,
        responseHeaders
      );

      response.statusCode=code;
      response.body=CharArrayToString(responseData);
      response.headers=responseHeaders;

      if(code<0)
        {
         response.error="WebRequest failed. MT5 error=" + IntegerToString(GetLastError());
         return false;
        }

      response.success=(code>=200 && code<300);
      if(!response.success)
        {
         response.error="http_" + IntegerToString(code);
         return false;
        }

      return true;
     }
  };
#endif
