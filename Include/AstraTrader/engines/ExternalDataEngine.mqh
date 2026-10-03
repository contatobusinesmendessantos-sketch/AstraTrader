//+------------------------------------------------------------------+
//| ExternalDataEngine.mqh                                          |
//| Astra Trader AI                                                 |
//|                                                                  |
//| ENGINE DE DADOS EXTERNOS / OTC                                  |
//|                                                                  |
//| Responsabilidades:                                              |
//|  - carregar candles OTC externos                                |
//|  - selecionar arquivo pelo timeframe                             |
//|  - converter candles para AnalysisContext                        |
//|  - preservar ordem temporal central                              |
//|  - NÃO fabricar histórico por padrão                              |
//|  - NÃO produzir sinais                                            |
//+------------------------------------------------------------------+
#ifndef ASTRA_EXTERNALDATAENGINE_MQH
#define ASTRA_EXTERNALDATAENGINE_MQH

#include <AstraTrader\Analysis\AnalysisContext.mqh>


class ExternalDataEngine
{
private:

   bool m_allowSyntheticFallback;
   bool m_allowLegacyFileFallback;

   bool IsValidOHLC(
      const MqlRates &bar
   ) const
   {
      if(bar.time <= 0)
         return false;

      if(
         !MathIsValidNumber(bar.open) ||
         !MathIsValidNumber(bar.high) ||
         !MathIsValidNumber(bar.low) ||
         !MathIsValidNumber(bar.close) ||
         bar.open == EMPTY_VALUE ||
         bar.high == EMPTY_VALUE ||
         bar.low == EMPTY_VALUE ||
         bar.close == EMPTY_VALUE
      )
      {
         return false;
      }

      if(
         bar.open <= 0.0 ||
         bar.high <= 0.0 ||
         bar.low <= 0.0 ||
         bar.close <= 0.0 ||
         bar.high < bar.low ||
         bar.high < bar.open ||
         bar.high < bar.close ||
         bar.low > bar.open ||
         bar.low > bar.close
      )
      {
         return false;
      }

      return true;
   }


   //=================================================================
   // DOUBLE
   //=================================================================

   double ExtractDouble(
      const string &src,
      const string key
   )
   {
      const string search =
         "\"" +
         key +
         "\":";

      const int pos =
         StringFind(
            src,
            search
         );

      if(pos < 0)
         return 0.0;

      int start =
         pos +
         StringLen(search);

      const int len =
         StringLen(src);

      while(
         start < len &&
         StringGetCharacter(
            src,
            start
         ) == ' '
      )
      {
         start++;
      }

      int end =
         start;

      while(end < len)
      {
         const ushort ch =
            StringGetCharacter(
               src,
               end
            );

         if(
            ch == ',' ||
            ch == '}' ||
            ch == ' ' ||
            ch == '\n' ||
            ch == '\r'
         )
         {
            break;
         }

         end++;
      }

      if(end <= start)
         return 0.0;

      return StringToDouble(
         StringSubstr(
            src,
            start,
            end - start
         )
      );
   }


   //=================================================================
   // LONG
   //=================================================================

   long ExtractLong(
      const string &src,
      const string key
   )
   {
      return (
         long
      )ExtractDouble(
         src,
         key
      );
   }


   //=================================================================
   // PARSE CANDLES
   //
   // Entrada:
   //   cronológica:
   //   oldest -> newest
   //
   // Saída:
   //   mesma ordem
   //   posteriormente invertida em PopulateContext().
   //=================================================================

   int ParseCandles(
      const string &json,
      MqlRates &out[]
   )
   {
      ArrayResize(
         out,
         0
      );

      const string marker =
         "\"candles\":[";

      const int p =
         StringFind(
            json,
            marker
         );

      if(p < 0)
         return 0;

      const int s =
         p +
         StringLen(marker);

      const int e =
         StringFind(
            json,
            "]",
            s
         );

      if(e < 0)
         return 0;

      const string body =
         StringSubstr(
            json,
            s,
            e - s
         );

      if(StringLen(body) < 5)
         return 0;

      string chunks[];

      const int n =
         StringSplit(
            body,
            '}',
            chunks
         );

      if(n <= 0)
         return 0;

      MqlRates tmp[];

      ArrayResize(
         tmp,
         n
      );

      int filled =
         0;

      for(int i = 0; i < n; i++)
      {
         if(
            StringFind(
               chunks[i],
               "{"
            ) < 0
         )
         {
            continue;
         }

         MqlRates bar;

         ZeroMemory(
            bar
         );

         bar.time =
            (datetime)
            ExtractLong(
               chunks[i],
               "time"
            );

         bar.open =
            ExtractDouble(
               chunks[i],
               "open"
            );

         bar.high =
            ExtractDouble(
               chunks[i],
               "high"
            );

         bar.low =
            ExtractDouble(
               chunks[i],
               "low"
            );

         bar.close =
            ExtractDouble(
               chunks[i],
               "close"
            );

         bar.tick_volume =
            (long)
            ExtractLong(
               chunks[i],
               "volume"
            );


         //==========================================================
         // VALIDAÇÃO
         //==========================================================

         if(!IsValidOHLC(bar))
            continue;


         tmp[filled] =
            bar;

         filled++;
      }


      if(filled <= 0)
         return 0;

      ArrayResize(
         tmp,
         filled
      );

      ArrayCopy(
         out,
         tmp,
         0,
         0,
         filled
      );

      return filled;
   }


