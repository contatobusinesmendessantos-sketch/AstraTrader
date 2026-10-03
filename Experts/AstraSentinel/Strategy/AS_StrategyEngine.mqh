#ifndef __AS_STRATEGY_ENGINE_MQH__
#define __AS_STRATEGY_ENGINE_MQH__

#include "../Core/AS_Types.mqh"

class CASStrategyEngine
  {
private:
   string m_strategy_id; string m_source; string m_target; double m_ls_threshold; double m_rsi_entry; double m_rsi_exit; bool m_enable_entry; bool m_enable_exit; bool m_enable_time_exit; int m_exit_hour; int m_exit_minute;
public:
   void Configure(const string strategy_id,const string source,const string target,const double ls_threshold,const double rsi_entry,const double rsi_exit,const bool enable_entry,const bool enable_exit,const bool enable_time_exit,const int exit_hour,const int exit_minute)
     { m_strategy_id=strategy_id; m_source=source; m_target=target; m_ls_threshold=ls_threshold; m_rsi_entry=rsi_entry; m_rsi_exit=rsi_exit; m_enable_entry=enable_entry; m_enable_exit=enable_exit; m_enable_time_exit=enable_time_exit; m_exit_hour=MathMax(0,MathMin(23,exit_hour)); m_exit_minute=MathMax(0,MathMin(59,exit_minute)); }

   AS_StrategySignal Evaluate(const AS_MarketSnapshot &s,const ulong cycle_id,const datetime now) const
     {
      AS_StrategySignal sig; ZeroMemory(sig); sig.protocol_version="1.0"; sig.strategy_id=m_strategy_id; sig.source=m_source; sig.target=m_target; sig.cycle_id=cycle_id; sig.timestamp=now; sig.symbol=s.symbol; sig.timeframe=s.timeframe; sig.direction=AS_SIGNAL_NONE; sig.signal_text="NONE"; sig.candle_positive=s.candle_positive; sig.ma21=s.ma21; sig.rsi9=s.rsi9; sig.historical_volatility_pct=s.historical_volatility_pct; sig.distance_pct=s.distance_pct; sig.raw_ls_index=s.raw_ls_index; sig.ls_index=s.ls_index; sig.ls_threshold=m_ls_threshold; sig.rsi_entry_threshold=m_rsi_entry; sig.rsi_exit_threshold=m_rsi_exit; sig.reason="NO_SIGNAL";
      if(!s.data_ready){ sig.reason="DATA_NOT_READY"; return sig; }
      if(m_enable_exit && s.rsi9>=m_rsi_exit){ sig.direction=AS_SIGNAL_EXIT; sig.signal_text="EXIT"; sig.reason="RSI9_EXIT_THRESHOLD"; return sig; }
      MqlDateTime dt; TimeToStruct(s.bar_time,dt);
      if(m_enable_time_exit && (dt.hour>m_exit_hour || (dt.hour==m_exit_hour && dt.min>=m_exit_minute))){ sig.direction=AS_SIGNAL_EXIT; sig.signal_text="EXIT"; sig.reason="TIME_EXIT"; return sig; }
      if(m_enable_entry && s.candle_positive && s.ls_index>m_ls_threshold && s.rsi9<m_rsi_entry){ sig.direction=AS_SIGNAL_BUY; sig.signal_text="BUY"; sig.reason="CANDLE_POSITIVE_AND_LS_ABOVE_THRESHOLD_AND_RSI_BELOW_ENTRY"; return sig; }
      sig.reason="ENTRY_CONDITIONS_NOT_MET"; return sig;
     }
  };

#endif // __AS_STRATEGY_ENGINE_MQH__
