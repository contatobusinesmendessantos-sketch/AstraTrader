#ifndef __AS_INDICATOR_ENGINE_MQH__
#define __AS_INDICATOR_ENGINE_MQH__

#include "../Core/AS_Types.mqh"

class CASIndicatorEngine
  {
private:
   int m_ma_period; int m_rsi_period; int m_hv_period; int m_normalization_period;
   double SMA(const MqlRates &rates[],const int start_index,const int period) const
     { double sum=0.0; for(int i=start_index;i<start_index+period;i++){ const double c=rates[i].close; if(!MathIsValidNumber(c) || c<=0.0) return EMPTY_VALUE; sum+=c; } return(sum/(double)period); }
   double HistoricalVolatilityPct(const MqlRates &rates[],const int bar_index,const int period) const
     { if(period<2) return EMPTY_VALUE; double sum=0.0,sum2=0.0; int count=0; for(int j=0;j<period;j++){ const int i1=bar_index+j,i2=bar_index+j+1; if(rates[i2].close<=0.0 || rates[i1].close<=0.0) return EMPTY_VALUE; const double ret=MathLog(rates[i1].close/rates[i2].close)*100.0; sum+=ret; sum2+=ret*ret; count++; } if(count<2) return EMPTY_VALUE; const double mean=sum/(double)count; double variance=(sum2/(double)count)-(mean*mean); if(variance<0.0 && variance>-1e-12) variance=0.0; if(variance<0.0) return EMPTY_VALUE; return MathSqrt(variance); }
   double RawLSValue(const MqlRates &rates[],const int bar_index) const
     { const double ma=SMA(rates,bar_index,m_ma_period); if(ma==EMPTY_VALUE || ma<=0.0) return EMPTY_VALUE; const double hv=HistoricalVolatilityPct(rates,bar_index,m_hv_period); if(hv==EMPTY_VALUE || hv<=0.0) return EMPTY_VALUE; const double distance=MathAbs(rates[bar_index].close-ma)/ma*100.0; return(distance/hv)*100.0; }
   double NormalizeMinMax(const MqlRates &rates[],const int bar_index,const double current_raw) const
     { if(current_raw==EMPTY_VALUE) return EMPTY_VALUE; double min_v=DBL_MAX,max_v=-DBL_MAX; int valid=0; for(int j=0;j<m_normalization_period;j++){ const double v=RawLSValue(rates,bar_index+j); if(v==EMPTY_VALUE || !MathIsValidNumber(v)) continue; min_v=MathMin(min_v,v); max_v=MathMax(max_v,v); valid++; } if(valid<2 || max_v<=min_v) return 0.0; double normalized=(current_raw-min_v)/(max_v-min_v)*100.0; normalized=MathMax(0.0,MathMin(100.0,normalized)); return normalized; }
   double RSIWilder(const MqlRates &rates[],const int closed_index,const int period) const
     { const int lookback=MathMax(100,period*10); const int oldest=closed_index+lookback; double avg_gain=0.0,avg_loss=0.0; int seeded=0; for(int k=oldest;k>closed_index;k--){ const double delta=rates[k-1].close-rates[k].close; if(delta>0.0) avg_gain+=delta; else if(delta<0.0) avg_loss-=delta; seeded++; if(seeded==period) break; } if(seeded<period) return EMPTY_VALUE; avg_gain/=period; avg_loss/=period; for(int k=oldest-seeded;k>closed_index;k--){ const double delta=rates[k-1].close-rates[k].close; const double gain=(delta>0.0 ? delta : 0.0); const double loss=(delta<0.0 ? -delta : 0.0); avg_gain=((avg_gain*(period-1))+gain)/(double)period; avg_loss=((avg_loss*(period-1))+loss)/(double)period; } if(avg_loss<=0.0) return 100.0; const double rs=avg_gain/avg_loss; return 100.0-(100.0/(1.0+rs)); }
public:
   void Configure(const int ma_period,const int rsi_period,const int hv_period,const int normalization_period){ m_ma_period=MathMax(2,ma_period); m_rsi_period=MathMax(2,rsi_period); m_hv_period=MathMax(2,hv_period); m_normalization_period=MathMax(2,normalization_period); }
   bool Calculate(const MqlRates &rates[],AS_MarketSnapshot &out_snapshot) const
     { const int needed=MathMax(m_normalization_period+m_ma_period+m_hv_period+10,m_rsi_period*10+20); if(ArraySize(rates)<needed) return false; const int closed=1; out_snapshot.bar_time=rates[closed].time; out_snapshot.open=rates[closed].open; out_snapshot.high=rates[closed].high; out_snapshot.low=rates[closed].low; out_snapshot.close=rates[closed].close; out_snapshot.volume=rates[closed].tick_volume; out_snapshot.ma21=SMA(rates,closed,m_ma_period); out_snapshot.rsi9=RSIWilder(rates,closed,m_rsi_period); out_snapshot.historical_volatility_pct=HistoricalVolatilityPct(rates,closed,m_hv_period); if(out_snapshot.ma21==EMPTY_VALUE || out_snapshot.ma21<=0.0 || out_snapshot.rsi9==EMPTY_VALUE || out_snapshot.historical_volatility_pct==EMPTY_VALUE) return false; out_snapshot.distance_pct=MathAbs(out_snapshot.close-out_snapshot.ma21)/out_snapshot.ma21*100.0; out_snapshot.raw_ls_index=RawLSValue(rates,closed); out_snapshot.ls_index=NormalizeMinMax(rates,closed,out_snapshot.raw_ls_index); out_snapshot.candle_positive=(out_snapshot.close>out_snapshot.open); out_snapshot.data_ready=(out_snapshot.ls_index!=EMPTY_VALUE); return out_snapshot.data_ready; }
  };

#endif // __AS_INDICATOR_ENGINE_MQH__
