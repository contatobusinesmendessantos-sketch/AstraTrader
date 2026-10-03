#property strict
#property version   "1.00"
#property description "ASTRA SENTINEL v1.0 - Mini Index specialist / ASTRA LINK v1.0"
#property description "Generates strategy signals and delegates authorization/execution to ASTRA TRADER."

#include "Core/AS_Config.mqh"
#include "Core/AS_Types.mqh"
#include "Indicators/AS_IndicatorEngine.mqh"
#include "Strategy/AS_StrategyEngine.mqh"
#include "Link/AS_LinkTransport.mqh"
#include "Storage/AS_Storage.mqh"

input group "ASTRA SENTINEL | Identity"
input string InpStrategyID=AS_DEFAULT_STRATEGY_ID;
input string InpLinkedTarget=AS_DEFAULT_TARGET;
input bool InpEnabled=true;
input group "ASTRA SENTINEL | Market"
input ENUM_TIMEFRAMES InpTimeframe=PERIOD_M1;
input int InpMA21Period=21;
input int InpRSI9Period=9;
input int InpHistoricalVolPeriod=21;
input int InpNormalizationPeriod=21;
input group "ASTRA SENTINEL | Entry"
input bool InpEnableEntry=true;
input double InpLSVolatilityThreshold=25.0;
input double InpRSIEntryThreshold=30.0;
input group "ASTRA SENTINEL | Exit"
input bool InpEnableExit=true;
input double InpRSIExitThreshold=70.0;
input bool InpEnableTimeExit=true;
input int InpExitHour=12;
input int InpExitMinute=0;
input group "ASTRA SENTINEL | Runtime"
input int InpTimerSeconds=1;
input int InpRateBuffer=256;
input bool InpPublishOnlySignals=false;
input int InpLinkTimeoutSeconds=5;
input bool InpDiagnosticMode=false;
input string InpLinkNamespace="";
input bool InpLinkDebug=false;

CASIndicatorEngine g_indicators; CASStrategyEngine g_strategy; CASLinkTransport g_link; CASLinkProtocol g_protocol; CASStorage g_storage;
ulong g_cycle_id=0; datetime g_last_closed_bar=0; string g_last_signal="NONE"; string g_last_reason="INIT"; string g_last_auth="UNKNOWN"; string g_last_auth_reason="";
AS_StrategySignal g_pending_signal; AS_MarketSnapshot g_pending_snapshot; bool g_has_pending_signal=false; bool g_diagnostic_signal_created=false; bool g_pending_poll_recorded=false; ulong g_pending_started_ms=0; ulong g_last_expired_cycle=0; ulong g_last_completed_cycle=0;

int BarsNeeded(){ return MathMax(InpRateBuffer,MathMax(InpNormalizationPeriod+InpMA21Period+InpHistoricalVolPeriod+32,InpRSI9Period*10+64)); }
bool LoadRates(MqlRates &rates[]){ ArraySetAsSeries(rates,true); const int copied=CopyRates(_Symbol,InpTimeframe,0,BarsNeeded(),rates); return(copied>=BarsNeeded()); }
void RenderPanel(const AS_MarketSnapshot &s,const AS_StrategySignal &sig){ string panel; panel+="ASTRA SENTINEL v1.0\n"; panel+="ASTRA LINK v1.0 | "+_Symbol+" | "+EnumToString(InpTimeframe)+"\n"; panel+="CycleID: "+(string)g_cycle_id+" | Bar: "+TimeToString(s.bar_time,TIME_DATE|TIME_SECONDS)+"\n"; panel+="Close: "+DoubleToString(s.close,_Digits)+" | MA21: "+DoubleToString(s.ma21,_Digits)+"\n"; panel+="RSI9: "+DoubleToString(s.rsi9,2)+" | HV: "+DoubleToString(s.historical_volatility_pct,4)+"%\n"; panel+="Distance: "+DoubleToString(s.distance_pct,4)+"% | LS Raw: "+DoubleToString(s.raw_ls_index,2)+" | LS: "+DoubleToString(s.ls_index,2)+"\n"; panel+="Candle Positive: "+(s.candle_positive?"TRUE":"FALSE")+"\n"; panel+="Signal: "+g_last_signal+" | Reason: "+g_last_reason+"\n"; panel+="Auth: "+g_last_auth+" | "+g_last_auth_reason+"\n"; panel+="Mode: SIGNAL/DELEGATED EXECUTION"; Comment(panel); }
string AuthorizationStatusText(const AS_AuthorizationStatus status){ switch(status){ case AS_AUTH_APPROVED:return "APPROVED"; case AS_AUTH_BLOCKED:return "BLOCKED"; case AS_AUTH_EXECUTED:return "EXECUTED"; case AS_AUTH_ERROR:return "ERROR"; default:return "UNKNOWN"; } }

