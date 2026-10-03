//+------------------------------------------------------------------+
//| VolumeProfileEngine.mqh                                          |
//| Astra Trader AI                                                  |
//|                                                                  |
//| ESTÁGIO: VOLUME PROFILE                                          |
//|                                                                  |
//| RESPONSABILIDADES:                                               |
//|  - Construir perfil aproximado de volume                         |
//|  - Identificar POC                                               |
//|  - Identificar Value Area                                         |
//|  - Identificar concentração                                      |
//|  - Identificar HVN/LVN                                           |
//|  - Avaliar pressão relativa                                      |
//|  - Alimentar AnalysisContext                                     |
//|                                                                  |
//| CONTRATO:                                                        |
//|  - NÃO utiliza CopyRates()                                       |
//|  - Consome exclusivamente AnalysisContext.marketBars[]           |
//|  - Usa somente candles fechados para construir o perfil          |
//|  - NÃO decide BUY/SELL                                           |
//|  - NÃO calcula lote                                               |
//|  - NÃO calcula SL/TP                                              |
//|  - NÃO executa ordens                                             |
//+------------------------------------------------------------------+
#ifndef ASTRA_VOLUMEPROFILEENGINE_MQH
#define ASTRA_VOLUMEPROFILEENGINE_MQH

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>


//+------------------------------------------------------------------+
//| VolumeProfileEngine                                              |
//+------------------------------------------------------------------+
class VolumeProfileEngine
{
private:

   int    m_lookbackBars;
   int    m_profileRows;
   double m_valueAreaPercent;


   //=================================================================
   // CLAMP
   //=================================================================

   double Clamp(
      const double value,
      const double minValue,
      const double maxValue
   ) const
   {
      if(value < minValue)
         return minValue;

      if(value > maxValue)
         return maxValue;

      return value;
   }


   //=================================================================
   // PREÇO TÍPICO
   //=================================================================

   double TypicalPrice(
      const MqlRates &bar
   ) const
   {
      return (
         bar.high +
         bar.low +
         bar.close
      ) / 3.0;
   }


   //=================================================================
   // RANGE
   //=================================================================

   bool FindPriceRange(
      const MqlRates &rates[],
      const int count,
      double &priceLow,
      double &priceHigh
   ) const
   {
      if(count <= 0)
         return false;

      priceLow  = DBL_MAX;
      priceHigh = -DBL_MAX;

      for(int i = 0; i < count; i++)
      {
         if(rates[i].low < priceLow)
            priceLow = rates[i].low;

         if(rates[i].high > priceHigh)
            priceHigh = rates[i].high;
      }

      if(
         priceLow == DBL_MAX ||
         priceHigh == -DBL_MAX
      )
      {
         return false;
      }

      if(priceHigh <= priceLow)
         return false;

      return true;
   }


   //=================================================================
   // PREÇO -> BIN
   //=================================================================

   int PriceToBin(
      const double price,
      const double priceLow,
      const double priceHigh,
      const double binSize,
      const int rows
   ) const
   {
      if(rows <= 0)
         return -1;

      if(binSize <= 0.0)
         return -1;

      if(priceHigh <= priceLow)
         return -1;

      int index =
         (int)MathFloor(
            (price - priceLow) /
            binSize
         );

      if(index < 0)
         index = 0;

      if(index >= rows)
         index = rows - 1;

      return index;
   }


   //=================================================================
   // POC
   //=================================================================

   int FindPOCBin(
      const double &profile[],
      const int rows
   ) const
   {
      if(rows <= 0)
         return -1;

      double maximumVolume =
         -1.0;

      int poc =
         -1;

      for(int i = 0; i < rows; i++)
      {
         if(profile[i] > maximumVolume)
         {
            maximumVolume =
               profile[i];

            poc =
               i;
         }
      }

      return poc;
   }


   //=================================================================
   // VALUE AREA
   //=================================================================

