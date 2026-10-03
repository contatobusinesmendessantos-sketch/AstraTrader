#ifndef __AS_LINK_PROTOCOL_MQH__
#define __AS_LINK_PROTOCOL_MQH__

#include "../Core/AS_Types.mqh"

class CASLinkProtocol
  {
private:
   bool IsUnsignedInteger(const string value) const
     {
      if(value=="")
         return false;
      for(int i=0;i<StringLen(value);i++)
        {
         const ushort ch=StringGetCharacter(value,i);
         if(ch<'0' || ch>'9')
            return false;
        }
      return true;
     }

   bool IsFiniteNumber(const string value) const
     {
      const int length=StringLen(value);
      if(length==0)
         return false;

      int i=0;
      ushort ch=StringGetCharacter(value,i);
      if(ch=='-' || ch=='+')
         i++;

      int integer_digits=0;
      while(i<length)
        {
         ch=StringGetCharacter(value,i);
         if(ch<'0' || ch>'9')
            break;
         integer_digits++;
         i++;
        }

      int fractional_digits=0;
      if(i<length && StringGetCharacter(value,i)=='.')
        {
         i++;
         while(i<length)
           {
            ch=StringGetCharacter(value,i);
            if(ch<'0' || ch>'9')
               break;
            fractional_digits++;
            i++;
           }
        }

      if(integer_digits+fractional_digits==0)
         return false;

      if(i<length && (StringGetCharacter(value,i)=='e' || StringGetCharacter(value,i)=='E'))
        {
         i++;
         if(i<length && (StringGetCharacter(value,i)=='-' || StringGetCharacter(value,i)=='+'))
            i++;
         int exponent_digits=0;
         while(i<length)
           {
            ch=StringGetCharacter(value,i);
            if(ch<'0' || ch>'9')
               break;
            exponent_digits++;
            i++;
           }
         if(exponent_digits==0)
            return false;
        }

      if(i!=length)
         return false;
      return MathIsValidNumber(StringToDouble(value));
     }

public:
   string SignalDirectionToText(const AS_SignalDirection direction) const
     {
      switch(direction)
        {
         case AS_SIGNAL_BUY:  return "BUY";
         case AS_SIGNAL_SELL: return "SELL";
         case AS_SIGNAL_EXIT: return "EXIT";
         default:             return "NONE";
        }
     }

   AS_AuthorizationStatus AuthorizationFromText(const string value) const
     {
      if(value=="APPROVED") return AS_AUTH_APPROVED;
      if(value=="BLOCKED")  return AS_AUTH_BLOCKED;
      if(value=="EXECUTED") return AS_AUTH_EXECUTED;
      if(value=="ERROR")    return AS_AUTH_ERROR;
      return AS_AUTH_UNKNOWN;
     }

   string BuildSignalLine(const AS_StrategySignal &sig) const
     {
      // Stable semicolon-delimited, versioned envelope.
      string line="";
      line+="1.0;SIGNAL;";
      line+=sig.strategy_id+";";
      line+=sig.source+";";
      line+=sig.target+";";
      line+=(string)sig.cycle_id+";";
      line+=TimeToString(sig.timestamp,TIME_DATE|TIME_SECONDS)+";";
      line+=sig.symbol+";";
      line+=(string)sig.timeframe+";";
      line+=SignalDirectionToText(sig.direction)+";";
      line+=(sig.candle_positive ? "1" : "0")+";";
      line+=DoubleToString(sig.ma21,8)+";";
      line+=DoubleToString(sig.rsi9,6)+";";
      line+=DoubleToString(sig.historical_volatility_pct,8)+";";
      line+=DoubleToString(sig.distance_pct,8)+";";
      line+=DoubleToString(sig.raw_ls_index,6)+";";
      line+=DoubleToString(sig.ls_index,6)+";";
      line+=DoubleToString(sig.ls_threshold,6)+";";
      line+=DoubleToString(sig.rsi_entry_threshold,6)+";";
      line+=DoubleToString(sig.rsi_exit_threshold,6)+";";
      line+=sig.reason;
      return line;
     }

   bool ParseSignalLineDetailed(const string line,AS_StrategySignal &out,string &reject_stage,string &reject_field,string &reject_error) const
     {
      reject_stage="ENVELOPE"; reject_field=""; reject_error="";
      string parts[];
      const int n=StringSplit(line,';',parts);
      if(n!=21){ reject_stage="FIELD_COUNT"; reject_field="envelope"; reject_error="EXPECTED_21_FIELDS_RECEIVED_"+(string)n; return false; }
      if(parts[0]!="1.0"){ reject_stage="VALIDATION"; reject_field="protocol_version"; reject_error="EXPECTED=1.0;RECEIVED="+parts[0]; return false; }
      if(parts[1]!="SIGNAL"){ reject_stage="VALIDATION"; reject_field="message_type"; reject_error="EXPECTED=SIGNAL;RECEIVED="+parts[1]; return false; }
      if(parts[2]==""){ reject_stage="VALIDATION"; reject_field="strategy_id"; reject_error="MISSING_STRATEGY_ID"; return false; }
      if(parts[3]==""){ reject_stage="VALIDATION"; reject_field="source"; reject_error="MISSING_SOURCE"; return false; }
      if(parts[4]==""){ reject_stage="VALIDATION"; reject_field="target"; reject_error="MISSING_TARGET"; return false; }
      if(!IsUnsignedInteger(parts[5]) || StringToInteger(parts[5])<=0){ reject_stage="VALIDATION"; reject_field="cycle_id"; reject_error="CYCLE_ID_NOT_POSITIVE_UNSIGNED_DECIMAL"; return false; }
      if(StringToTime(parts[6])<=0){ reject_stage="VALIDATION"; reject_field="timestamp"; reject_error="INVALID_TIMESTAMP"; return false; }
      if(parts[7]==""){ reject_stage="VALIDATION"; reject_field="symbol"; reject_error="MISSING_SYMBOL"; return false; }
      if(!IsUnsignedInteger(parts[8]) || StringToInteger(parts[8])<=0){ reject_stage="VALIDATION"; reject_field="timeframe"; reject_error="TIMEFRAME_NOT_POSITIVE_UNSIGNED_DECIMAL"; return false; }
      if(parts[9]!="BUY" && parts[9]!="EXIT" && parts[9]!="NONE"){ reject_stage="VALIDATION"; reject_field="signal"; reject_error="UNKNOWN_SIGNAL"; return false; }
      if(parts[10]!="0" && parts[10]!="1"){ reject_stage="VALIDATION"; reject_field="candle_positive"; reject_error="EXPECTED_BOOLEAN_0_OR_1"; return false; }
      if(parts[20]==""){ reject_stage="VALIDATION"; reject_field="reason"; reject_error="MISSING_SIGNAL_REASON"; return false; }
      for(int i=11;i<=19;i++) if(!IsFiniteNumber(parts[i])){ reject_stage="VALIDATION"; reject_field="numeric_field_"+(string)i; reject_error="NOT_FINITE_NUMBER"; return false; }

      ZeroMemory(out);
      out.protocol_version=parts[0]; out.strategy_id=parts[2]; out.source=parts[3]; out.target=parts[4];
      out.cycle_id=(ulong)StringToInteger(parts[5]); out.timestamp=StringToTime(parts[6]); out.symbol=parts[7];
      out.timeframe=(ENUM_TIMEFRAMES)StringToInteger(parts[8]); out.signal_text=parts[9];
      out.direction=(parts[9]=="BUY" ? AS_SIGNAL_BUY : (parts[9]=="EXIT" ? AS_SIGNAL_EXIT : AS_SIGNAL_NONE));
      out.candle_positive=(parts[10]=="1"); out.ma21=StringToDouble(parts[11]); out.rsi9=StringToDouble(parts[12]);
      out.historical_volatility_pct=StringToDouble(parts[13]); out.distance_pct=StringToDouble(parts[14]);
      out.raw_ls_index=StringToDouble(parts[15]); out.ls_index=StringToDouble(parts[16]);
      out.ls_threshold=StringToDouble(parts[17]); out.rsi_entry_threshold=StringToDouble(parts[18]);
      out.rsi_exit_threshold=StringToDouble(parts[19]); out.reason=parts[20];
      return true;
     }

   bool ParseAuthorizationLineDetailed(const string line,AS_Authorization &out,string &reject_stage,string &reject_field,string &reject_error) const
     {
      reject_stage="ENVELOPE"; reject_field=""; reject_error="";
      string parts[]; const int n=StringSplit(line,';',parts);
      if(n!=9){ reject_stage="FIELD_COUNT"; reject_field="envelope"; reject_error="EXPECTED_9_FIELDS_RECEIVED_"+(string)n; return false; }
      if(parts[0]!="1.0"){ reject_stage="VALIDATION"; reject_field="protocol_version"; reject_error="EXPECTED=1.0;RECEIVED="+parts[0]; return false; }
      if(parts[1]!="AUTH_RESPONSE"){ reject_stage="VALIDATION"; reject_field="message_type"; reject_error="EXPECTED=AUTH_RESPONSE;RECEIVED="+parts[1]; return false; }
      if(parts[2]==""){ reject_stage="VALIDATION"; reject_field="cycle_id"; reject_error="MISSING_CYCLE_ID"; return false; }
      if(!IsUnsignedInteger(parts[2])){ reject_stage="VALIDATION"; reject_field="cycle_id"; reject_error="CYCLE_ID_NOT_UNSIGNED_DECIMAL"; return false; }
      const long parsed_cycle=StringToInteger(parts[2]);
      if(parsed_cycle<=0){ reject_stage="VALIDATION"; reject_field="cycle_id"; reject_error="CYCLE_ID_NOT_POSITIVE"; return false; }
      const datetime parsed_timestamp=StringToTime(parts[3]);
      if(parsed_timestamp<=0){ reject_stage="VALIDATION"; reject_field="timestamp"; reject_error="INVALID_TIMESTAMP"; return false; }
      const AS_AuthorizationStatus parsed_status=AuthorizationFromText(parts[4]);
      if(parsed_status==AS_AUTH_UNKNOWN){ reject_stage="VALIDATION"; reject_field="status"; reject_error="UNKNOWN_AUTHORIZATION_STATUS"; return false; }
      if(parts[5]==""){ reject_stage="VALIDATION"; reject_field="reason"; reject_error="MISSING_RESPONSE_REASON"; return false; }
      const double approved_volume=StringToDouble(parts[6]); const double stop_loss=StringToDouble(parts[7]); const double take_profit=StringToDouble(parts[8]);
      if(!IsFiniteNumber(parts[6]) || !IsFiniteNumber(parts[7]) || !IsFiniteNumber(parts[8]) || !MathIsValidNumber(approved_volume) || approved_volume<0.0 || !MathIsValidNumber(stop_loss) || stop_loss<0.0 || !MathIsValidNumber(take_profit) || take_profit<0.0)
        {
         reject_stage="VALIDATION"; reject_field="approved_volume|stop_loss_points|take_profit_points"; reject_error="RISK_FIELD_NOT_FINITE_NONNEGATIVE_NUMBER";
         if(!IsFiniteNumber(parts[6]) || approved_volume<0.0) reject_field="approved_volume";
         else if(!IsFiniteNumber(parts[7]) || stop_loss<0.0) reject_field="stop_loss_points";
         else if(!IsFiniteNumber(parts[8]) || take_profit<0.0) reject_field="take_profit_points";
         return false;
        }
      ZeroMemory(out); out.protocol_version=parts[0]; out.cycle_id=(ulong)parsed_cycle; out.timestamp=parsed_timestamp; out.status=parsed_status; out.reason=parts[5]; out.approved_volume=approved_volume; out.stop_loss_points=stop_loss; out.take_profit_points=take_profit; return true;
     }

   bool ParseAuthorizationLine(const string line,AS_Authorization &out) const
     {
      string reject_stage; string reject_field; string reject_error;
      return ParseAuthorizationLineDetailed(line,out,reject_stage,reject_field,reject_error);
     }

   string BuildAuthorizationLine(const ulong cycle_id,const AS_AuthorizationStatus status,const string reason,const double approved_volume=0.0,const double stop_loss_points=0.0,const double take_profit_points=0.0,const string protocol_version="1.0",const datetime response_timestamp=0) const
     {
      string status_text="UNKNOWN";
      if(status==AS_AUTH_APPROVED) status_text="APPROVED"; else if(status==AS_AUTH_BLOCKED) status_text="BLOCKED"; else if(status==AS_AUTH_EXECUTED) status_text="EXECUTED"; else if(status==AS_AUTH_ERROR) status_text="ERROR";
      const datetime server_time=TimeCurrent(); const datetime timestamp=(response_timestamp>0 ? response_timestamp : (server_time>0 ? server_time : TimeLocal()));
      string line=protocol_version+";AUTH_RESPONSE;"; line+=(string)cycle_id+";"; line+=TimeToString(timestamp,TIME_DATE|TIME_SECONDS)+";"; line+=status_text+";"; line+=reason+";"; line+=DoubleToString(approved_volume,4)+";"; line+=DoubleToString(stop_loss_points,2)+";"; line+=DoubleToString(take_profit_points,2); return line;
     }
  };

#endif // __AS_LINK_PROTOCOL_MQH__