void RecordLinkEvent(const string event_name,const AS_StrategySignal &sig,const AS_MarketSnapshot &snapshot,const string link_status,const AS_AuthorizationStatus auth_status,const string response_reason,const string transport_status,const ulong elapsed_ms,const ulong event_cycle=0,const datetime message_timestamp=0,const string message_type="SIGNAL",const string validation_result="",const string reject_reason="",const string protocol_version="")
  {
   AS_LinkRuntimeEvent event; ZeroMemory(event); event.runtime_timestamp=TimeLocal(); event.market_timestamp=snapshot.bar_time; event.message_timestamp=(message_timestamp>0 ? message_timestamp : sig.timestamp); event.cycle_id=(event_cycle>0 ? event_cycle : sig.cycle_id); event.protocol_version=(protocol_version=="" ? sig.protocol_version : protocol_version); event.link_namespace=g_link.LinkNamespace(); event.event_name=event_name; event.message_type=message_type; event.source=sig.source; event.target=sig.target; event.symbol=sig.symbol; event.timeframe=sig.timeframe; event.signal=sig.signal_text; event.ma21=sig.ma21; event.rsi9=sig.rsi9; event.historical_volatility_pct=sig.historical_volatility_pct; event.distance_pct=sig.distance_pct; event.ls_index=sig.ls_index; event.candle_positive=sig.candle_positive; event.link_status=link_status; event.authorization_status=(auth_status==AS_AUTH_UNKNOWN ? "" : AuthorizationStatusText(auth_status)); event.response_reason=response_reason; event.transport_status=transport_status; event.validation_result=validation_result; event.reject_reason=reject_reason; event.elapsed_ms=elapsed_ms;
   if(!g_storage.AppendLinkEvent(event)) Print("ASTRA LINK | event trace write failed. event=",event_name," cycle=",event.cycle_id," error=",GetLastError());
   Print("ASTRA LINK | event=",event_name," cycle=",event.cycle_id," state=",link_status," auth=",event.authorization_status," reason=",response_reason," transport=",transport_status," elapsed_ms=",elapsed_ms);
  }
ulong PendingElapsedMs(){ if(!g_has_pending_signal || g_pending_started_ms==0) return 0; return GetTickCount64()-g_pending_started_ms; }
void ClosePending(const string final_state){ Print("ASTRA LINK | pending cycle closed. cycle=",g_pending_signal.cycle_id," final_state=",final_state); g_last_completed_cycle=g_pending_signal.cycle_id; g_has_pending_signal=false; g_pending_started_ms=0; }
void SubmitSignal(const AS_StrategySignal &sig,const AS_MarketSnapshot &snapshot)
  {
   RecordLinkEvent("SIGNAL_CREATED",sig,snapshot,"SIGNAL_CREATED",AS_AUTH_UNKNOWN,sig.reason,"NOT_ATTEMPTED",0);
   if(!g_link.PublishSignal(sig)){ const int error=GetLastError(); g_last_auth="ERROR"; g_last_auth_reason="SIGNAL_TRANSPORT_FAILED"; RecordLinkEvent("REQUEST_FAILED",sig,snapshot,"ERROR",AS_AUTH_ERROR,g_last_auth_reason,"FAILED",0); Print("ASTRA LINK | signal publication failed. cycle=",sig.cycle_id," error=",error); return; }
   RecordLinkEvent("REQUEST_SENT",sig,snapshot,"REQUEST_SENT",AS_AUTH_UNKNOWN,"SIGNAL_REQUEST_PUBLISHED","SUCCESS",0);
   if(sig.direction!=AS_SIGNAL_NONE){ g_pending_signal=sig; g_pending_snapshot=snapshot; g_has_pending_signal=true; g_pending_started_ms=GetTickCount64(); g_pending_poll_recorded=false; g_last_auth="WAITING"; g_last_auth_reason="PENDING"; RecordLinkEvent("PENDING",g_pending_signal,g_pending_snapshot,"PENDING",AS_AUTH_UNKNOWN,"AWAITING_AUTHORIZATION","SUCCESS",0); }
   else RecordLinkEvent("FINAL_STATE",sig,snapshot,"IDLE",AS_AUTH_UNKNOWN,"NO_AUTHORIZATION_REQUIRED","SUCCESS",0);
  }