   void CalculateValueArea(
      const double &profile[],
      const int rows,
      const int poc,
      const double targetVolume,
      int &valueLowBin,
      int &valueHighBin
   ) const
   {
      valueLowBin =
         poc;

      valueHighBin =
         poc;

      if(
         poc < 0 ||
         poc >= rows ||
         rows <= 0 ||
         targetVolume <= 0.0
      )
      {
         return;
      }

      double accumulated =
         profile[poc];

      while(accumulated < targetVolume)
      {
         const int lower =
            valueLowBin - 1;

         const int upper =
            valueHighBin + 1;

         if(
            lower < 0 &&
            upper >= rows
         )
         {
            break;
         }

         double lowerVolume =
            -1.0;

         double upperVolume =
            -1.0;

         if(lower >= 0)
            lowerVolume =
               profile[lower];

         if(upper < rows)
            upperVolume =
               profile[upper];

         if(
            lowerVolume >= upperVolume &&
            lower >= 0
         )
         {
            accumulated +=
               lowerVolume;

            valueLowBin =
               lower;
         }
         else
         if(upper < rows)
         {
            accumulated +=
               upperVolume;

            valueHighBin =
               upper;
         }
         else
         {
            break;
         }
      }
   }


   //=================================================================
   // MÉDIA DE VOLUME
   //=================================================================

   double CalculateAverageVolume(
      const MqlRates &rates[],
      const int count
   ) const
   {
      if(count <= 0)
         return 0.0;

      double total =
         0.0;

      int valid =
         0;

      for(int i = 0; i < count; i++)
      {
         if(rates[i].tick_volume <= 0)
            continue;

         total +=
            (double)rates[i].tick_volume;

         valid++;
      }

      if(valid <= 0)
         return 0.0;

      return
         total /
         (double)valid;
   }


   //=================================================================
   // PRESSÃO
   //=================================================================

   double CalculateVolumePressure(
      const MqlRates &rates[],
      const int count
   ) const
   {
      if(count <= 0)
         return 0.0;

      double weightedPressure =
         0.0;

      double totalVolume =
         0.0;

      for(int i = 0; i < count; i++)
      {
         const double range =
            rates[i].high -
            rates[i].low;

         if(range <= 0.0)
            continue;

         double position =
            (
               rates[i].close -
               rates[i].low
            ) / range;

         position =
            Clamp(
               position,
               0.0,
               1.0
            );

         const double pressure =
            (position * 2.0) -
            1.0;

         const double volume =
            (double)rates[i].tick_volume;

         if(volume <= 0.0)
            continue;

         weightedPressure +=
            pressure *
            volume;

         totalVolume +=
            volume;
      }

      if(totalVolume <= 0.0)
         return 0.0;

      return Clamp(
         (
            weightedPressure /
            totalVolume
         ) * 100.0,
         -100.0,
         100.0
      );
   }


   //=================================================================
   // ABSORÇÃO ESTIMADA
   //=================================================================

   double CalculateAbsorption(
      const MqlRates &rates[],
      const int count,
      const double averageVolume
   ) const
   {
      if(
         count <= 0 ||
         averageVolume <= 0.0
      )
      {
         return 0.0;
      }

      double score =
         0.0;

      int samples =
         0;

      for(int i = 0; i < count; i++)
      {
         const double range =
            rates[i].high -
            rates[i].low;

         if(range <= 0.0)
            continue;

         const double volume =
            (double)rates[i].tick_volume;

         if(volume <= 0.0)
            continue;

         const double volumeRatio =
            volume /
            averageVolume;

         if(volumeRatio < 1.50)
            continue;

         double closePosition =
            (
               rates[i].close -
               rates[i].low
            ) / range;

         closePosition =
            Clamp(
               closePosition,
               0.0,
               1.0
            );

         const double distanceFromCenter =
            MathAbs(
               closePosition -
               0.50
            );

         if(distanceFromCenter < 0.20)
         {
            score +=
               10.0;

            samples++;
         }
      }

      if(samples <= 0)
         return 0.0;

      return Clamp(
         score,
         0.0,
         100.0
      );
   }


   //=================================================================
   // HVN
   //=================================================================

