#ifndef __AS_LINK_TRANSPORT_MQH__
#define __AS_LINK_TRANSPORT_MQH__

#include "../Core/AS_Config.mqh"
#include "../Core/AS_Types.mqh"
#include "AS_LinkProtocol.mqh"

class CASLinkTransport
  {
private:
   CASLinkProtocol m_protocol;
   string m_namespace;
   string m_outbound_path;
   string m_inbound_path;
   string m_heartbeat_path;
   bool m_use_common_files;
   bool m_configured;

   int CommonFlag() const { return(m_use_common_files ? FILE_COMMON : 0); }

   bool EnsureFolder(const string relative_path) const
     {
      string parts[]; const int n=StringSplit(relative_path,'\\',parts); if(n<=1) return true;
      string current="";
      for(int i=0;i<n-1;i++){ if(current=="") current=parts[i]; else current+="\\"+parts[i]; FolderCreate(current,CommonFlag()); }
      return true;
     }

   bool WriteAtomicText(const string file_name,const string line) const
     {
      const string temp=file_name+".tmp"; EnsureFolder(file_name); if(!m_configured) return false;
      const int common_flag=CommonFlag();
      int handle=FileOpen(temp,FILE_WRITE|FILE_BIN|common_flag|FILE_SHARE_READ|FILE_SHARE_WRITE); if(handle==INVALID_HANDLE) return false;
      const uint expected_bytes=(uint)(StringLen(line+"\r\n")*2); const uint written=FileWriteString(handle,line+"\r\n"); FileFlush(handle);
      const bool complete=(written==expected_bytes && FileSize(handle)==(ulong)expected_bytes); FileClose(handle);
      if(!complete){ FileDelete(temp,common_flag); return false; }
      FileDelete(file_name,common_flag); return FileMove(temp,common_flag,file_name,common_flag|FILE_REWRITE);
     }

   bool ReadText(const string file_name,string &line) const
     {
      line=""; const int common_flag=CommonFlag(); if(!m_configured || !FileIsExist(file_name,common_flag)) return false;
      int handle=FileOpen(file_name,FILE_READ|FILE_BIN|common_flag|FILE_SHARE_READ|FILE_SHARE_WRITE); if(handle==INVALID_HANDLE) return false;
      const int size=(int)FileSize(handle); if(size<=0 || size%2!=0){ FileClose(handle); return false; }
      line=FileReadString(handle,size/2); FileClose(handle); StringReplace(line,"\r",""); StringReplace(line,"\n",""); return(line!="");
     }

public:
   CASLinkTransport(void){ m_namespace=""; m_outbound_path=""; m_inbound_path=""; m_heartbeat_path=""; m_use_common_files=true; m_configured=false; }

   bool Configure(const string link_namespace)
     {
      m_configured=false;
      if(link_namespace==""){ m_namespace="PRODUCTION"; m_outbound_path=AS_COMMON_OUTBOUND; m_inbound_path=AS_COMMON_INBOUND; m_heartbeat_path=AS_COMMON_HEARTBEAT; m_use_common_files=true; m_configured=true; return true; }
      if(!AS_IsValidLinkNamespace(link_namespace)) return false;
      m_namespace=link_namespace; m_outbound_path=link_namespace+"\\sentinel_to_astra.csv"; m_inbound_path=link_namespace+"\\astra_to_sentinel.csv"; m_heartbeat_path=link_namespace+"\\sentinel_heartbeat.csv"; m_use_common_files=false; m_configured=true; return true;
     }

   string LinkNamespace(void) const { return m_namespace; }
   string TransportName(void) const { return(m_use_common_files ? "FILE_COMMON" : "FILE_SANDBOX"); }
   bool PublishSignal(const AS_StrategySignal &signal) const { return WriteAtomicText(m_outbound_path,m_protocol.BuildSignalLine(signal)); }
   bool ReadSignalLine(string &line) const { return ReadText(m_outbound_path,line); }
   bool DeleteSignal(void) const { const int common_flag=CommonFlag(); if(!m_configured || !FileIsExist(m_outbound_path,common_flag)) return true; return FileDelete(m_outbound_path,common_flag); }

   bool ReadAuthorization(AS_Authorization &authorization) const { string line; if(!ReadAuthorizationLine(line)) return false; if(!m_protocol.ParseAuthorizationLine(line,authorization)) return false; return true; }
   bool ReadAuthorizationLine(string &line) const { return ReadText(m_inbound_path,line); }
   bool DeleteAuthorization() const { const int common_flag=CommonFlag(); if(!m_configured || !FileIsExist(m_inbound_path,common_flag)) return true; return FileDelete(m_inbound_path,common_flag); }
   bool ConsumeAuthorization(const ulong expected_cycle_id,AS_Authorization &authorization) const { if(!ReadAuthorization(authorization)) return false; if(authorization.cycle_id!=expected_cycle_id) return false; return DeleteAuthorization(); }

   bool PublishTestAuthorization(const ulong cycle_id,const AS_AuthorizationStatus status,const string reason,const double approved_volume=0.0,const double stop_loss_points=0.0,const double take_profit_points=0.0,const string protocol_version="1.0") const
     { return WriteAtomicText(m_inbound_path,m_protocol.BuildAuthorizationLine(cycle_id,status,reason,approved_volume,stop_loss_points,take_profit_points,protocol_version)); }
   bool PublishTestAuthorizationLine(const string line) const { return WriteAtomicText(m_inbound_path,line); }

   bool PublishHeartbeat(const string state,const ulong last_cycle,const datetime last_bar) const
     {
      const string line="1.0;HEARTBEAT;ASTRA_SENTINEL;"+TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS)+";"+state+";"+(string)last_cycle+";"+TimeToString(last_bar,TIME_DATE|TIME_SECONDS);
      return WriteAtomicText(m_heartbeat_path,line);
     }
  };

#endif // __AS_LINK_TRANSPORT_MQH__
