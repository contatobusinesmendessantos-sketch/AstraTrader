#ifndef __AS_TYPES_MQH__
#define __AS_TYPES_MQH__

enum AS_SignalDirection
  {
   AS_SIGNAL_NONE = 0,
   AS_SIGNAL_BUY  = 1,
   AS_SIGNAL_SELL = -1,
   AS_SIGNAL_EXIT = 2
  };

enum AS_AuthorizationStatus
  {
   AS_AUTH_UNKNOWN   = 0,
   AS_AUTH_APPROVED  = 1,
   AS_AUTH_BLOCKED   = 2,
   AS_AUTH_EXECUTED  = 3,
   AS_AUTH_ERROR     = 4
  };

struct AS_MarketSnapshot
  {
   string             symbol;
   ENUM_TIMEFRAMES    timeframe;
   datetime           bar_time;
   double             open;
   double             high;
   double             low;
   double             close;
   long               volume;
   double             ma21;
   double             rsi9;
   double             historical_volatility_pct;
   double             distance_pct;
   double             raw_ls_index;
   double             ls_index;
   bool               candle_positive;
   bool               data_ready;
  };

struct AS_StrategySignal
  {
   string              protocol_version;
   string              strategy_id;
   string              source;
   string              target;
   ulong               cycle_id;
   datetime            timestamp;
   string              symbol;
   ENUM_TIMEFRAMES     timeframe;
   AS_SignalDirection  direction;
   string              signal_text;
   bool                candle_positive;
   double              ma21;
   double              rsi9;
   double              historical_volatility_pct;
   double              distance_pct;
   double              raw_ls_index;
   double              ls_index;
   double              ls_threshold;
   double              rsi_entry_threshold;
   double              rsi_exit_threshold;
   string              reason;
  };

struct AS_Authorization
  {
   string                 protocol_version;
   ulong                  cycle_id;
   datetime               timestamp;
   AS_AuthorizationStatus status;
   string                 reason;
   double                 approved_volume;
   double                 stop_loss_points;
   double                 take_profit_points;
  };

struct AS_LinkRuntimeEvent
  {
   datetime           runtime_timestamp;
   datetime           market_timestamp;
   datetime           message_timestamp;
   ulong              cycle_id;
   string             protocol_version;
   string             link_namespace;
   string             event_name;
   string             message_type;
   string             source;
   string             target;
   string             symbol;
   ENUM_TIMEFRAMES    timeframe;
   string             signal;
   double             ma21;
   double             rsi9;
   double             historical_volatility_pct;
   double             distance_pct;
   double             ls_index;
   bool               candle_positive;
   string             link_status;
   string             authorization_status;
   string             response_reason;
   string             transport_status;
   string             validation_result;
   string             reject_reason;
   ulong              elapsed_ms;
  };

#endif // __AS_TYPES_MQH__