   int FindNearestHighVolumeNode(
      const double &profile[],
      const int rows,
      const int poc
   ) const
   {
      if(
         rows <= 0 ||
         poc < 0 ||
         poc >= rows
      )
      {
         return -1;
      }

      const double pocVolume =
         profile[poc];

      if(pocVolume <= 0.0)
         return -1;

      const double threshold =
         pocVolume * 0.50;

      int best =
         -1;

      double bestDistance =
         DBL_MAX;

      for(int i = 0; i < rows; i++)
      {
         if(i == poc)
            continue;

         if(profile[i] < threshold)
            continue;

         const double distance =
            MathAbs(
               (double)i -
               (double)poc
            );

         if(distance < bestDistance)
         {
            bestDistance =
               distance;

            best =
               i;
         }
      }

      return best;
   }


   //=================================================================
   // LVN
   //=================================================================

   int FindNearestLowVolumeNode(
      const double &profile[],
      const int rows,
      const int poc
   ) const
   {
      if(
         rows <= 0 ||
         poc < 0 ||
         poc >= rows
      )
      {
         return -1;
      }

      const double pocVolume =
         profile[poc];

      if(pocVolume <= 0.0)
         return -1;

      const double threshold =
         pocVolume * 0.20;

      int best =
         -1;

      double bestDistance =
         DBL_MAX;

      for(int i = 0; i < rows; i++)
      {
         if(i == poc)
            continue;

         if(profile[i] <= 0.0)
            continue;

         if(profile[i] > threshold)
            continue;

         const double distance =
            MathAbs(
               (double)i -
               (double)poc
            );

         if(distance < bestDistance)
         {
            bestDistance =
               distance;

            best =
               i;
         }
      }

      return best;
   }


   //=================================================================
   // CONCENTRAÇÃO
   //=================================================================

   double CalculateConcentration(
      const double &profile[],
      const int rows,
      const double totalVolume
   ) const
   {
      if(
         rows <= 0 ||
         totalVolume <= 0.0
      )
      {
         return 0.0;
      }

      double maximumVolume =
         0.0;

      for(int i = 0; i < rows; i++)
      {
         if(profile[i] > maximumVolume)
            maximumVolume =
               profile[i];
      }

      if(maximumVolume <= 0.0)
         return 0.0;

      const double concentration =
         (
            maximumVolume /
            totalVolume
         ) *
         (double)rows *
         100.0;

      return Clamp(
         concentration,
         0.0,
         100.0
      );
   }


   //=================================================================
   // SCORE
   //=================================================================

   double CalculateProfileScore(
      const double pressure,
      const double concentration,
      const bool abovePOC,
      const bool belowPOC,
      const bool insideValueArea
   ) const
   {
      double score =
         pressure * 0.70;

      if(abovePOC)
         score +=
            concentration * 0.15;
      else
      if(belowPOC)
         score -=
            concentration * 0.15;

      if(insideValueArea)
         score *= 0.85;

      return Clamp(
         score,
         -100.0,
         100.0
      );
   }


public:

   //=================================================================
   // CONSTRUTOR
   //=================================================================

   VolumeProfileEngine(
      const int lookbackBars = 150,
      const int profileRows = 40,
      const double valueAreaPercent = 0.70
   )
   {
      m_lookbackBars =
         MathMax(
            20,
            lookbackBars
         );

      m_profileRows =
         MathMax(
            10,
            profileRows
         );

      m_valueAreaPercent =
         Clamp(
            valueAreaPercent,
            0.50,
            0.95
         );
   }


   //=================================================================
   // ANALYZE
   //=================================================================