void RecordRejectedResponse(const string event_name,const string reason,const ulong received_cycle,const datetime response_timestamp,const string validation_result="REJECTED",const string reject_reason="",const string protocol_version="") { RecordLinkEvent(event_name,g_pending_signal,g_pending_snapshot,event_name,AS_AUTH_ERROR,reason,"REJECTED",PendingElapsedMs(),received_cycle,response_timestamp,"AUTH_RESPONSE",validation_result,(reject_reason=="" ? reason : reject_reason),protocol_version); }
void PollAuthorization()
  {
   if(g_has_pending_signal && !g_pending_poll_recorded){ g_pending_poll_recorded=true; RecordLinkEvent("POLL",g_pending_signal,g_pending_snapshot,"POLLING",AS_AUTH_UNKNOWN,"AUTHORIZATION_POLL_STARTED","SUCCESS",PendingElapsedMs()); }
   if(g_has_pending_signal && PendingElapsedMs()>=(ulong)InpLinkTimeoutSeconds*1000){ const ulong elapsed=PendingElapsedMs(); const ulong expired_cycle=g_pending_signal.cycle_id; g_last_expired_cycle=expired_cycle; g_last_auth="TIMEOUT"; g_last_auth_reason="NO_AUTHORIZATION_RESPONSE"; RecordLinkEvent("LINK_TIMEOUT",g_pending_signal,g_pending_snapshot,"TIMEOUT",AS_AUTH_ERROR,g_last_auth_reason,"NO_RESPONSE",elapsed); if(!g_storage.AppendSnapshot(g_pending_signal,g_pending_snapshot,AS_AUTH_ERROR,g_last_auth_reason)) Print("ASTRA LINK | timeout snapshot write failed. cycle=",expired_cycle," error=",GetLastError()); ClosePending("TIMEOUT"); RecordLinkEvent("FINAL_STATE",g_pending_signal,g_pending_snapshot,"IDLE",AS_AUTH_ERROR,"TIMEOUT_CLOSED_PENDING","SUCCESS",elapsed); }
   string line; if(!g_link.ReadAuthorizationLine(line)) return;
   RecordLinkEvent("RESPONSE_FOUND",g_pending_signal,g_pending_snapshot,"RESPONSE_FOUND",AS_AUTH_UNKNOWN,"AUTH_RESPONSE_FILE_READ","SUCCESS",PendingElapsedMs(),0,0,"AUTH_RESPONSE");
   AS_Authorization auth; string reject_stage; string reject_field; string reject_error;
   if(!g_protocol.ParseAuthorizationLineDetailed(line,auth,reject_stage,reject_field,reject_error)){ if(!g_link.DeleteAuthorization()) Print("ASTRA LINK | could not delete invalid authorization. error=",GetLastError()); g_last_auth="REJECTED"; g_last_auth_reason="PARSE_STAGE="+reject_stage+";FIELD="+reject_field+";ERROR="+reject_error; if(InpLinkDebug) Print("ASTRA LINK | AUTH_RESPONSE_REJECTED namespace=",g_link.LinkNamespace()," stage=",reject_stage," field=",reject_field," error=",reject_error); RecordRejectedResponse("INVALID_RESPONSE_REJECTED",g_last_auth_reason,0,0,"REJECTED",g_last_auth_reason,AS_PROTOCOL_VERSION); return; }
   RecordLinkEvent("RESPONSE_PARSED",g_pending_signal,g_pending_snapshot,"PARSED",auth.status,"AUTH_RESPONSE_FIELDS_PARSED","SUCCESS",PendingElapsedMs(),auth.cycle_id,auth.timestamp,"AUTH_RESPONSE","PARSED","",auth.protocol_version);
   if(!g_has_pending_signal){ if(!g_link.DeleteAuthorization()) Print("ASTRA LINK | could not delete stale authorization. error=",GetLastError()); const bool late=(auth.cycle_id==g_last_expired_cycle); const bool duplicate=(auth.cycle_id==g_last_completed_cycle); const string event_name=(late ? "LATE_RESPONSE_DISCARDED" : (duplicate ? "DUPLICATE_RESPONSE_DISCARDED" : "UNSOLICITED_RESPONSE_DISCARDED")); const string reason=(late ? "CYCLE_ALREADY_TIMED_OUT" : (duplicate ? "CYCLE_ALREADY_CLOSED" : "NO_PENDING_CYCLE")); g_last_auth="REJECTED"; g_last_auth_reason=reason; RecordRejectedResponse(event_name,reason,auth.cycle_id,auth.timestamp,"REJECTED",reason,auth.protocol_version); return; }
   if(auth.cycle_id!=g_pending_signal.cycle_id){ if(!g_link.DeleteAuthorization()) Print("ASTRA LINK | could not delete mismatched authorization. error=",GetLastError()); const string reason="EXPECTED_CYCLE_ID="+(string)g_pending_signal.cycle_id+";RECEIVED_CYCLE_ID="+(string)auth.cycle_id; RecordRejectedResponse("CYCLE_ID_MISMATCH",reason,auth.cycle_id,auth.timestamp,"REJECTED",reason,auth.protocol_version); return; }
   RecordLinkEvent("RESPONSE_VALID",g_pending_signal,g_pending_snapshot,"VALIDATED",auth.status,"CYCLE_ID_MATCH","SUCCESS",PendingElapsedMs(),auth.cycle_id,auth.timestamp,"AUTH_RESPONSE","VALID","",auth.protocol_version);
   if(!g_link.DeleteAuthorization()){ const int error=GetLastError(); Print("ASTRA LINK | valid authorization could not be consumed. cycle=",auth.cycle_id," error=",error); return; }
   const ulong elapsed=PendingElapsedMs(); g_last_auth=AuthorizationStatusText(auth.status); g_last_auth_reason=auth.reason;
   RecordLinkEvent("RESPONSE_RECEIVED",g_pending_signal,g_pending_snapshot,"RESPONSE_RECEIVED",auth.status,auth.reason,"SUCCESS",elapsed,auth.cycle_id,auth.timestamp,"AUTH_RESPONSE","VALID","",auth.protocol_version);
   RecordLinkEvent("RESPONSE_VALIDATED",g_pending_signal,g_pending_snapshot,"VALIDATED",auth.status,"CYCLE_ID_MATCH","SUCCESS",elapsed,auth.cycle_id,auth.timestamp,"AUTH_RESPONSE","VALID","",auth.protocol_version);
   if(!g_storage.AppendSnapshot(g_pending_signal,g_pending_snapshot,auth.status,auth.reason)) Print("ASTRA LINK | authorization snapshot write failed. cycle=",auth.cycle_id," error=",GetLastError());
   RecordLinkEvent("AUTHORIZATION_PROCESSED",g_pending_signal,g_pending_snapshot,AuthorizationStatusText(auth.status),auth.status,auth.reason,"SUCCESS",elapsed,auth.cycle_id,auth.timestamp,"AUTH_RESPONSE","VALID","",auth.protocol_version);
   ClosePending(g_last_auth); RecordLinkEvent("PENDING_CLEARED",g_pending_signal,g_pending_snapshot,"IDLE",auth.status,"AUTHORIZATION_CYCLE_CLOSED","SUCCESS",elapsed,auth.cycle_id,auth.timestamp,"AUTH_RESPONSE","VALID","",auth.protocol_version); RecordLinkEvent("FINAL_STATE",g_pending_signal,g_pending_snapshot,"IDLE",auth.status,auth.reason,"SUCCESS",elapsed,auth.cycle_id,auth.timestamp,"AUTH_RESPONSE","VALID","",auth.protocol_version);
  }
