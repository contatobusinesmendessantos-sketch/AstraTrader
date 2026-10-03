//+------------------------------------------------------------------+
//| TimeframeAnalyzer.mqh                                            |
//| Astra Trader AI                                                  |
//|                                                                  |
//| Estágio 2 - Análise Multi-Timeframe                              |
//|                                                                  |
//| Responsabilidades:                                               |
//|  - Avaliar direção de múltiplos timeframes                       |
//|  - Calcular score individual de cada timeframe                   |
//|  - Medir alinhamento entre timeframes                             |
//|  - Produzir timeframeScore                                       |
//|  - Produzir timeframeAligned                                     |
//|                                                                  |
//| NÃO é responsável por:                                           |
//|  - Decidir BUY/SELL                                               |
//|  - Calcular lote                                                  |
//|  - Calcular SL/TP                                                 |
//|  - Executar ordens                                                |
//+------------------------------------------------------------------+
#ifndef ASTRA_TIMEFRAMEANALYZER_MQH
#define ASTRA_TIMEFRAMEANALYZER_MQH

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>
#include <AstraTrader\Core\Config.mqh>

//+------------------------------------------------------------------+
//| Classe TimeframeAnalyzer                                         |
//+------------------------------------------------------------------+
class TimeframeAnalyzer
  {
private:

   //=================================================================
   // CONFIGURAÇÃO
   //=================================================================
   int    m_lookbackBars;
   double m_minDirectionalScore;
   double m_alignmentThreshold;

   //=================================================================
   // CLAMP
   //=================================================================
   double Clamp(const double value,
                const double minValue,
                const double maxValue)
     {
      return MathMax(minValue,MathMin(maxValue,value));
     }

   //=================================================================
   // SCORE DE UMA SÉRIE
   //
   // Compara:
   // - preço atual
   // - média
   // - momentum
   //
   // Resultado:
   // +100 = forte alta
   // -100 = forte baixa
   // 0    = neutro
   //=================================================================
   double CalculateTimeframeScore(
      const string symbol,
      const ENUM_TIMEFRAMES timeframe)
     {
      if(symbol=="")
         return 0.0;

      int barsRequired=m_lookbackBars+2;

      if(barsRequired<10)
         barsRequired=10;

      MqlRates rates[];

      ArraySetAsSeries(rates,true);

      int copied=
         CopyRates(
            symbol,
            timeframe,
            1,
            barsRequired,
            rates
         );

      if(copied<10)
         return 0.0;

      //==============================================================
      // PREÇO MAIS RECENTE FECHADO
      //==============================================================
      double currentClose=
         rates[0].close;

      if(currentClose<=0.0)
         return 0.0;

      //==============================================================
      // MÉDIA DOS FECHAMENTOS
      //==============================================================
      double sum=0.0;
      int count=MathMin(m_lookbackBars,copied);

      for(int i=0;i<count;i++)
         sum+=rates[i].close;

      if(count<=0)
         return 0.0;

      double average=sum/(double)count;

      if(average<=0.0)
         return 0.0;

      //==============================================================
      // COMPONENTE DE TENDÊNCIA
      //==============================================================
      double trendScore=
         ((currentClose-average)/average)*10000.0;

      trendScore=
         Clamp(trendScore,-100.0,100.0);

      //==============================================================
      // COMPONENTE DE MOMENTUM
      //
      // Compara fechamento recente com fechamento anterior.
      //==============================================================
      double momentumScore=0.0;

      if(copied>=2 && rates[1].close>0.0)
        {
         momentumScore=
            ((rates[0].close-rates[1].close)/
             rates[1].close)*10000.0;

         momentumScore=
            Clamp(momentumScore,-100.0,100.0);
        }

      //==============================================================
      // COMPONENTE DE ESTRUTURA DE CANDLE
      //==============================================================
      double candleScore=0.0;

      if(rates[0].high>rates[0].low)
        {
         double range=
            rates[0].high-rates[0].low;

         double body=
            rates[0].close-rates[0].open;

         candleScore=
            (body/range)*100.0;

         candleScore=
            Clamp(candleScore,-100.0,100.0);
        }

      //==============================================================
      // SCORE FINAL
      //==============================================================
      double score=
           trendScore  *0.50
         + momentumScore*0.30
         + candleScore *0.20;

      return Clamp(score,-100.0,100.0);
     }

   //=================================================================
   // SCORE DIRECIONAL
   //=================================================================
   int DirectionFromScore(const double score)
     {
      if(score>=m_minDirectionalScore)
         return 1;

      if(score<=-m_minDirectionalScore)
         return -1;

      return 0;
     }

   //=================================================================
   // CALCULA ALINHAMENTO
   //=================================================================
   double CalculateAlignmentScore(
      const int bullish,
      const int bearish,
      const int neutral)
     {
      int total=
         bullish+
         bearish+
         neutral;

      if(total<=0)
         return 0.0;

      double directional=
         ((double)(bullish-bearish)/
          (double)total)*100.0;

      return Clamp(
         directional,
         -100.0,
         100.0
      );
     }

   //=================================================================
   // VERIFICA SE EXISTE ALINHAMENTO
   //=================================================================
   bool IsAligned(
      const int bullish,
      const int bearish,
      const int neutral,
      const double score)
     {
      int total=
         bullish+
         bearish+
         neutral;

      if(total<=0)
         return false;

      //==============================================================
      // Precisa haver predominância direcional.
      //==============================================================
      int directional=
         MathMax(bullish,bearish);

      double ratio=
         (double)directional/
         (double)total;

      if(ratio<m_alignmentThreshold)
         return false;

      //==============================================================
      // Score global também precisa ter direção.
      //==============================================================
      if(MathAbs(score)<m_minDirectionalScore)
         return false;

      return true;
     }

   //=================================================================
   // ATUALIZA SCORE E CONTADORES
   //=================================================================
   void UpdateAlignment(
      AnalysisContext &ctx)
     {
      ctx.alignedBullishTFs=0;
      ctx.alignedBearishTFs=0;
      ctx.neutralTFCount=0;

      //==============================================================
      // M1
      //==============================================================
      int direction=
         DirectionFromScore(ctx.m1Score);

      if(direction>0)
         ctx.alignedBullishTFs++;
      else
      if(direction<0)
         ctx.alignedBearishTFs++;
      else
         ctx.neutralTFCount++;

      //==============================================================
      // M5
      //==============================================================
      direction=
         DirectionFromScore(ctx.m5Score);

      if(direction>0)
         ctx.alignedBullishTFs++;
      else
      if(direction<0)
         ctx.alignedBearishTFs++;
      else
         ctx.neutralTFCount++;

      //==============================================================
      // M15
      //==============================================================
      direction=
         DirectionFromScore(ctx.m15Score);

      if(direction>0)
         ctx.alignedBullishTFs++;
      else
      if(direction<0)
         ctx.alignedBearishTFs++;
      else
         ctx.neutralTFCount++;

      //==============================================================
      // M30
      //==============================================================
      direction=
         DirectionFromScore(ctx.m30Score);

      if(direction>0)
         ctx.alignedBullishTFs++;
      else
      if(direction<0)
         ctx.alignedBearishTFs++;
      else
         ctx.neutralTFCount++;

      //==============================================================
      // H1
      //==============================================================
      direction=
         DirectionFromScore(ctx.h1Score);

      if(direction>0)
         ctx.alignedBullishTFs++;
      else
      if(direction<0)
         ctx.alignedBearishTFs++;
      else
         ctx.neutralTFCount++;

      //==============================================================
      // H4
      //==============================================================
      direction=
         DirectionFromScore(ctx.h4Score);

      if(direction>0)
         ctx.alignedBullishTFs++;
      else
      if(direction<0)
         ctx.alignedBearishTFs++;
      else
         ctx.neutralTFCount++;

      //==============================================================
      // D1
      //==============================================================
      direction=
         DirectionFromScore(ctx.d1Score);

      if(direction>0)
         ctx.alignedBullishTFs++;
      else
      if(direction<0)
         ctx.alignedBearishTFs++;
      else
         ctx.neutralTFCount++;

      //==============================================================
      // W1
      //==============================================================
      direction=
         DirectionFromScore(ctx.w1Score);

      if(direction>0)
         ctx.alignedBullishTFs++;
      else
      if(direction<0)
         ctx.alignedBearishTFs++;
      else
         ctx.neutralTFCount++;

      //==============================================================
      // MN1
      //==============================================================
      direction=
         DirectionFromScore(ctx.mn1Score);

      if(direction>0)
         ctx.alignedBullishTFs++;
      else
      if(direction<0)
         ctx.alignedBearishTFs++;
      else
         ctx.neutralTFCount++;
     }

   //=================================================================
   // MÉDIA PONDERADA DOS TIMEFRAMES
   //
   // Timeframes maiores recebem maior peso.
   //=================================================================
   double CalculateWeightedScore(
      const AnalysisContext &ctx)
     {
      double weighted=
           ctx.m1Score  *0.03
         + ctx.m5Score  *0.05
         + ctx.m15Score *0.08
         + ctx.m30Score *0.09
         + ctx.h1Score  *0.15
         + ctx.h4Score  *0.20
         + ctx.d1Score  *0.20
         + ctx.w1Score  *0.12
         + ctx.mn1Score *0.08;

      return Clamp(
         weighted,
         -100.0,
         100.0
      );
     }

public:

   //=================================================================
   // CONSTRUTOR
   //=================================================================
   TimeframeAnalyzer(
      const int lookbackBars=20,
      const double minDirectionalScore=15.0,
      const double alignmentThreshold=0.60)
     {
      m_lookbackBars=
         MathMax(10,lookbackBars);

      m_minDirectionalScore=
         Clamp(
            minDirectionalScore,
            1.0,
            100.0
         );

      m_alignmentThreshold=
         Clamp(
            alignmentThreshold,
            0.50,
            1.0
         );
     }

   //=================================================================
   // ANALYZE
   //=================================================================
   bool Analyze(AnalysisContext &ctx)
     {
      //==============================================================
      // RESET DA CAMADA
      //==============================================================
      ctx.timeframeAligned=false;

      ctx.timeframeScore=0.0;

      ctx.m1Score=0.0;
      ctx.m5Score=0.0;
      ctx.m15Score=0.0;
      ctx.m30Score=0.0;

      ctx.h1Score=0.0;
      ctx.h4Score=0.0;

      ctx.d1Score=0.0;
      ctx.w1Score=0.0;
      ctx.mn1Score=0.0;

      ctx.alignedBullishTFs=0;
      ctx.alignedBearishTFs=0;
      ctx.neutralTFCount=0;

      ctx.timeframeState=LAYER_NEUTRAL;

      //==============================================================
      // VALIDAÇÃO DO CONTEXTO
      //==============================================================
      if(ctx.symbol=="")
        {
         ctx.timeframeState=LAYER_INVALID;
         return false;
        }

      //==============================================================
      // GARANTE QUE O SÍMBOLO ESTÁ DISPONÍVEL
      //==============================================================
      if(!SymbolSelect(ctx.symbol,true))
        {
         ctx.timeframeState=LAYER_INVALID;
         return false;
        }

      //==============================================================
      // ANALISA TODOS OS TIMEFRAMES
      //==============================================================
      ctx.m1Score=
         CalculateTimeframeScore(
            ctx.symbol,
            PERIOD_M1
         );

      ctx.m5Score=
         CalculateTimeframeScore(
            ctx.symbol,
            PERIOD_M5
         );

      ctx.m15Score=
         CalculateTimeframeScore(
            ctx.symbol,
            PERIOD_M15
         );

      ctx.m30Score=
         CalculateTimeframeScore(
            ctx.symbol,
            PERIOD_M30
         );

      ctx.h1Score=
         CalculateTimeframeScore(
            ctx.symbol,
            PERIOD_H1
         );

      ctx.h4Score=
         CalculateTimeframeScore(
            ctx.symbol,
            PERIOD_H4
         );

      ctx.d1Score=
         CalculateTimeframeScore(
            ctx.symbol,
            PERIOD_D1
         );

      ctx.w1Score=
         CalculateTimeframeScore(
            ctx.symbol,
            PERIOD_W1
         );

      ctx.mn1Score=
         CalculateTimeframeScore(
            ctx.symbol,
            PERIOD_MN1
         );

      //==============================================================
      // CONTADORES
      //==============================================================
      UpdateAlignment(ctx);

      //==============================================================
      // SCORE PONDERADO
      //==============================================================
      double weightedScore=
         CalculateWeightedScore(ctx);

      //==============================================================
      // SCORE DE ALINHAMENTO
      //==============================================================
      double alignmentScore=
         CalculateAlignmentScore(
            ctx.alignedBullishTFs,
            ctx.alignedBearishTFs,
            ctx.neutralTFCount
         );

      //==============================================================
      // COMBINA SCORE DOS TIMEFRAMES COM ALINHAMENTO
      //==============================================================
      // O contrato exporta magnitude; a direção permanece nos
      // contadores alignedBullishTFs/alignedBearishTFs.
      ctx.timeframeScore=
         Clamp(
            MathAbs(
               weightedScore*0.65+
               alignmentScore*0.35
            ),
            0.0,
            100.0
         );

      //==============================================================
      // ALINHAMENTO FINAL
      //==============================================================
      ctx.timeframeAligned=
         IsAligned(
            ctx.alignedBullishTFs,
            ctx.alignedBearishTFs,
            ctx.neutralTFCount,
            ctx.timeframeScore
         );

      //==============================================================
      // ESTADO DA CAMADA
      //==============================================================
      if(ctx.timeframeAligned)
         ctx.timeframeState=LAYER_VALID;
      else
         ctx.timeframeState=LAYER_NEUTRAL;

      //==============================================================
      // LOG
      //==============================================================
      PrintFormat(
         "[TimeframeAnalyzer] %s | "
         "M1=%.1f M5=%.1f M15=%.1f M30=%.1f "
         "H1=%.1f H4=%.1f D1=%.1f W1=%.1f MN1=%.1f | "
         "Score=%.1f | "
         "Bull=%d Bear=%d Neutral=%d | "
         "Aligned=%s",
         ctx.symbol,
         ctx.m1Score,
         ctx.m5Score,
         ctx.m15Score,
         ctx.m30Score,
         ctx.h1Score,
         ctx.h4Score,
         ctx.d1Score,
         ctx.w1Score,
         ctx.mn1Score,
         ctx.timeframeScore,
         ctx.alignedBullishTFs,
         ctx.alignedBearishTFs,
         ctx.neutralTFCount,
         ctx.timeframeAligned ? "TRUE" : "FALSE"
      );

      return true;
     }

   //=================================================================
   // SETTERS
   //=================================================================
   void SetLookbackBars(const int value)
     {
      m_lookbackBars=
         MathMax(10,value);
     }

   void SetMinimumDirectionalScore(const double value)
     {
      m_minDirectionalScore=
         Clamp(value,1.0,100.0);
     }

   void SetAlignmentThreshold(const double value)
     {
      m_alignmentThreshold=
         Clamp(value,0.50,1.0);
     }

   //=================================================================
   // GETTERS
   //=================================================================
   double GetTimeframeScore(
      const AnalysisContext &ctx) const
     {
      return ctx.timeframeScore;
     }

   bool IsTimeframeAligned(
      const AnalysisContext &ctx) const
     {
      return ctx.timeframeAligned;
     }

   int GetBullishCount(
      const AnalysisContext &ctx) const
     {
      return ctx.alignedBullishTFs;
     }

   int GetBearishCount(
      const AnalysisContext &ctx) const
     {
      return ctx.alignedBearishTFs;
     }

   int GetNeutralCount(
      const AnalysisContext &ctx) const
     {
      return ctx.neutralTFCount;
     }
  };

//+------------------------------------------------------------------+
#endif // ASTRA_TIMEFRAMEANALYZER_MQH
//+------------------------------------------------------------------+