   //=================================================================
   // LOAD FILE
   //=================================================================

   bool LoadFile(
      const string filename,
      string &json
   )
   {
      json =
         "";

      ResetLastError();

      const int handle =
         FileOpen(
            filename,
            FILE_READ |
            FILE_TXT  |
            FILE_ANSI |
            FILE_COMMON
         );

      if(handle == INVALID_HANDLE)
         return false;

      while(!FileIsEnding(handle))
      {
         json +=
            FileReadString(
               handle
            );
      }

      FileClose(
         handle
      );

      if(StringLen(json) < 10)
         return false;

      return true;
   }


   //=================================================================
   // TIMEFRAME
   //=================================================================

   string GetTimeframeName(
      const ENUM_TIMEFRAMES tf
   )
   {
      string tfName =
         EnumToString(
            tf
         );

      StringReplace(
         tfName,
         "PERIOD_",
         ""
      );

      return tfName;
   }


   //=================================================================
   // POPULATE CONTEXT
   //
   // Contrato:
   //
   // marketBars[0] = newest/current
   // marketBars[1] = previous
   // marketBars[2] = older
   //
   // Os candles recebidos do arquivo continuam cronológicos.
   // Aqui fazemos a inversão.
   //=================================================================

   bool PopulateContext(
      AnalysisContext &context,
      MqlRates &bars[],
      const int count
   )
   {
      if(count <= 0)
         return false;

      const int n =
         MathMin(
            count,
            300
         );

      if(n < 3)
         return false;


      if(
         ArrayResize(
            context.marketBars,
            n
         ) != n
      )
      {
         return false;
      }


      //==============================================================
      // MAIS RECENTE EM [0]
      //==============================================================

      for(int i = 0; i < n; i++)
      {
         context.marketBars[i] =
            bars[count - 1 - i];
      }


      context.marketBarsCount =
         n;

      context.marketHistoryReady =
         true;


      //==============================================================
      // BARRAS DE COMPATIBILIDADE
      //==============================================================

      context.currentBar =
         context.marketBars[0];

      context.previousBar =
         context.marketBars[1];

      context.olderBar =
         context.marketBars[2];


      //==============================================================
      // MARKET DATA
      //==============================================================

      context.price =
         context.currentBar.close;

      context.open =
         context.currentBar.open;

      context.high =
         context.currentBar.high;

      context.low =
         context.currentBar.low;

      context.close =
         context.currentBar.close;


      context.bid =
         context.currentBar.close;

      context.ask =
         context.currentBar.close;


      // Não inventamos spread.
      context.spreadPoints =
         0.0;


      context.marketDataReady =
         true;

      context.marketDataBarCount =
         n;

      context.barsAvailable =
         n;

      context.dataQuality =
         ASTRA_DATA_GOOD;
      context.marketDataSource =
         "EXTERNAL_OTC";


      //==============================================================
      // SYMBOL METADATA
      //==============================================================

      if(context.point <= 0.0)
      {
         const double symPoint =
            SymbolInfoDouble(
               context.symbol,
               SYMBOL_POINT
            );

         if(symPoint > 0.0)
         {
            context.point =
               symPoint;

            context.digits =
               (int)
               SymbolInfoInteger(
                  context.symbol,
                  SYMBOL_DIGITS
               );
         }
         else
         {
            // Fallback apenas para análise,
            // nunca deve ser tratado como spread/microestrutura real.
            context.point =
               0.00001;

            context.digits =
               5;
         }
      }


      context.tickSize =
         SymbolInfoDouble(
            context.symbol,
            SYMBOL_TRADE_TICK_SIZE
         );

      context.tickValue =
         SymbolInfoDouble(
            context.symbol,
            SYMBOL_TRADE_TICK_VALUE
         );


      return true;
   }


public:

   //=================================================================
   // CONSTRUTOR
   //=================================================================

   ExternalDataEngine()
   {
      m_allowSyntheticFallback =
         false;

      m_allowLegacyFileFallback =
         false;
   }


   //=================================================================
   // CONFIGURAÇÃO
   //=================================================================

   void SetAllowSyntheticFallback(
      const bool value
   )
   {
      m_allowSyntheticFallback =
         value;
   }


   void SetAllowLegacyFileFallback(
      const bool value
   )
   {
      m_allowLegacyFileFallback =
         value;
   }


   bool IsSyntheticFallbackAllowed() const
   {
      return m_allowSyntheticFallback;
   }


   bool IsLegacyFileFallbackAllowed() const
   {
      return m_allowLegacyFileFallback;
   }


   //=================================================================
   // PROCESS
   //=================================================================

   bool Process(
      AnalysisContext &context
   )
   {
      //==============================================================
      // OTC / EXTERNAL ONLY
      //==============================================================

      if(
         StringFind(
            context.symbol,
            "OTC"
         ) < 0
      )
      {
         return false;
      }

      context.syntheticMarketBarsCount =
         0;


      //==============================================================
      // TIMEFRAME
      //==============================================================

      const string tfName =
         GetTimeframeName(
            context.primaryTF
         );

      if(tfName == "")
      {
         context.validationMessage =
            "ExternalDataEngine: timeframe invalido.";

         return false;
      }


      //==============================================================
      // ARQUIVO PRIMÁRIO
      //==============================================================

      const string primaryFilename =
         "quotex_" +
         context.symbol +
         "_" +
         tfName +
         ".json";


      string json =
         "";

      string usedFilename =
         primaryFilename;


      bool loaded =
         LoadFile(
            primaryFilename,
            json
         );


      //==============================================================
      // FALLBACK LEGADO
      //==============================================================

      if(
         !loaded &&
         m_allowLegacyFileFallback
      )
      {
         const string legacyFilename =
            "quotex_" +
            context.symbol +
            ".json";

         if(
            LoadFile(
               legacyFilename,
               json
            )
         )
         {
            loaded =
               true;

            usedFilename =
               legacyFilename;

            PrintFormat(
               "[ExternalDataEngine][WARNING] "
               "Arquivo legado utilizado | "
               "Symbol=%s | TF=%s | File=%s",
               context.symbol,
               tfName,
               legacyFilename
            );
         }
      }


      if(!loaded)
      {
         context.validationMessage =
            StringFormat(
               "ExternalDataEngine: arquivo nao encontrado | "
               "File=%s",
               primaryFilename
            );

         return false;
      }


      if(StringLen(json) < 10)
      {
         context.validationMessage =
            StringFormat(
               "ExternalDataEngine: JSON vazio | "
               "File=%s",
               usedFilename
            );

         return false;
      }


      //==============================================================
      // PARSE
      //==============================================================

      MqlRates bars[];

      int count =
         ParseCandles(
            json,
            bars
         );


      //==============================================================
      // HISTÓRICO INSUFICIENTE
      //==============================================================

      if(count < 50)
      {
         if(!m_allowSyntheticFallback)
         {
            context.marketHistoryReady =
               false;

            context.marketDataReady =
               false;

            context.dataQuality =
               ASTRA_DATA_INVALID;

            context.validationMessage =
               StringFormat(
                  "ExternalDataEngine: historico insuficiente | "
                  "real=%d | minimo=50 | TF=%s | File=%s",
                  count,
                  tfName,
                  usedFilename
               );

            PrintFormat(
               "[ExternalDataEngine][BLOCKED] "
               "Historico insuficiente | "
               "Symbol=%s | TF=%s | Candles=%d | "
               "Minimo=50 | "
               "FallbackSintetico=false",
               context.symbol,
               tfName,
               count
            );

            return false;
         }


         //==========================================================
         // FALLBACK SINTÉTICO
         //
         // Somente quando explicitamente habilitado.
         //==========================================================

         MqlRates extended[];

         const int syntheticCount =
            100;

         if(
            ArrayResize(
               extended,
               syntheticCount
            ) != syntheticCount
         )
         {
            return false;
         }


         double basePrice =
            1.0850;

         datetime baseTime =
            TimeCurrent();


         if(count > 0)
         {
            basePrice =
               bars[count - 1].close;

            baseTime =
               bars[count - 1].time;
         }


         const int periodSeconds =
            PeriodSeconds(
               context.primaryTF
            );


         if(periodSeconds <= 0)
         {
            context.validationMessage =
               "ExternalDataEngine: "
               "PeriodSeconds invalido.";

            return false;
         }


         MathSrand(
            (int)TimeLocal()
         );


         for(int i = 0; i < syntheticCount; i++)
         {
            ZeroMemory(
               extended[i]
            );

            extended[i].time =
               baseTime -
               (
                  syntheticCount -
                  1 -
                  i
               ) *
               periodSeconds;

            const double r1 =
               MathRand() /
               32767.0;

            const double r2 =
               MathRand() /
               32767.0;

            const double r3 =
               MathRand() /
               32767.0;

            const double r4 =
               MathRand() /
               32767.0;

            extended[i].open =
               basePrice +
               (
                  r1 - 0.5
               ) *
               0.001;

            extended[i].high =
               extended[i].open +
               r2 *
               0.0005;

            extended[i].low =
               extended[i].open -
               r3 *
               0.0005;

            extended[i].close =
               extended[i].open +
               (
                  r4 - 0.5
               ) *
               0.0008;

            extended[i].tick_volume =
               100 +
               (
                  MathRand() %
                  400
               );
         }


         // Sobrepor o final com dados reais disponíveis.
         if(count > 0)
         {
            const int copyCount =
               MathMin(
                  count,
                  syntheticCount
               );

            for(int i = 0; i < copyCount; i++)
            {
               extended[
                  syntheticCount -
                  copyCount +
                  i
               ] =
                  bars[
                     count -
                     copyCount +
                     i
                  ];
            }

            context.syntheticMarketBarsCount =
               syntheticCount - copyCount;
         }
         else
         {
            context.syntheticMarketBarsCount =
               syntheticCount;
         }

         const int copiedSynthetic =
            ArrayCopy(
               bars,
               extended
            );

         count =
            ArraySize(bars);

         if(
            copiedSynthetic != syntheticCount ||
            count != syntheticCount
         )
         {
            context.validationMessage =
               "ExternalDataEngine: falha ao aplicar "
               "fallback sintetico.";

            return false;
         }

         PrintFormat(
            "[ExternalDataEngine][WARNING] "
            "Fallback sintetico habilitado | "
            "Symbol=%s | TF=%s | Candles=%d | "
            "SyntheticCandles=%d | SyntheticRange=oldest_tail | "
            "File=%s | "
            "NAO USAR PARA BACKTEST DE PERFORMANCE",
            context.symbol,
            tfName,
            count,
            context.syntheticMarketBarsCount,
            usedFilename
         );
      }


      //==============================================================
      // VALIDAÇÃO FINAL
      //==============================================================

      if(count <= 0)
      {
         context.marketHistoryReady =
            false;

         context.marketDataReady =
            false;

         context.dataQuality =
            ASTRA_DATA_INVALID;

         context.validationMessage =
            "ExternalDataEngine: nenhum candle valido.";

         return false;
      }


      //==============================================================
      // POPULATE
      //==============================================================

      if(!PopulateContext(
            context,
            bars,
            count
         ))
      {
         context.marketHistoryReady =
            false;

         context.marketDataReady =
            false;

         context.dataQuality =
            ASTRA_DATA_INVALID;

         context.validationMessage =
            "ExternalDataEngine: falha ao preencher "
            "AnalysisContext.";

         return false;
      }

      if(!context.ValidateRateArray(context.marketBars))
      {
         context.marketHistoryReady =
            false;

         context.marketDataReady =
            false;

         context.dataQuality =
            ASTRA_DATA_INVALID;

         context.validationMessage =
            "ExternalDataEngine: historico contem "
            "valores numericos invalidos.";

         return false;
      }

      context.marketDataSource =
         "EXTERNAL_OTC";


      //==============================================================
      // LOG
      //==============================================================

      PrintFormat(
         "[ExternalDataEngine] OTC carregado | "
         "Symbol=%s | TF=%s | Candles=%d | "
         "SyntheticCandles=%d | SyntheticRange=oldest_tail | "
         "Source=%s | "
         "Current=%.5f | Previous=%.5f | File=%s",
         context.symbol,
         tfName,
         context.marketBarsCount,
         context.syntheticMarketBarsCount,
         context.marketDataSource,
         context.marketBars[0].close,
         context.marketBars[1].close,
         usedFilename
      );

      return true;
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_EXTERNALDATAENGINE_MQH