void ProcessNewClosedBar()
  {
   MqlRates rates[]; if(!LoadRates(rates)){ g_last_reason="RATES_NOT_READY"; return; }
   AS_MarketSnapshot snapshot; ZeroMemory(snapshot); snapshot.symbol=_Symbol; snapshot.timeframe=InpTimeframe;
   if(!g_indicators.Calculate(rates,snapshot)){ g_last_reason="INDICATORS_NOT_READY"; return; }
   if(snapshot.bar_time==g_last_closed_bar) return;
   g_last_closed_bar=snapshot.bar_time; g_cycle_id++;
   AS_StrategySignal sig=g_strategy.Evaluate(snapshot,g_cycle_id,TimeCurrent()); g_last_signal=sig.signal_text; g_last_reason=sig.reason;
   if(InpPublishOnlySignals || sig.direction!=AS_SIGNAL_NONE) SubmitSignal(sig,snapshot);
   if(sig.direction!=AS_SIGNAL_NONE || !InpPublishOnlySignals) if(!g_storage.AppendSnapshot(sig,snapshot,AS_AUTH_UNKNOWN,(sig.direction==AS_SIGNAL_NONE ? "" : "WAITING_AUTHORIZATION"))) Print("ASTRA SENTINEL | snapshot telemetry write failed. cycle=",sig.cycle_id," error=",GetLastError());
   if(!g_link.PublishHeartbeat("RUNNING",g_cycle_id,g_last_closed_bar)) Print("ASTRA LINK | RUNNING heartbeat publication failed. cycle=",g_cycle_id," error=",GetLastError());
   RenderPanel(snapshot,sig);
  }