   bool Analyze(
      AnalysisContext &ctx
   )
   {
      //==============================================================
      // RESET SOMENTE DOS CAMPOS PRÓPRIOS
      //==============================================================

      ctx.volumeProfileScore =
         0.0;

      ctx.pointOfControl =
         0.0;

      ctx.valueAreaHigh =
         0.0;

      ctx.valueAreaLow =
         0.0;

      ctx.volumePressure =
         0.0;

      ctx.volumeDirectionalScore =
         0.0;

      ctx.bullishVolumePressure =
         0.0;

      ctx.bearishVolumePressure =
         0.0;

      ctx.volumeConcentration =
         0.0;

      ctx.volumeImbalance =
         0.0;

      ctx.nearestHighVolumeNode =
         0.0;

      ctx.nearestLowVolumeNode =
         0.0;

      ctx.priceAbovePOC =
         false;

      ctx.priceBelowPOC =
         false;

      ctx.insideValueArea =
         false;

      ctx.aboveValueArea =
         false;

      ctx.belowValueArea =
         false;


      //==============================================================
      // VALIDAÇÃO
      //==============================================================

      if(ctx.symbol == "")
      {
         ctx.volumeProfileState =
            LAYER_INVALID;

         return false;
      }

      if(ctx.primaryTF == PERIOD_CURRENT)
      {
         ctx.volumeProfileState =
            LAYER_INVALID;

         return false;
      }

      if(!ctx.marketHistoryReady)
      {
         ctx.volumeProfileState =
            LAYER_INVALID;

         return false;
      }


      const int available =
         ctx.GetMarketBarCount();

      if(available < 21)
      {
         ctx.volumeProfileState =
            LAYER_INVALID;

         return false;
      }


      //==============================================================
      // SOMENTE CANDLES FECHADOS
      //
      // [0] atual
      // [1] fechado mais recente
      // [2+] fechados anteriores
      //==============================================================

      int count =
         MathMin(
            available - 1,
            m_lookbackBars
         );

      if(count < 20)
      {
         ctx.volumeProfileState =
            LAYER_INVALID;

         return false;
      }


      MqlRates rates[];

      if(
         ArrayResize(
            rates,
            count
         ) != count
      )
      {
         ctx.volumeProfileState =
            LAYER_INVALID;

         return false;
      }


      int validCount =
         0;

      for(int i = 1; i < available && validCount < count; i++)
      {
         if(ctx.marketBars[i].time <= 0)
            continue;

         rates[validCount] =
            ctx.marketBars[i];

         validCount++;
      }


      if(validCount < 20)
      {
         ctx.volumeProfileState =
            LAYER_INVALID;

         return false;
      }

      if(validCount != count)
      {
         ArrayResize(
            rates,
            validCount
         );

         count =
            validCount;
      }


      //==============================================================
      // RANGE
      //==============================================================

      double priceLow =
         0.0;

      double priceHigh =
         0.0;

      if(!FindPriceRange(
            rates,
            count,
            priceLow,
            priceHigh
         ))
      {
         ctx.volumeProfileState =
            LAYER_INVALID;

         return false;
      }


      const double priceRange =
         priceHigh -
         priceLow;

      if(priceRange <= 0.0)
      {
         ctx.volumeProfileState =
            LAYER_INVALID;

         return false;
      }


      const double binSize =
         priceRange /
         (double)m_profileRows;

      if(binSize <= 0.0)
      {
         ctx.volumeProfileState =
            LAYER_INVALID;

         return false;
      }


      //==============================================================
      // PERFIL
      //==============================================================

      double volumeProfile[];

      if(
         ArrayResize(
            volumeProfile,
            m_profileRows
         ) != m_profileRows
      )
      {
         ctx.volumeProfileState =
            LAYER_INVALID;

         return false;
      }

      ArrayInitialize(
         volumeProfile,
         0.0
      );


      double totalVolume =
         0.0;


      for(int i = 0; i < count; i++)
      {
         const double volume =
            (double)rates[i].tick_volume;

         if(volume <= 0.0)
            continue;

         const double typical =
            TypicalPrice(
               rates[i]
            );

         const int bin =
            PriceToBin(
               typical,
               priceLow,
               priceHigh,
               binSize,
               m_profileRows
            );

         if(bin < 0)
            continue;

         volumeProfile[bin] +=
            volume;

         totalVolume +=
            volume;
      }


      if(totalVolume <= 0.0)
      {
         ctx.volumeProfileState =
            LAYER_INVALID;

         return false;
      }


      //==============================================================
      // POC
      //==============================================================

      const int pocBin =
         FindPOCBin(
            volumeProfile,
            m_profileRows
         );

      if(pocBin < 0)
      {
         ctx.volumeProfileState =
            LAYER_INVALID;

         return false;
      }


      const double pocPrice =
         priceLow +
         (
            (double)pocBin +
            0.5
         ) *
         binSize;

      ctx.pointOfControl =
         pocPrice;


      //==============================================================
      // VALUE AREA
      //==============================================================

      const double targetVolume =
         totalVolume *
         m_valueAreaPercent;

      int valueLowBin =
         pocBin;

      int valueHighBin =
         pocBin;

      CalculateValueArea(
         volumeProfile,
         m_profileRows,
         pocBin,
         targetVolume,
         valueLowBin,
         valueHighBin
      );


      const double valueAreaLow =
         priceLow +
         (double)valueLowBin *
         binSize;

      const double valueAreaHigh =
         priceLow +
         (
            (double)valueHighBin +
            1.0
         ) *
         binSize;


      ctx.valueAreaLow =
         valueAreaLow;

      ctx.valueAreaHigh =
         valueAreaHigh;


      //==============================================================
      // PREÇO ATUAL
      //
      // O perfil foi calculado apenas com candles fechados.
      // A localização do preço pode usar o preço analítico atual
      // já fornecido pelo MarketDataEngine.
      //==============================================================

      double currentPrice =
         ctx.price;

      if(currentPrice <= 0.0)
         currentPrice =
            ctx.close;

      if(currentPrice <= 0.0)
         currentPrice =
            ctx.marketBars[0].close;

      if(currentPrice <= 0.0)
      {
         ctx.volumeProfileState =
            LAYER_INVALID;

         return false;
      }


      //==============================================================
      // LOCALIZAÇÃO
      //==============================================================

      ctx.priceAbovePOC =
         currentPrice >
         pocPrice;

      ctx.priceBelowPOC =
         currentPrice <
         pocPrice;

      ctx.insideValueArea =
         (
            currentPrice >= valueAreaLow &&
            currentPrice <= valueAreaHigh
         );

      ctx.aboveValueArea =
         currentPrice >
         valueAreaHigh;

      ctx.belowValueArea =
         currentPrice <
         valueAreaLow;


      //==============================================================
      // PRESSÃO
      //==============================================================

      const double pressure =
         CalculateVolumePressure(
            rates,
            count
         );

      ctx.volumePressure =
         pressure;


      if(pressure > 0.0)
      {
         ctx.bullishVolumePressure =
            pressure;

         ctx.bearishVolumePressure =
            0.0;
      }
      else
      {
         ctx.bullishVolumePressure =
            0.0;

         ctx.bearishVolumePressure =
            MathAbs(
               pressure
            );
      }


      //==============================================================
      // IMBALANCE
      //==============================================================

      ctx.volumeImbalance =
         Clamp(
            pressure,
            -100.0,
            100.0
         );


      //==============================================================
      // CONCENTRAÇÃO
      //==============================================================

      ctx.volumeConcentration =
         CalculateConcentration(
            volumeProfile,
            m_profileRows,
            totalVolume
         );


      //==============================================================
      // HVN
      //==============================================================

      const int hvnBin =
         FindNearestHighVolumeNode(
            volumeProfile,
            m_profileRows,
            pocBin
         );

      if(hvnBin >= 0)
      {
         ctx.nearestHighVolumeNode =
            priceLow +
            (
               (double)hvnBin +
               0.5
            ) *
            binSize;
      }


      //==============================================================
      // LVN
      //==============================================================

      const int lvnBin =
         FindNearestLowVolumeNode(
            volumeProfile,
            m_profileRows,
            pocBin
         );

      if(lvnBin >= 0)
      {
         ctx.nearestLowVolumeNode =
            priceLow +
            (
               (double)lvnBin +
               0.5
            ) *
            binSize;
      }


      //==============================================================
      // SCORE
      //==============================================================

      ctx.volumeProfileScore =
         CalculateProfileScore(
            pressure,
            ctx.volumeConcentration,
            ctx.priceAbovePOC,
            ctx.priceBelowPOC,
            ctx.insideValueArea
         );

      // One canonical directional family score for all downstream consumers.
      ctx.volumeDirectionalScore =
         Clamp(
            ctx.volumeProfileScore + ctx.volumePressure,
            -100.0,
            100.0
         );


      //==============================================================
      // MÉDIA DE VOLUME
      //==============================================================

      const double averageVolume =
         CalculateAverageVolume(
            rates,
            count
         );


      //==============================================================
      // ABSORÇÃO
      //==============================================================

      ctx.absorptionScore =
         CalculateAbsorption(
            rates,
            count,
            averageVolume
         );


      //==============================================================
      // FLUXO INSTITUCIONAL ESTIMADO
      //
      // IMPORTANTE:
      // tick_volume não representa fluxo institucional real.
      // É apenas uma inferência.
      //==============================================================

      double institutionalFlow =
         pressure;

      if(ctx.priceAbovePOC)
         institutionalFlow +=
            10.0;
      else
      if(ctx.priceBelowPOC)
         institutionalFlow -=
            10.0;

      if(ctx.insideValueArea)
         institutionalFlow *=
            0.75;

      institutionalFlow +=
         ctx.absorptionScore *
         0.20;


      ctx.institutionalFlowScore =
         Clamp(
            institutionalFlow,
            -100.0,
            100.0
         );


      //==============================================================
      // IMPORTANTE:
      //
      // NÃO alteramos liquidityScore ou smartMoneyScore.
      //
      // Essas camadas possuem engines próprias.
      // O Volume Profile fornece apenas seus próprios campos.
      //==============================================================


      //==============================================================
      // ESTADO
      //==============================================================

      if(
         MathAbs(
            ctx.volumeProfileScore
         ) >= 20.0 ||
         ctx.volumeConcentration >= 30.0 ||
         MathAbs(
            ctx.volumeImbalance
         ) >= 30.0
      )
      {
         ctx.volumeProfileState =
            LAYER_VALID;
      }
      else
      {
         ctx.volumeProfileState =
            LAYER_NEUTRAL;
      }


      //==============================================================
      // LOG
      //==============================================================

      PrintFormat(
         "[VolumeProfileEngine] "
         "%s %s | "
         "Bars=%d | "
         "POC=%.5f | "
         "VAL=%.5f | "
         "VAH=%.5f | "
         "Pressure=%.2f | "
         "Imbalance=%.2f | "
         "Concentration=%.2f | "
         "HVN=%.5f | "
         "LVN=%.5f | "
         "Institutional=%.2f | "
         "Absorption=%.2f | "
         "Score=%.2f",
         ctx.symbol,
         EnumToString(
            ctx.primaryTF
         ),
         count,
         ctx.pointOfControl,
         ctx.valueAreaLow,
         ctx.valueAreaHigh,
         ctx.volumePressure,
         ctx.volumeImbalance,
         ctx.volumeConcentration,
         ctx.nearestHighVolumeNode,
         ctx.nearestLowVolumeNode,
         ctx.institutionalFlowScore,
         ctx.absorptionScore,
         ctx.volumeProfileScore
      );

      return true;
   }


   //=================================================================
   // SETTERS
   //=================================================================

   void SetLookbackBars(
      const int bars
   )
   {
      m_lookbackBars =
         MathMax(
            20,
            bars
         );
   }


   void SetProfileRows(
      const int rows
   )
   {
      m_profileRows =
         MathMax(
            10,
            rows
         );
   }


   void SetValueAreaPercent(
      const double percent
   )
   {
      m_valueAreaPercent =
         Clamp(
            percent,
            0.50,
            0.95
         );
   }


   //=================================================================
   // GETTERS
   //=================================================================

   int GetLookbackBars() const
   {
      return m_lookbackBars;
   }


   int GetProfileRows() const
   {
      return m_profileRows;
   }


   double GetValueAreaPercent() const
   {
      return m_valueAreaPercent;
   }
};


//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_VOLUMEPROFILEENGINE_MQH
