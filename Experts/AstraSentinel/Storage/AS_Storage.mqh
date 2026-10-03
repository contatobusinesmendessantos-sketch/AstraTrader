#ifndef __AS_STORAGE_MQH__
#define __AS_STORAGE_MQH__

#include "../Core/AS_Config.mqh"
#include "../Core/AS_Types.mqh"

class CASStorage
  {
private:
   string m_namespace; string m_telemetry_path; string m_runtime_path; bool m_use_common_files; bool m_configured;
   int CommonFlag() const { return(m_use_common_files ? FILE_COMMON : 0); }
   bool EnsureFolder(const string relative_path) const
     { string parts[]; const int n=StringSplit(relative_path,'\\',parts); if(n<=1) return true; string current=""; for(int i=0;i<n-1;i++){ if(current=="") current=parts[i]; else current+="\\"+parts[i]; FolderCreate(current,CommonFlag()); } return true; }
public:
   CASStorage(void){ m_namespace=""; m_telemetry_path=""; m_runtime_path=""; m_use_common_files=true; m_configured=false; }
   bool Configure(const string link_namespace)
     {
      m_configured=false;
      if(link_namespace==""){ m_namespace="PRODUCTION"; m_telemetry_path=AS_COMMON_TELEMETRY; m_runtime_path=AS_COMMON_LINK_RUNTIME; m_use_common_files=true; m_configured=true; return true; }
      if(!AS_IsValidLinkNamespace(link_namespace)) return false;
      m_namespace=link_namespace; m_telemetry_path=link_namespace+"\\sentinel_telemetry.csv"; m_runtime_path=link_namespace+"\\sentinel_link_runtime.csv"; m_use_common_files=false; m_configured=true; return true;
     }
   bool AppendLinkEvent(const AS_LinkRuntimeEvent &event) const
     {
      if(!m_configured) return false; EnsureFolder(m_runtime_path);
      int handle=FileOpen(m_runtime_path,FILE_READ|FILE_WRITE|FILE_CSV|CommonFlag()|FILE_SHARE_READ|FILE_SHARE_WRITE,';'); if(handle==INVALID_HANDLE) return false;
      ResetLastError(); const bool write_header=(FileSize(handle)==0); FileSeek(handle,0,SEEK_END);
      if(write_header) FileWrite(handle,"runtime_timestamp","market_timestamp","message_timestamp","cycle_id","event","protocol_version","link_namespace","message_type","source","target","symbol","timeframe","signal","ma21","rsi9","historical_volatility_pct","price_distance_pct","ls_volatility","candle_positive","link_status","authorization_status","response_reason","transport_status","validation_result","reject_reason","elapsed_ms");
      FileWrite(handle,TimeToString(event.runtime_timestamp,TIME_DATE|TIME_SECONDS),(event.market_timestamp>0 ? TimeToString(event.market_timestamp,TIME_DATE|TIME_SECONDS) : ""),(event.message_timestamp>0 ? TimeToString(event.message_timestamp,TIME_DATE|TIME_SECONDS) : ""),(string)event.cycle_id,event.event_name,event.protocol_version,event.link_namespace,event.message_type,event.source,event.target,event.symbol,(string)event.timeframe,event.signal,DoubleToString(event.ma21,8),DoubleToString(event.rsi9,6),DoubleToString(event.historical_volatility_pct,8),DoubleToString(event.distance_pct,8),DoubleToString(event.ls_index,6),(event.candle_positive ? "1" : "0"),event.link_status,event.authorization_status,event.response_reason,event.transport_status,event.validation_result,event.reject_reason,(string)event.elapsed_ms);
      FileFlush(handle); const int write_error=GetLastError(); FileClose(handle); return(write_error==0);
     }
   bool AppendSnapshot(const AS_StrategySignal &sig,const AS_MarketSnapshot &s,const AS_AuthorizationStatus auth_status,const string auth_reason) const
     {
      if(!m_configured) return false; EnsureFolder(m_telemetry_path); const int common_flag=CommonFlag(); const bool exists=FileIsExist(m_telemetry_path,common_flag);
      int handle=FileOpen(m_telemetry_path,FILE_READ|FILE_WRITE|FILE_CSV|common_flag|FILE_SHARE_READ|FILE_SHARE_WRITE,';'); if(handle==INVALID_HANDLE) return false;
      if(!exists) FileWrite(handle,"timestamp","cycle_id","strategy","symbol","timeframe","signal","open","high","low","close","volume","ma21","rsi9","hv_pct","distance_pct","raw_ls","ls_index","ls_threshold","rsi_entry","rsi_exit","candle_positive","reason","auth_status","auth_reason");
      FileSeek(handle,0,SEEK_END);
      FileWrite(handle,TimeToString(sig.timestamp,TIME_DATE|TIME_SECONDS),(string)sig.cycle_id,sig.strategy_id,s.symbol,(string)s.timeframe,sig.signal_text,DoubleToString(s.open,4),DoubleToString(s.high,4),DoubleToString(s.low,4),DoubleToString(s.close,4),(string)s.volume,DoubleToString(s.ma21,6),DoubleToString(s.rsi9,6),DoubleToString(s.historical_volatility_pct,8),DoubleToString(s.distance_pct,8),DoubleToString(s.raw_ls_index,6),DoubleToString(s.ls_index,6),DoubleToString(sig.ls_threshold,6),DoubleToString(sig.rsi_entry_threshold,6),DoubleToString(sig.rsi_exit_threshold,6),(sig.candle_positive ? "1" : "0"),sig.reason,(string)auth_status,auth_reason);
      FileFlush(handle); FileClose(handle); return true;
     }
  };

#endif // __AS_STORAGE_MQH__