void ProcessRuntime()
  {
   if(!InpEnabled) return; PollAuthorization(); if(g_has_pending_signal) return;
   if(InpDiagnosticMode){ if(g_diagnostic_signal_created) return; g_diagnostic_signal_created=true; g_cycle_id++; AS_MarketSnapshot snapshot; ZeroMemory(snapshot); snapshot.symbol=_Symbol; snapshot.timeframe=InpTimeframe; AS_StrategySignal signal; ZeroMemory(signal); signal.protocol_version=AS_PROTOCOL_VERSION; signal.strategy_id="ASTRA_SENTINEL_RUNTIME_TEST"; signal.source=AS_DEFAULT_SOURCE; signal.target=InpLinkedTarget; signal.cycle_id=g_cycle_id; const datetime server_time=TimeCurrent(); signal.timestamp=(server_time>0 ? server_time : TimeLocal()); signal.symbol=_Symbol; signal.timeframe=InpTimeframe; signal.direction=AS_SIGNAL_BUY; signal.signal_text="BUY"; signal.reason="SYNTHETIC_RUNTIME_TEST"; g_last_signal=signal.signal_text; g_last_reason=signal.reason; SubmitSignal(signal,snapshot); return; }
   ProcessNewClosedBar();
  }

int OnInit()
  {
   if(InpTimerSeconds<1 || InpLinkTimeoutSeconds<1 || InpLinkTimeoutSeconds>86400) return(INIT_PARAMETERS_INCORRECT);
   if(InpDiagnosticMode && !AS_IsTestLinkNamespace(InpLinkNamespace)){ Print("ASTRA LINK | diagnostic mode requires a namespace beginning ASTRA_SENTINEL_TEST_."); return(INIT_PARAMETERS_INCORRECT); }
   if(!g_link.Configure(InpLinkNamespace) || !g_storage.Configure(InpLinkNamespace)){ Print("ASTRA LINK | invalid namespace configuration."); return(INIT_PARAMETERS_INCORRECT); }
   g_cycle_id=(ulong)TimeLocal()*1000000+GetTickCount64();
   g_indicators.Configure(InpMA21Period,InpRSI9Period,InpHistoricalVolPeriod,InpNormalizationPeriod);
   g_strategy.Configure(InpStrategyID,AS_DEFAULT_SOURCE,InpLinkedTarget,InpLSVolatilityThreshold,InpRSIEntryThreshold,InpRSIExitThreshold,InpEnableEntry,InpEnableExit,InpEnableTimeExit,InpExitHour,InpExitMinute);
   if(!EventSetTimer(InpTimerSeconds)){ Print("ASTRA SENTINEL | timer setup failed. error=",GetLastError()); return INIT_FAILED; }
   if(!g_link.PublishHeartbeat("INITIALIZED",g_cycle_id,0)) Print("ASTRA LINK | INITIALIZED heartbeat publication failed. error=",GetLastError());
   Print(AS_PRODUCT_NAME," v",AS_PRODUCT_VERSION," initialized. Protocol=",AS_PROTOCOL_NAME," v",AS_PROTOCOL_VERSION,", Symbol=",_Symbol,", TF=",EnumToString(InpTimeframe),", DiagnosticMode=",(InpDiagnosticMode ? "TRUE" : "FALSE"),", LinkNamespace=",g_link.LinkNamespace(),", Environment=",(InpDiagnosticMode ? "TEST" : (InpLinkNamespace=="" ? "PRODUCTION" : "ISOLATED")),", Transport=",g_link.TransportName(),", Recovery=IDLE (pending state is not persisted)");
   return(INIT_SUCCEEDED);
  }
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_has_pending_signal){ const ulong elapsed=PendingElapsedMs(); RecordLinkEvent("PENDING_INTERRUPTED_BY_RESTART",g_pending_signal,g_pending_snapshot,"INTERRUPTED",AS_AUTH_ERROR,"PENDING_NOT_PERSISTED","STOPPED",elapsed); }
   if(!g_link.PublishHeartbeat("STOPPED",g_cycle_id,g_last_closed_bar)) Print("ASTRA LINK | STOPPED heartbeat publication failed. error=",GetLastError());
   Comment(""); Print(AS_PRODUCT_NAME," stopped. reason=",reason," cycle=",g_cycle_id);
  }
void OnTimer(){ ProcessRuntime(); }
void OnTick(){ /* Timer drives the bar-close state machine; this EA intentionally does not execute orders. */ }
