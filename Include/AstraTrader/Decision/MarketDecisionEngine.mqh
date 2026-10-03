//+------------------------------------------------------------------+
//| MarketDecisionEngine.mqh                                         |
//| Astra Trader AI                                                  |
//|                                                                  |
//| MOTOR CENTRAL DE DECISÃO                                         |
//|                                                                  |
//| CONTRATO:                                                        |
//|   AnalysisContext é a única fonte de verdade.                   |
//|                                                                  |
//| RESPONSABILIDADES:                                               |
//|   - consolidar evidências                                        |
//|   - determinar BUY / SELL / NONE                                 |
//|   - calcular probabilities                                       |
//|   - calcular consensus                                           |
//|   - calcular confluence                                          |
//|   - calcular confidence                                           |
//|   - determinar opportunity grade                                  |
//|   - registrar trace da decisão                                   |
//|   - aplicar Mempool Context Modifier                              |
//|                                                                  |
//| NÃO RESPONSÁVEL POR:                                             |
//|   - Entry                                                        |
//|   - SL / TP                                                      |
//|   - lote                                                         |
//|   - risco                                                        |
//|   - margem                                                       |
//|   - execução                                                     |
//|                                                                  |
//| MEMPOOL CONTRACT:                                                |
//|   O Mempool NÃO determina BUY / SELL.                            |
//|   O Mempool NÃO altera bull / bear.                              |
//|   O Mempool NÃO altera consensus / confluence.                   |
//|                                                                  |
//|   O Mempool somente pode modificar a confiança final quando:     |
//|                                                                  |
//|      mempoolValid       == true                                  |
//|      mempoolConnected   == true                                  |
//|      mempoolAnalysisReady == true                                |
//|      mempoolStale       == false                                 |
//|                                                                  |
//|   O modifier é pequeno, determinístico e limitado a +5%.         |
//+------------------------------------------------------------------+
#ifndef ASTRA_MARKETDECISIONENGINE_MQH
#define ASTRA_MARKETDECISIONENGINE_MQH

#property strict

#include <AstraTrader\Core\Types.mqh>
#include <AstraTrader\Core\Config.mqh>
#include <AstraTrader\Analysis\AnalysisContext.mqh>


class MarketDecisionEngine
{
private:

   string m_status;
   string m_reason;


   //=================================================================
   // CLAMP SCORE
   //=================================================================
   double ClampScore(
      const double value
   ) const
   {
      if(value < -100.0)
         return -100.0;

      if(value > 100.0)
         return 100.0;

      return value;
   }


   //=================================================================
   // CLAMP POSITIVE
   //=================================================================
   double ClampPositive(
      const double value
   ) const
   {
      if(value < 0.0)
         return 0.0;

      if(value > 100.0)
         return 100.0;

      return value;
   }


   //=================================================================
   // CLAMP CONFIDENCE
   //=================================================================
   double ClampConfidence(
      const double value
   ) const
   {
      if(value < 0.0)
         return 0.0;

      if(value > 1.0)
         return 1.0;

      return value;
   }


   //=================================================================
   // RESET
   //=================================================================
   void ResetInternal()
   {
      m_status =
         "RESET";

      m_reason =
         "Sem decisão";
   }


   //=================================================================
   // CONTRIBUTION GENÉRICA
   //=================================================================
   void AddContribution(
      const double score,
      double &bull,
      double &bear
   )
   {
      const double value =
         ClampScore(
            score
         );

      if(value > 0.0)
      {
         bull += value;
      }
      else
      if(value < 0.0)
      {
         bear += MathAbs(value);
      }
   }

   void AddMagnitudeContribution(
      const double score,
      const bool bullish,
      const bool bearish,
      double &bull,
      double &bear
   )
   {
      const double value = MathAbs(ClampScore(score));
      if(bullish && !bearish)
         bull += value;
      else
      if(bearish && !bullish)
         bear += value;
   }


   //=================================================================
   // CONTRIBUTION ESTRUTURAL
   //
   // StructuralScore representa magnitude.
   // structuralBias representa a direção.
   //
   // Portanto:
   //
   //   BIAS_BULLISH + Score positivo  -> bullish
   //   BIAS_BEARISH + Score positivo  -> bearish
   //
   // StructuralScore positivo NÃO deve ser interpretado isoladamente
   // como BUY.
   //=================================================================
   void AddStructuralContribution(
      const AnalysisContext &c,
      double &bull,
      double &bear
   )
   {
      const double score =
         ClampScore(
            c.structuralScore
         );

      if(score <= 0.0)
         return;


      if(c.structuralBias == BIAS_BULLISH)
      {
         bull += score;
         return;
      }


      if(c.structuralBias == BIAS_BEARISH)
      {
         bear += score;
         return;
      }


      // BIAS_NEUTRAL:
      // não adiciona direção.
   }


   //=================================================================
   // PROBABILIDADES
   //=================================================================
   void CalculateProbabilities(
      const double bull,
      const double bear,
      double &buy,
      double &sell
   )
   {
      const double bullish =
         ClampPositive(
            bull
         );

      const double bearish =
         ClampPositive(
            bear
         );

      const double total =
         bullish +
         bearish;

      if(total <= 0.0)
      {
         buy  = 0.50;
         sell = 0.50;

         return;
      }

      buy =
         ClampConfidence(
            bullish / total
         );

      sell =
         ClampConfidence(
            bearish / total
         );
   }


   //=================================================================
   // CONTAGEM DE FATORES
   //
   // StructuralScore representa magnitude.
   // A direção vem de structuralBias.
   //
   // Exemplo:
   //
   //   structuralBias = BIAS_BEARISH
   //   structuralScore = +65
   //
   // Isso representa evidência bearish de força 65.
   //=================================================================
   void CalculateFactorCounts(
      const AnalysisContext &c,
      int &bullFactors,
      int &bearFactors,
      int &neutralFactors
   )
   {
      bullFactors    = 0;
      bearFactors    = 0;
      neutralFactors = 0;


      //==============================================================
      // STRUCTURE
      //==============================================================

      if(c.structuralBias == BIAS_BULLISH)
      {
         if(
            c.structuralScore != 0.0 ||
            c.bos ||
            c.choch
         )
         {
            bullFactors++;
         }
         else
         {
            neutralFactors++;
         }
      }
      else
      if(c.structuralBias == BIAS_BEARISH)
      {
         if(
            c.structuralScore != 0.0 ||
            c.bos ||
            c.choch
         )
         {
            bearFactors++;
         }
         else
         {
            neutralFactors++;
         }
      }
      else
      {
         neutralFactors++;
      }


      //==============================================================
      // LIQUIDITY
      //==============================================================

      if(c.sellSideLiquidityTaken && !c.buySideLiquidityTaken)
         bullFactors++;
      else
      if(c.buySideLiquidityTaken && !c.sellSideLiquidityTaken)
         bearFactors++;
      else
         neutralFactors++;


      //==============================================================
      // SMART MONEY
      //==============================================================

      if(c.smartMoneyScore > 0.0)
         bullFactors++;
      else
      if(c.smartMoneyScore < 0.0)
         bearFactors++;
      else
         neutralFactors++;


      //==============================================================
      // WYCKOFF
      //==============================================================

      const bool wyckoffBullish = c.springDetected || c.sosDetected;
      const bool wyckoffBearish = c.upthrustDetected || c.sowDetected;
      if(wyckoffBullish && !wyckoffBearish)
         bullFactors++;
      else
      if(wyckoffBearish && !wyckoffBullish)
         bearFactors++;
      else
         neutralFactors++;


      //==============================================================
      // ELLIOTT
      //==============================================================

      // elliottScore não possui direção explícita no contexto.
      neutralFactors++;


      //==============================================================
      // TIMEFRAME
      //==============================================================
      // TrafficLightEngine is the single source of D1/H4/H1/M15/M5
      // multi-timeframe information in the active pipeline. Legacy
      // alignedBullishTFs/alignedBearishTFs remain diagnostic only.
      neutralFactors++;


      //==============================================================
      // PATTERN
      //==============================================================

      if(c.patternScore > 0.0)
         bullFactors++;
      else
      if(c.patternScore < 0.0)
         bearFactors++;
      else
         neutralFactors++;


      //==============================================================
      // MOMENTUM
      //==============================================================

      if(c.momentumScore > 0.0)
         bullFactors++;
      else
      if(c.momentumScore < 0.0)
         bearFactors++;
      else
         neutralFactors++;


      //==============================================================
      // VOLUME
      //==============================================================

      if(c.volumeDirectionalScore > 0.0)
         bullFactors++;
      else
      if(c.volumeDirectionalScore < 0.0)
         bearFactors++;
      else
         neutralFactors++;


      //==============================================================
      // TECHNICAL INTELLIGENCE
      //==============================================================

      // Score de inteligência técnica não expõe direção.
      neutralFactors++;


      //==============================================================
      // TRAFFIC
      //==============================================================

      if(c.mtfCanonicalDirection == TRAFFIC_BULLISH)
         bullFactors++;
      else
      if(c.mtfCanonicalDirection == TRAFFIC_BEARISH)
         bearFactors++;
      else
         neutralFactors++;
   }


   //=================================================================
   // CONSENSUS DIRECIONAL PONDERADO
   //
   // O Consensus permanece coerente com a direção escolhida pelo
   // domínio de força bullish/bearish.
   //
   // Componentes:
   //   1) dominância ponderada (Bull/Bear)
   //   2) acordo dos fatores direcionais (votos)
   //
   // A dominância define o sinal. O acordo reduz a magnitude quando
   // os fatores discordam, sem inverter artificialmente a direção.
   //
   // Exemplo:
   //   RawDominance = +60%
   //   FactorAgreement = 50%
   //   Consensus = +30%
   //
   // Assim, uma divergência entre força e votos reduz o Consensus e
   // pode bloquear a entrada pelo threshold existente de 25%, sem
   // produzir a inconsistência BUY + Consensus negativo.
   //=================================================================
   double CalculateConsensus(
      const AnalysisContext &c
   ) const
   {
      // Consensus measures directional strength only.
      // Factor voting and evidence coverage are handled separately.
      const double bullish =
         ClampPositive(c.buyScore);

      const double bearish =
         ClampPositive(c.sellScore);

      const double total =
         bullish +
         bearish;

      if(total <= 0.0)
         return 0.0;

      const double rawDominance =
         (
            (bullish - bearish) /
            total
         );

      return ClampScore(
         rawDominance * 100.0
      );
   }


   //=================================================================
   // WEIGHTED EVIDENCE QUALITY
   //
   // Separates:
   //   - Strength: how much one side dominates
   //   - Coverage: how many eligible evidence families are active
   //   - Agreement: how much active evidence supports the candidate
   //
   // Evidence families intentionally avoid double-counting subcomponents
   // that belong to the same family (e.g. VolumeProfile + VolumePressure).
   // Derived/context-only signals do not inflate directional coverage.
   //=================================================================
   void CalculateEvidenceQuality(
      const AnalysisContext &c,
      const double bull,
      const double bear,
      const ENUM_DECISION decision,
      double &strength,
      double &coverage,
      double &agreement,
      double &quality,
      double &eligibleWeight,
      double &activeWeight,
      double &alignedWeight,
      double &opposingWeight
   ) const
   {
      strength = 0.0;
      coverage = 0.0;
      agreement = 0.0;
      quality = 0.0;
      eligibleWeight = 0.0;
      activeWeight = 0.0;
      alignedWeight = 0.0;
      opposingWeight = 0.0;

      const double totalStrength =
         ClampPositive(bull) +
         ClampPositive(bear);

      if(totalStrength > 0.0)
      {
         strength =
            MathAbs(
               bull - bear
            ) /
            totalStrength;
      }

      // Family weights: primary evidence > secondary/conditional evidence.
      const double W_STRUCTURE = 2.00;
      // Smart Money is composite/derived from Structure, Liquidity, OB/FVG;
      // it is confirmation only and is deliberately excluded from independent coverage.
      const double W_MOMENTUM = 1.25;
      const double W_VOLUME = 1.25;
      // Standalone MultiTimeframeEngine is not a true multi-TF source in this phase.
      // TrafficLight already supplies D1/H4/H1/M15/M5, so MTF is a Traffic substate.
      const double W_TRAFFIC = 1.00;
      const double W_LIQUIDITY = 0.75;
      const double W_WYCKOFF = 0.75;
      const double W_PATTERN = 0.75;

      // Adds one evidence family to the weighted accounting.
      // state: +1 bull, -1 bear, 0 neutral.
      // eligible means the family was available for directional analysis.
      // active means it produced a directional state.
      // aligned/opposing are measured against the candidate decision.
      // Structure: always direction-capable; neutral structure is a real
      // analyzed absence of directional confirmation, not NON_DIRECTIONAL.
      eligibleWeight += W_STRUCTURE;
      if(c.structuralBias == BIAS_BULLISH &&
         (c.structuralScore != 0.0 || c.bos || c.choch))
      {
         activeWeight += W_STRUCTURE;
         if(decision == DECISION_BUY) alignedWeight += W_STRUCTURE;
         else opposingWeight += W_STRUCTURE;
      }
      else if(c.structuralBias == BIAS_BEARISH &&
              (c.structuralScore != 0.0 || c.bos || c.choch))
      {
         activeWeight += W_STRUCTURE;
         if(decision == DECISION_SELL) alignedWeight += W_STRUCTURE;
         else opposingWeight += W_STRUCTURE;
      }

      // SmartMoney: composite confirmation only; not an independent evidence family.

      // Momentum.
      eligibleWeight += W_MOMENTUM;
      if(c.momentumScore > 0.0)
      {
         activeWeight += W_MOMENTUM;
         if(decision == DECISION_BUY) alignedWeight += W_MOMENTUM;
         else opposingWeight += W_MOMENTUM;
      }
      else if(c.momentumScore < 0.0)
      {
         activeWeight += W_MOMENTUM;
         if(decision == DECISION_SELL) alignedWeight += W_MOMENTUM;
         else opposingWeight += W_MOMENTUM;
      }

      // Volume.
      if(c.volumeProfileEnabled)
      {
         eligibleWeight += W_VOLUME;
         const double volumeDirection = c.volumeDirectionalScore;
         if(volumeDirection > 0.0)
         {
            activeWeight += W_VOLUME;
            if(decision == DECISION_BUY) alignedWeight += W_VOLUME;
            else opposingWeight += W_VOLUME;
         }
         else if(volumeDirection < 0.0)
         {
            activeWeight += W_VOLUME;
            if(decision == DECISION_SELL) alignedWeight += W_VOLUME;
            else opposingWeight += W_VOLUME;
         }
      }

      // MTF is represented by TrafficLightEngine multi-timeframe state.
      // Do not count it as a second independent family.

      // Traffic is a primary directional family only when the aggregated
      // direction crosses the TrafficLight directional threshold. Its
      // bullish/bearish component scores remain contextual when direction=NONE.
      const double trafficTotal =
         MathMax(0.0, c.trafficBullishScore) +
         MathMax(0.0, c.trafficBearishScore);
      if(trafficTotal > 0.0 ||
         c.mtfCanonicalDirection != TRAFFIC_NONE)
      {
         eligibleWeight += W_TRAFFIC;
         if(c.mtfCanonicalDirection == TRAFFIC_BULLISH)
         {
            activeWeight += W_TRAFFIC;
            if(decision == DECISION_BUY) alignedWeight += W_TRAFFIC;
            else opposingWeight += W_TRAFFIC;
         }
         else if(c.mtfCanonicalDirection == TRAFFIC_BEARISH)
         {
            activeWeight += W_TRAFFIC;
            if(decision == DECISION_SELL) alignedWeight += W_TRAFFIC;
            else opposingWeight += W_TRAFFIC;
         }
      }

      // Liquidity only becomes an independent directional family when a
      // directional event (sweep/taken) is present. A standalone numeric
      // liquidity score is diagnostic/contextual and must not dilute Coverage.
      if(c.sellSideLiquidityTaken && !c.buySideLiquidityTaken)
      {
         eligibleWeight += W_LIQUIDITY;
         activeWeight += W_LIQUIDITY;
         if(decision == DECISION_BUY) alignedWeight += W_LIQUIDITY;
         else opposingWeight += W_LIQUIDITY;
      }
      else if(c.buySideLiquidityTaken && !c.sellSideLiquidityTaken)
      {
         eligibleWeight += W_LIQUIDITY;
         activeWeight += W_LIQUIDITY;
         if(decision == DECISION_SELL) alignedWeight += W_LIQUIDITY;
         else opposingWeight += W_LIQUIDITY;
      }
      else if(c.sellSideLiquidityTaken && c.buySideLiquidityTaken)
      {
         // Both sides taken: family was analyzed but produced no unique
         // direction, so it remains out of active/eligible directional weight.
      }

      // Wyckoff only becomes an independent directional family when a
      // directional event (Spring/SOS/Upthrust/SOW) is detected. A numeric
      // Wyckoff score without an event is contextual/diagnostic only.
      const bool wyckoffBullish =
         c.springDetected || c.sosDetected;
      const bool wyckoffBearish =
         c.upthrustDetected || c.sowDetected;
      if(wyckoffBullish && !wyckoffBearish)
      {
         eligibleWeight += W_WYCKOFF;
         activeWeight += W_WYCKOFF;
         if(decision == DECISION_BUY) alignedWeight += W_WYCKOFF;
         else opposingWeight += W_WYCKOFF;
      }
      else if(wyckoffBearish && !wyckoffBullish)
      {
         eligibleWeight += W_WYCKOFF;
         activeWeight += W_WYCKOFF;
         if(decision == DECISION_SELL) alignedWeight += W_WYCKOFF;
         else opposingWeight += W_WYCKOFF;
      }

      // Pattern.
      if(c.patternScore != 0.0 ||
         c.bullishPatternDetected ||
         c.bearishPatternDetected)
      {
         eligibleWeight += W_PATTERN;
         if(c.bullishPatternDetected && !c.bearishPatternDetected)
         {
            activeWeight += W_PATTERN;
            if(decision == DECISION_BUY) alignedWeight += W_PATTERN;
            else opposingWeight += W_PATTERN;
         }
         else if(c.bearishPatternDetected && !c.bullishPatternDetected)
         {
            activeWeight += W_PATTERN;
            if(decision == DECISION_SELL) alignedWeight += W_PATTERN;
            else opposingWeight += W_PATTERN;
         }
         else if(c.patternScore > 0.0)
         {
            activeWeight += W_PATTERN;
            if(decision == DECISION_BUY) alignedWeight += W_PATTERN;
            else opposingWeight += W_PATTERN;
         }
         else if(c.patternScore < 0.0)
         {
            activeWeight += W_PATTERN;
            if(decision == DECISION_SELL) alignedWeight += W_PATTERN;
            else opposingWeight += W_PATTERN;
         }
      }

      // OrderBlock/FVG/Elliott are confirmation/derived signals in the
      // current implementation. Their direction is not independent of
      // Structure/FVG state, so they do not inflate coverage.

      if(eligibleWeight > 0.0)
         coverage = activeWeight / eligibleWeight;

      if(activeWeight > 0.0)
         agreement = alignedWeight / activeWeight;

      quality =
         ClampConfidence(
            strength *
            coverage *
            agreement
         );
   }


   //=================================================================
   void UpdateConfluenceState(AnalysisContext &c) const
   {
      if(c.evidenceQuality >= ASTRA_CONFLUENCE_VALID_QUALITY_DEFAULT)
         c.confluenceState = LAYER_VALID;
      else if(c.evidenceQuality >= ASTRA_CONFLUENCE_NEUTRAL_QUALITY_DEFAULT)
         c.confluenceState = LAYER_NEUTRAL;
      else
         c.confluenceState = LAYER_INVALID;
   }


   // EVIDENCE CONFLUENCE
   //=================================================================
   double CalculateEvidenceConfluence(
      const double bull,
      const double bear,
      const double evidenceQuality
   ) const
   {
      const double bullish = ClampPositive(bull);
      const double bearish = ClampPositive(bear);
      if((bullish + bearish) <= 0.0)
         return 0.0;

      // EvidenceQuality already contains Strength. The sign is taken from
      // the same bullish/bearish dominance only to orient the metric.
      const double sign =
         bullish > bearish ? 1.0 :
         bearish > bullish ? -1.0 :
         0.0;

      return ClampScore(
         sign * ClampConfidence(evidenceQuality) * 100.0
      );
   }



   //=================================================================
   // RAW CONFLUENCE
   //
   // Mede somente a relação entre força bullish e bearish.
   //
   // NÃO aplica:
   //   - MTF
   //   - Traffic
   //   - Range
   //   - BOS/CHOCH
   //   - Conflict
   //   - estrutura neutra
   //
   // Essas penalizações pertencem à confluence contextual e/ou
   // à ContextPenalty.
   //=================================================================
   double CalculateRawConfluence(
      const double bull,
      const double bear
   ) const
   {
      const double bullish = ClampPositive(bull);
      const double bearish = ClampPositive(bear);
      const double total = bullish + bearish;
      if(total <= 0.0)
         return 0.0;

      return ClampScore(
         ((bullish - bearish) / total) * 100.0
      );
   }





   //=================================================================
   // BASE CONFIDENCE
   //
   // A confiança base separa explicitamente:
   //   - Probability: dominância relativa do lado vencedor
   //   - EvidenceQuality: Strength x Coverage x Agreement
   //
   // Consensus e Confluence permanecem métricas de decisão/validação,
   // mas não são reutilizados aqui como proxies de qualidade.
   // Isso evita que uma direção com pouca cobertura pareça altamente
   // confiável apenas porque venceu quantitativamente.
   //
   // Penalizações contextuais entram posteriormente.
   //=================================================================
   double CalculateFinalConfidence(
      const double dominant,
      const double opposite,
      const double evidenceQuality
   ) const
   {
      const double dominantClamped = ClampPositive(dominant);
      const double oppositeClamped = ClampPositive(opposite);
      const double total = dominantClamped + oppositeClamped;

      double probability = 0.50;
      if(total > 0.0)
         probability = dominantClamped / total;

      const double quality =
         ClampConfidence(evidenceQuality);

      // 50% dominance + 50% evidence quality.
      // Context is applied exactly once after this stage.
      const double confidence =
         (probability * 0.50) +
         (quality * 0.50);

      return ClampConfidence(confidence);
   }



   //=================================================================
   // MÉTRICA DIRECIONAL
   //
   // Converte Consensus/Confluence para a perspectiva da decisão:
   //
   // BUY:
   //    valor positivo = favorável ao BUY
   //
   // SELL:
   //    valor positivo = favorável ao SELL
   //
   // NONE:
   //    não existe métrica direcional.
   //=================================================================
   double GetDirectionalMetric(
      const ENUM_DECISION decision,
      const double value
   ) const
   {
      if(decision == DECISION_BUY)
         return value;

      if(decision == DECISION_SELL)
         return -value;

      return 0.0;
   }


   //=================================================================
   // CONTEXT PENALTY
   //
   // Mantida determinística.
   //
   // IMPORTANTE:
   // A penalização contextual ocorre UMA VEZ sobre a confiança base.
   //=================================================================
 double CalculateContextPenalty(
   const AnalysisContext &c,
   const ENUM_DECISION decision
) const
{
   double penalty = 1.0;

   bool noStructureConfirmation =
      (c.structuralBias == BIAS_NEUTRAL);

   if(noStructureConfirmation)
      penalty *= 0.90;

   if(c.directionConflict)
      penalty *= 0.80;

   const bool mtfAlignedWithDecision =
      c.mtfCanonicalState == ASTRA_MTF_ALIGNED &&
      ((decision == DECISION_BUY && c.mtfCanonicalDirection == TRAFFIC_BULLISH) ||
       (decision == DECISION_SELL && c.mtfCanonicalDirection == TRAFFIC_BEARISH));

   if(c.mtfCanonicalState == ASTRA_MTF_CONFLICT ||
      (c.mtfCanonicalDirection != TRAFFIC_NONE && !mtfAlignedWithDecision))
      penalty *= 0.90;

   if(c.volumeDivergesFromTrend)
      penalty *= 0.90;

   if(c.regime == REGIME_RANGE && !c.bos && !c.choch)
      penalty *= 0.85;

   if(!c.bos && !c.choch &&
      c.structuralBias != BIAS_NEUTRAL)
   {
      penalty *= 0.90;
   }

   if(penalty < 0.35)
      penalty = 0.35;

   return ClampConfidence(penalty);
}
   // MEMPOOL CONTEXT GATE
   //
   // O Mempool só pode influenciar a confiança quando:
   //
   //   valid       = true
   //   connected   = true
   //   ready       = true
   //   stale       = false
   //
   // O Mempool NÃO determina direção.
   //=================================================================
   bool IsMempoolContextActive(
      const AnalysisContext &c
   ) const
   {
      if(!c.mempoolValid)
         return false;

      if(!c.mempoolConnected)
         return false;

      if(!c.mempoolAnalysisReady)
         return false;

      if(c.mempoolStale)
         return false;

      return true;
   }


   //=================================================================
   // MEMPOOL PRESSURE COMPONENT
   //
   // Converte Pressure Index 0..100 para intensidade 0..1.
   //=================================================================
   double CalculateMempoolPressureIntensity(
      const AnalysisContext &c
   ) const
   {
      if(c.mempoolPressureIndex <= 0.0)
         return 0.0;

      return ClampConfidence(
         c.mempoolPressureIndex /
         100.0
      );
   }


   //=================================================================
   // MEMPOOL ANOMALY COMPONENT
   //
   // AnomalyScore é tratado como intensidade contextual.
   //=================================================================
   double CalculateMempoolAnomalyIntensity(
      const AnalysisContext &c
   ) const
   {
      if(c.mempoolAnomalyScore <= 0.0)
         return 0.0;

      return ClampConfidence(
         c.mempoolAnomalyScore /
         100.0
      );
   }


   //=================================================================
   // MEMPOOL Z-SCORE COMPONENT
   //
   // Utilizamos magnitude do Z-Score e não sua direção.
   //
   // Motivo:
   // Z positivo/negativo não representa BUY/SELL por si só.
   //=================================================================
   double CalculateMempoolZIntensity(
      const AnalysisContext &c
   ) const
   {
      const double absoluteZ =
         MathAbs(
            c.mempoolZScore
         );

      if(absoluteZ <= 0.0)
         return 0.0;

      // 3 desvios = intensidade máxima.
      return ClampConfidence(
         absoluteZ /
         3.0
      );
   }


   //=================================================================
   // MEMPOOL PERCENTILE COMPONENT
   //
   // Valores extremos em ambas as pontas são tratados pela
   // distância de 50%.
   //=================================================================
   double CalculateMempoolPercentileIntensity(
      const AnalysisContext &c
   ) const
   {
      if(!c.mempoolPercentileAvailable)
         return 0.0;

      const double distance =
         MathAbs(
            c.mempoolPercentile -
            50.0
         );

      return ClampConfidence(
         distance /
         50.0
      );
   }


   //=================================================================
   // MEMPOOL DYNAMICS COMPONENT
   //
   // Utilizamos magnitude e não sinal.
   //
   // Momentum / Acceleration não são interpretados como direção
   // financeira do ativo.
   //=================================================================
   double CalculateMempoolDynamicsIntensity(
      const AnalysisContext &c
   ) const
   {
      const double momentum =
         MathMin(
            1.0,
            MathAbs(
               c.mempoolMomentum
            ) * 20.0
         );

      const double acceleration =
         MathMin(
            1.0,
            MathAbs(
               c.mempoolAcceleration
            ) * 20.0
         );

      return ClampConfidence(
         (
            momentum * 0.60
         )
         +
         (
            acceleration * 0.40
         )
      );
   }


   //=================================================================
   // MEMPOOL STATE COMPONENT
   //
   // O estado é somente contexto.
   //
   // NORMAL   = 0.00
   // ATENCAO  = 0.25
   // ALERTA   = 0.65
   // EXTREMO  = 1.00
   //
   // Outros estados não produzem contribuição.
   //=================================================================
   double CalculateMempoolStateIntensity(
      const AnalysisContext &c
   ) const
   {
      if(c.mempoolState == "EXTREMO")
         return 1.00;

      if(c.mempoolState == "ALERTA")
         return 0.65;

      if(c.mempoolState == "ATENCAO")
         return 0.25;

      if(c.mempoolState == "NORMAL")
         return 0.00;

      return 0.00;
   }


   //=================================================================
   // MEMPOOL CONTEXT INTENSITY
   //
   // Combina:
   //   Pressure
   //   Anomaly
   //   Z-Score
   //   Percentile
   //   Momentum / Acceleration
   //   State
   //
   // O resultado permanece em 0..1.
   //=================================================================
   double CalculateMempoolContextIntensity(
      const AnalysisContext &c
   ) const
   {
      if(
         !IsMempoolContextActive(
            c
         )
      )
      {
         return 0.0;
      }


      const double pressureIntensity =
         CalculateMempoolPressureIntensity(
            c
         );

      const double anomalyIntensity =
         CalculateMempoolAnomalyIntensity(
            c
         );

      const double zIntensity =
         CalculateMempoolZIntensity(
            c
         );

      const double percentileIntensity =
         CalculateMempoolPercentileIntensity(
            c
         );

      const double dynamicsIntensity =
         CalculateMempoolDynamicsIntensity(
            c
         );

      const double stateIntensity =
         CalculateMempoolStateIntensity(
            c
         );


      double intensity =
         (
            pressureIntensity * 0.25
         )
         +
         (
            anomalyIntensity * 0.25
         )
         +
         (
            zIntensity * 0.15
         )
         +
         (
            dynamicsIntensity * 0.10
         )
         +
         (
            stateIntensity * 0.10
         );

      if(c.mempoolPercentileAvailable)
         intensity += percentileIntensity * 0.15;


      return ClampConfidence(
         intensity
      );
   }


   //=================================================================
   // MEMPOOL CONTEXT MODIFIER
   //
   // O modifier é:
   //
   //   0.000 .. +0.050
   //
   // ou seja:
   //
   //   +0.0% .. +5.0%
   //
   // sobre a confiança já penalizada pelo contexto normal.
   //
   // O Mempool não cria uma decisão.
   // O Mempool não muda BUY para SELL.
   // O Mempool não muda SELL para BUY.
   //=================================================================
   double CalculateMempoolContextModifier(
      const AnalysisContext &c
   ) const
   {
      if(!IsMempoolContextActive(c))
         return 0.0;

      const double intensity =
         CalculateMempoolContextIntensity(
            c
         );


      // Limite institucional:
      // no máximo +5% de confiança.
      const double modifier =
         intensity * 0.05;


      return ClampConfidence(
         modifier
      );
   }


   //=================================================================
   // APPLY MEMPOOL MODIFIER
   //
   // Aplica somente após ContextPenalty.
   //=================================================================
   double ApplyMempoolContextModifier(
      const double adjustedConfidence,
      const double mempoolModifier
   ) const
   {
      const double base =
         ClampConfidence(
            adjustedConfidence
         );

      const double modifier =
         ClampConfidence(
            mempoolModifier
         );

      return ClampConfidence(
         base *
         (
            1.0 +
            modifier
         )
      );
   }


   bool IsBTCContextActive(
      const AnalysisContext &c
   ) const
   {
      if(!ASTRA_BTC_MODIFIER_ENABLED)
         return false;

      return (
         c.btcPrice.valid &&
         !c.btcPrice.stale &&
         c.btcQuantDataValid &&
         c.btcQuantScoreValid
      );
   }


   double CalculateBTCContextModifier(
      const AnalysisContext &c
   ) const
   {
      if(!IsBTCContextActive(c))
         return 0.0;

      const double modifier =
         ASTRA_BTC_MAX_MODIFIER *
         (c.btcQuantScore / 100.0);

      if(modifier < -ASTRA_BTC_MAX_MODIFIER)
         return -ASTRA_BTC_MAX_MODIFIER;

      if(modifier > ASTRA_BTC_MAX_MODIFIER)
         return ASTRA_BTC_MAX_MODIFIER;

      return modifier;
   }


   double ApplyBTCContextModifier(
      const double adjustedConfidence,
      const double btcModifier
   ) const
   {
      const double base =
         ClampConfidence(adjustedConfidence);

      return ClampConfidence(
         base * (1.0 + btcModifier)
      );
   }


   //=================================================================
   // GRADE
   //=================================================================
   ENUM_OPPORTUNITY_GRADE DetermineGrade(
      const double confidence,
      const double consensus,
      const double confluence,
      const bool directionConflict,
      const AnalysisContext &c,
      const ENUM_DECISION decision
   ) const
   {
      const double absConfidence =
         MathAbs(
            confidence
         );

      const double absConsensus =
         MathAbs(
            consensus
         );

      const double absConfluence =
         MathAbs(
            confluence
         );

      const bool mtfAlignedWithDecision =
         c.mtfCanonicalState == ASTRA_MTF_ALIGNED &&
         ((decision == DECISION_BUY && c.mtfCanonicalDirection == TRAFFIC_BULLISH) ||
          (decision == DECISION_SELL && c.mtfCanonicalDirection == TRAFFIC_BEARISH));


      //==============================================================
      // A+
      //==============================================================

      if(
         !directionConflict &&
         c.structuralBias != BIAS_NEUTRAL &&
         (c.bos || c.choch) &&
         mtfAlignedWithDecision &&
         c.regime == REGIME_EXPANSION &&
         absConfidence >= 0.85 &&
         absConsensus >= 80.0 &&
         absConfluence >= 80.0
      )
      {
         return GRADE_A_PLUS;
      }

      //==============================================================
      // A
      //==============================================================

      if(
         absConfidence >= 0.75 &&
         absConsensus >= 65.0 &&
         absConfluence >= 65.0
      )
      {
         if(
            directionConflict ||
            c.structuralBias == BIAS_NEUTRAL ||
            !mtfAlignedWithDecision ||
            (c.regime == REGIME_RANGE && !c.bos && !c.choch)
         )
         {
            return GRADE_B;
         }

         return GRADE_A;
      }


      //==============================================================
      // B
      //==============================================================

      if(
         absConfidence >= 0.65 &&
         absConsensus >= 50.0 &&
         absConfluence >= 50.0
      )
      {
         return GRADE_B;
      }


      //==============================================================
      // C
      //==============================================================

      if(
         absConfidence >= 0.55 &&
         absConsensus >= 35.0 &&
         absConfluence >= 35.0
      )
      {
         return GRADE_C;
      }


      return GRADE_NO_TRADE;
   }


   //=================================================================
   // WAIT
   //=================================================================
   void SetWait(
      AnalysisContext &c,
      const string reason,
      const string code
   )
   {
      c.decision =
         DECISION_NONE;

      c.decisionBias =
         BIAS_NEUTRAL;

      c.finalConfidence =
         0.0;

      c.decisionApproved =
         false;

      c.riskApproved =
         false;

      c.tradeValidationPassed =
         false;

      c.executionAllowed =
         false;

      c.executionConfirmed =
         false;

      c.orderSent =
         false;

      c.opportunityGrade =
         GRADE_NO_TRADE;

      m_reason =
         reason;

      c.pipelineStage =
         "DECISION";

      c.rejectStage =
         "MARKET_DECISION";

      c.rejectReason =
         code;

      c.executionRejection =
         reason;

      c.executionMessage =
         reason;

      c.decisionReason =
         reason;

      c.decisionExplanation =
         reason;

      m_status =
         "WAIT";
   }


   //=================================================================
   // SET DECISION
   //=================================================================
   void SetDecision(
      AnalysisContext &c,
      const ENUM_DECISION decision,
      const double confidence
   )
   {
      c.decision =
         decision;

      c.decisionBias =
         (
            decision == DECISION_BUY
            ? BIAS_BULLISH
            : BIAS_BEARISH
         );

      c.finalConfidence =
         ClampConfidence(
            confidence
         );

      // MarketDecision NÃO aprova execução.
      c.decisionApproved =
         false;

      c.riskApproved =
         false;

      c.tradeValidationPassed =
         false;

      c.executionAllowed =
         false;

      c.executionConfirmed =
         false;

      c.orderSent =
         false;

      m_status =
         (
            decision == DECISION_BUY
            ? "BUY_SIGNAL"
            : "SELL_SIGNAL"
         );
   }


   //=================================================================
   // DETECT CONFLICT
   //=================================================================
   bool DetectDirectionConflict(
      const AnalysisContext &c
   ) const
   {
      const bool oppositeStructureTraffic =
         (
            (
               c.structuralBias == BIAS_BULLISH &&
               c.trafficDirection == TRAFFIC_BEARISH
            )
            ||
            (
               c.structuralBias == BIAS_BEARISH &&
               c.trafficDirection == TRAFFIC_BULLISH
            )
         );


      const double trafficTotal =
         c.trafficBullishScore +
         c.trafficBearishScore;

      double trafficBalance =
         1.0;

      if(trafficTotal > 0.0)
      {
         trafficBalance =
            MathAbs(
               c.trafficBullishScore -
               c.trafficBearishScore
            ) / trafficTotal;
      }

      // Conflict exige evidencia realmente equilibrada.
      // Dois lados com score > 0 não representam conflito por si só.
      // O conflito de tráfego só é ativado quando:
      //   1) o MTF não está alinhado;
      //   2) não existe direção agregada;
      //   3) os scores estão suficientemente próximos.
      // Mixed traffic is uncertainty, not an explicit direction conflict.
      // Keep it available to ContextPenalty through trafficMTF/light state,
      // but reserve directionConflict for a real structure-vs-traffic clash.
      // This prevents mixed traffic from triggering the strong x0.80 penalty.
      //
      // Structure neutral indicates lack of confirmation, not conflict.
      // The penalty for missing structure is applied separately.
      return oppositeStructureTraffic;
   }


public:

   //=================================================================
   // CONSTRUCTOR
   //=================================================================
   MarketDecisionEngine()
   {
      ResetInternal();

      m_status =
         "INITIALIZED";
   }


   //=================================================================
   // RESET
   //=================================================================
   void Reset()
   {
      ResetInternal();

      m_status =
         "READY";
   }


   //=================================================================
   // STATUS
   //=================================================================
   string GetStatus() const
   {
      return m_status;
   }


   //=================================================================
   // REASON
   //=================================================================
   string GetReason() const
   {
      return m_reason;
   }


   //=================================================================
   // ANALYZE
   //=================================================================
   bool Analyze(
      AnalysisContext &c
   )
   {
      ResetInternal();


      //==============================================================
      // RESET
      //==============================================================

      c.pipelineStage =
         "DECISION";

      c.rejectStage =
         "";

      c.rejectReason =
         "";

      c.executionRejection =
         "";

      c.executionMessage =
         "";

      c.directionConflict =
         false;

      c.decisionBias =
         BIAS_NEUTRAL;

      c.decision =
         DECISION_NONE;

      c.finalConfidence =
         0.0;

      c.consensusScore =
         0.0;

      c.confluenceScore =
         0.0;

      c.buyScore =
         0.0;

      c.sellScore =
         0.0;

      c.bullishConfluence =
         0.0;

      c.bearishConfluence =
         0.0;

      c.bullishFactors =
         0;

      c.bearishFactors =
         0;

      c.probabilityBuy =
         0.50;

      c.probabilitySell =
         0.50;

      c.decisionApproved =
         false;

      c.riskApproved =
         false;

      c.tradeValidationPassed =
         false;

      c.executionAllowed =
         false;

      c.executionConfirmed =
         false;

      c.orderSent =
         false;

      c.opportunityGrade =
         GRADE_NO_TRADE;


      //==============================================================
      // CONTEXT
      //==============================================================

      if(!c.Validate())
      {
         SetWait(
            c,
            "AnalysisContext inválido.",
            "INVALID_CONTEXT"
         );

         return false;
      }


      //==============================================================
      // REGIME CONTEXT FILTER
      //
      // RANGE não bloqueia automaticamente a análise.
      //
      // O regime passa a atuar como:
      //   - penalização de confluence
      //   - penalização de confidence
      //   - critério de grade
      //
      // O motor deve continuar calculando a direção para que os
      // próximos gates determinem se existe ou não oportunidade.
      //==============================================================

      const bool lowVolatilityRange =
         (
            c.regime == REGIME_RANGE &&
            c.volatilityScore < 20.0
         );

      if(lowVolatilityRange)
      {
         PrintFormat(
            "[MarketDecisionEngine][Cycle=%I64u] "
            "REGIME_CONTEXT | Regime=%s | VolatilityScore=%.2f | "
            "Mode=SOFT_FILTER",
            c.cycleId,
            c.RegimeToString(),
            c.volatilityScore
         );
      }


      //==============================================================
      // SCORES RAW
      //==============================================================

      double bull =
         0.0;

      double bear =
         0.0;


      //==============================================================
      // STRUCTURE
      //==============================================================

      AddStructuralContribution(
         c,
         bull,
         bear
      );
      // Evidência derivada de fechamento, localização e volume.
      AddContribution(
         c.knowledgeScore,
         bull,
         bear
      );


      //==============================================================
      // LIQUIDITY
      //==============================================================

      AddMagnitudeContribution(
         c.liquidityScore,
         c.sellSideLiquidityTaken,
         c.buySideLiquidityTaken,
         bull,
         bear
      );


      //==============================================================
      // SMART MONEY / ORDER BLOCK / FVG / MITIGATION
      //==============================================================
      // TRACE_ONLY / UNUSED_DECISIONALLY. These are correlated
      // confirmations of Structure/Liquidity and do not affect BUY/SELL.
      // Keep them diagnostic rather than letting them inflate directional
      // strength or consensus as if they were independent families.
      c.confirmationBullScore = 0.0;
      c.confirmationBearScore = 0.0;

      if(c.smartMoneyScore > 0.0)
         c.confirmationBullScore += MathMin(c.smartMoneyScore, 20.0);
      else if(c.smartMoneyScore < 0.0)
         c.confirmationBearScore += MathMin(MathAbs(c.smartMoneyScore), 20.0);

      if(c.orderBlock && c.orderBlockValid)
      {
         if(c.bullishFVG)
            c.confirmationBullScore += 10.0;
         else if(c.bearishFVG)
            c.confirmationBearScore += 10.0;
      }

      if(c.fairValueGap && c.bullishFVG)
         c.confirmationBullScore += 10.0;
      else if(c.fairValueGap && c.bearishFVG)
         c.confirmationBearScore += 10.0;

      if(c.mitigation)
      {
         if(c.structuralBias == BIAS_BULLISH)
            c.confirmationBullScore += 5.0;
         else if(c.structuralBias == BIAS_BEARISH)
            c.confirmationBearScore += 5.0;
      }


      //==============================================================
      // WYCKOFF
      //==============================================================

      AddMagnitudeContribution(
         c.wyckoffScore,
         c.springDetected || c.sosDetected,
         c.upthrustDetected || c.sowDetected,
         bull,
         bear
      );

      if(c.springDetected)
         bull += 10.0;

      if(c.upthrustDetected)
         bear += 10.0;


      //==============================================================
      // ELLIOTT (CONFIRMATION ONLY)
      //==============================================================

      if(c.waveCDetected)
      {
         if(c.structuralBias == BIAS_BULLISH)
            c.confirmationBullScore += 5.0;
         else if(c.structuralBias == BIAS_BEARISH)
            c.confirmationBearScore += 5.0;
      }


      //==============================================================
      // REGIME EXPANSION
      //==============================================================

      if(c.regime == REGIME_EXPANSION)
      {
         const double trendContribution =
            MathMax(
               0.0,
               c.trendStrength
            ) * 0.10;

         if(c.structuralBias == BIAS_BULLISH)
         {
            bull +=
               trendContribution;
         }
         else
         if(c.structuralBias == BIAS_BEARISH)
         {
            bear +=
               trendContribution;
         }
      }


      //==============================================================
      // TRANSITION
      //==============================================================

      if(c.regime == REGIME_TRANSITION)
      {
         bull *= 0.90;
         bear *= 0.90;
      }


      //==============================================================
      // MTF / TIMEFRAME
      //==============================================================
      // TrafficLightEngine already aggregates D1/H4/H1/M15/M5.
      // No second independent MTF contribution is added here.


      //==============================================================
      // PATTERN
      //==============================================================

      // patternScore is the signed net of the pattern-family scores;
      // detected flags classify that same evidence, not a second bonus.
      AddContribution(
         c.patternScore,
         bull,
         bear
      );


      //==============================================================
      // MOMENTUM
      //==============================================================

      AddContribution(
         c.momentumScore,
         bull,
         bear
      );

      //==============================================================
      // VOLATILITY
      //==============================================================

      if(c.volatilityExpanding)
      {
         if(bull > bear)
            bull += 3.0;
         else
         if(bear > bull)
            bear += 3.0;
      }


      //==============================================================
      // VOLUME
      //==============================================================

      if(c.volumeProfileEnabled)
      {
         AddContribution(
            c.volumeDirectionalScore,
            bull,
            bear
         );
      }


      //==============================================================
      // TECHNICAL INTELLIGENCE
      //==============================================================


      //==============================================================
      // AI STRUCTURE
      //==============================================================


      //==============================================================
      // TRAFFIC
      //==============================================================

      if(
         c.mtfCanonicalDirection == TRAFFIC_BULLISH &&
         c.trafficLightScore > 0.0
      )
      {
         bull +=
            c.trafficLightScore *
            0.30;
      }
      else
      if(
         c.mtfCanonicalDirection == TRAFFIC_BEARISH &&
         c.trafficLightScore > 0.0
      )
      {
         bear +=
            c.trafficLightScore *
            0.30;
      }


      //==============================================================
      // CLAMP RAW
      //==============================================================

      bull =
         ClampPositive(
            bull
         );

      bear =
         ClampPositive(
            bear
         );


      c.decisionCoreBullScore = bull;
      c.decisionCoreBearScore = bear;

      c.buyScore =
         bull;

      c.sellScore =
         bear;


      //==============================================================
      // CONFLUENCE COMPONENTS
      //
      // Mantemos os componentes brutos da confluence no Context.
      // Isso permite ao SignalValidator verificar posteriormente
      // qual direção possui maior força.
      //=================================================================

      c.bullishConfluence =
         ClampPositive(
            bull
         );

      c.bearishConfluence =
         ClampPositive(
            bear
         );


      //==============================================================
      // CONFLICT
      //==============================================================

      c.directionConflict =
         DetectDirectionConflict(
            c
         );


      //==============================================================
      // FACTORS
      //==============================================================

      // FactorCounts are TRACE / NON-GATING; they do not control approval.
      int neutralFactors =
         0;

      CalculateFactorCounts(
         c,
         c.bullishFactors,
         c.bearishFactors,
         neutralFactors
      );


       //==============================================================
       // FACTOR TRACE
       //==============================================================
       PrintFormat(
          "[MarketDecisionEngine][Cycle=%I64u] FACTORS | "
          "Structure=%s | Liquidity=%s | SmartMoney=%s | "
          "Wyckoff=%s | Elliott=NEUTRAL | Timeframe=NEUTRAL | Pattern=%s | "
          "Momentum=%s | Volume=%s | TechnicalIntelligence=NEUTRAL | "
          "TrafficDirection=%s | TrafficBias=%s | CanonicalMTF=%s | CanonicalDirection=%s",
          c.cycleId,
          c.structuralBias == BIAS_BULLISH ? "BULL" : (c.structuralBias == BIAS_BEARISH ? "BEAR" : "NEUTRAL"),
          c.sellSideLiquidityTaken && !c.buySideLiquidityTaken ? "BULL" : (c.buySideLiquidityTaken && !c.sellSideLiquidityTaken ? "BEAR" : "NEUTRAL"),
          c.smartMoneyScore > 0.0 ? "BULL" : (c.smartMoneyScore < 0.0 ? "BEAR" : "NEUTRAL"),
          (c.springDetected || c.sosDetected) && !(c.upthrustDetected || c.sowDetected) ? "BULL" : ((c.upthrustDetected || c.sowDetected) && !(c.springDetected || c.sosDetected) ? "BEAR" : "NEUTRAL"),
          c.patternScore > 0.0 ? "BULL" : (c.patternScore < 0.0 ? "BEAR" : "NEUTRAL"),
          c.momentumScore > 0.0 ? "BULL" : (c.momentumScore < 0.0 ? "BEAR" : "NEUTRAL"),
          c.volumeDirectionalScore > 0.0 ? "BULL" : (c.volumeDirectionalScore < 0.0 ? "BEAR" : "NEUTRAL"),
          c.trafficDirection == TRAFFIC_BULLISH ? "BULL" : (c.trafficDirection == TRAFFIC_BEARISH ? "BEAR" : "NEUTRAL"),
          c.trafficBullishScore > c.trafficBearishScore ? "BULL" : (c.trafficBearishScore > c.trafficBullishScore ? "BEAR" : "NEUTRAL"),
          EnumToString(c.mtfCanonicalState),
          EnumToString(c.mtfCanonicalDirection)
       );


      //==============================================================
      // METRICS
      //==============================================================

      c.consensusScore =
         CalculateConsensus(c);



      CalculateProbabilities(
         bull,
         bear,
         c.probabilityBuy,
         c.probabilitySell
      );


      // RAW trace emitted after direction/evidence metrics are computed.
      //==============================================================
      // MEMPOOL GATE TRACE
      //
      // O Gate é avaliado aqui para auditoria.
      // O modifier só será aplicado depois que uma direção válida
      // tiver sido determinada.
      //==============================================================

      const bool mempoolContextActive =
         IsMempoolContextActive(
         c
         );


      const double mempoolContextIntensity =
         mempoolContextActive
         ? CalculateMempoolContextIntensity(
              c
           )
         : 0.0;


      const double mempoolContextModifier =
         mempoolContextActive
         ? CalculateMempoolContextModifier(
              c
           )
         : 0.0;


      PrintFormat(
         "[MarketDecisionEngine][Cycle=%I64u] "
         "MEMPOOL | Active=%s | "
         "Valid=%s | Connected=%s | Ready=%s | Stale=%s | "
         "Pressure=%.2f | State=%s | Z=%.4f | "
         "Percentile=%.2f | Momentum=%.6f | "
         "Acceleration=%.6f | Age=%d | "
         "Intensity=%.4f | Modifier=%.4f",
         c.cycleId,
         mempoolContextActive ? "true" : "false",
         c.mempoolValid ? "true" : "false",
         c.mempoolConnected ? "true" : "false",
         c.mempoolAnalysisReady ? "true" : "false",
         c.mempoolStale ? "true" : "false",
         c.mempoolPressureIndex,
         c.mempoolState,
         c.mempoolZScore,
         c.mempoolPercentile,
         c.mempoolMomentum,
         c.mempoolAcceleration,
         c.mempoolAgeSeconds,
         mempoolContextIntensity,
         mempoolContextModifier
      );


      //==============================================================
      // DOMINANCE
      //==============================================================

      const bool bullDom =
         bull > bear;

      const bool bearDom =
         bear > bull;


      if(
         !bullDom &&
         !bearDom
      )
      {
         SetWait(
            c,
            "Equilíbrio entre forças bullish e bearish.",
            "NO_DIRECTION"
         );

         return true;
      }


      //==============================================================
      // DIRECTION
      //==============================================================

      ENUM_DECISION candidateDecision =
         bullDom
         ? DECISION_BUY
         : DECISION_SELL;


      //==============================================================
      // EVIDENCE QUALITY
      //==============================================================

      CalculateEvidenceQuality(
         c,
         bull,
         bear,
         candidateDecision,
         c.evidenceStrength,
         c.evidenceCoverage,
         c.evidenceAgreement,
         c.evidenceQuality,
         c.evidenceEligibleWeight,
         c.evidenceActiveWeight,
         c.evidenceAlignedWeight,
         c.evidenceOpposingWeight
      );

      const bool traceWyckoffBullish =
         c.springDetected || c.sosDetected;
      const bool traceWyckoffBearish =
         c.upthrustDetected || c.sowDetected;

      //==============================================================
      // EVIDENCE FAMILY TRACE
      //==============================================================
      // Keep the trace explicit so the backtest can distinguish:
      //   - raw engine availability
      //   - active directional evidence
      //   - alignment/opposition to the candidate
      // without inferring these values from FactorCount.
      PrintFormat(
         "[MarketDecisionEngine][Cycle=%I64u] EVIDENCE | "
         "Structure[state=%s,w=2.00,active=%s] | "
         "Momentum[state=%s,w=1.25,active=%s] | "
         "Volume[state=%s,w=1.25,active=%s] | "
         "Traffic[dir=%s,bias=%s,light=%s,mtf=%s,active=%s] | "
         "Liquidity[event=%s,w=0.75,active=%s] | "
         "Wyckoff[event=%s,w=0.75,active=%s] | "
         "Pattern[state=%s,w=0.75,active=%s] | "
         "Totals[eligible=%.2f,active=%.2f,aligned=%.2f,opposing=%.2f]",
         c.cycleId,
         c.structuralBias == BIAS_BULLISH ? "BULL" : (c.structuralBias == BIAS_BEARISH ? "BEAR" : "NEUTRAL"),
         (c.structuralBias != BIAS_NEUTRAL && (c.structuralScore != 0.0 || c.bos || c.choch)) ? "true" : "false",
         c.momentumScore > 0.0 ? "BULL" : (c.momentumScore < 0.0 ? "BEAR" : "NEUTRAL"),
         c.momentumScore != 0.0 ? "true" : "false",
         c.volumeDirectionalScore > 0.0 ? "BULL" : (c.volumeDirectionalScore < 0.0 ? "BEAR" : "NEUTRAL"),
         c.volumeDirectionalScore != 0.0 ? "true" : "false",
         EnumToString(c.trafficDirection),
         c.trafficBullishScore > c.trafficBearishScore ? "BULL" : (c.trafficBearishScore > c.trafficBullishScore ? "BEAR" : "NEUTRAL"),
         EnumToString(c.trafficLight),
         c.trafficMTFAligned ? "true" : "false",
         c.trafficDirection != TRAFFIC_NONE ? "true" : "false",
         c.sellSideLiquidityTaken && !c.buySideLiquidityTaken ? "SELL_SIDE_TAKEN" : (c.buySideLiquidityTaken && !c.sellSideLiquidityTaken ? "BUY_SIDE_TAKEN" : "NONE"),
         (c.sellSideLiquidityTaken != c.buySideLiquidityTaken) ? "true" : "false",
         traceWyckoffBullish && !traceWyckoffBearish ? "BULL_EVENT" : (traceWyckoffBearish && !traceWyckoffBullish ? "BEAR_EVENT" : "NONE"),
         (traceWyckoffBullish != traceWyckoffBearish) ? "true" : "false",
         c.patternScore > 0.0 ? "BULL" : (c.patternScore < 0.0 ? "BEAR" : "NEUTRAL"),
         (c.patternScore != 0.0 || c.bullishPatternDetected || c.bearishPatternDetected) ? "true" : "false",
         c.evidenceEligibleWeight,
         c.evidenceActiveWeight,
         c.evidenceAlignedWeight,
         c.evidenceOpposingWeight
      );

      c.confluenceScore =
         CalculateEvidenceConfluence(
            bull,
            bear,
            c.evidenceQuality
         );

      UpdateConfluenceState(c);

      //==============================================================
      // TRACE RAW
      //==============================================================

      PrintFormat(
         "[MarketDecisionEngine][Cycle=%I64u] "
         "RAW | Bullish=%.2f | Bearish=%.2f | "
         "BullFactors=%d | BearFactors=%d | NeutralFactors=%d | "
         "Consensus=%.2f | Confluence=%.2f | "
         "BullishConfluence=%.2f | BearishConfluence=%.2f | "
         "KnowledgeScore=%.2f | "
         "EvidenceStrength=%.3f | EvidenceCoverage=%.3f | "
         "EvidenceAgreement=%.3f | EvidenceQuality=%.3f | "
         "Structure=%s | BOS=%s | CHOCH=%s | "
         "Regime=%s | Traffic=%s | MTFAligned=%s | Conflict=%s",
         c.cycleId,
         bull,
         bear,
         c.bullishFactors,
         c.bearishFactors,
         neutralFactors,
         c.consensusScore,
         c.confluenceScore,
         c.bullishConfluence,
         c.bearishConfluence,
         c.knowledgeScore,
         c.evidenceStrength,
         c.evidenceCoverage,
         c.evidenceAgreement,
         c.evidenceQuality,
         EnumToString(c.structuralBias),
         c.bos ? "true" : "false",
         c.choch ? "true" : "false",
         c.RegimeToString(),
         EnumToString(c.trafficLight),
         c.trafficMTFAligned ? "true" : "false",
         c.directionConflict ? "true" : "false"
      );





      //==============================================================
      // MÉTRICAS DIRECIONAIS
      //
      // Aqui utilizamos a confluence de qualidade de evidência para o gate.
      //==============================================================

      const double directionalConsensus =
         GetDirectionalMetric(
            candidateDecision,
            c.consensusScore
         );

      const double directionalConfluence =
         GetDirectionalMetric(
            candidateDecision,
            c.confluenceScore
         );

      // Raw confluence is a diagnostic view of the bullish/bearish
      // dominance before the evidence-quality transformation.
      // Keep it local to the decision cycle so the BUY/SELL explanation
      // uses the same value that is actually defined by the current
      // bullish and bearish scores.
      const double rawConfluenceScore =
         CalculateRawConfluence(
            bull,
            bear
         );


      //==============================================================
      // DIRECTION CONSISTENCY GATE - CONSENSUS
      //
      // O candidato bruto (bull > bear / bear > bull) não pode
      // continuar quando o Consensus forte aponta explicitamente
      // para a direção oposta. Isso evita produzir um BUY que será
      // inevitavelmente rejeitado pelos gates posteriores por
      // Consensus/Traffic contraditórios.
      //
      // O threshold mínimo pertence ao SignalValidator.
      // MarketDecision rejeita apenas contradição direcional explícita.
      //==============================================================

      if(directionalConsensus <= 0.0)
      {
         SetWait(
            c,
            StringFormat(
               "Evidência agregada não confirma a direção candidata: %.2f",
               directionalConsensus
            ),
            "DIRECTION_CONSENSUS_CONFLICT"
         );

         return true;
      }


      //==============================================================
      // CONFLUENCE THRESHOLD
      //==============================================================
      // SignalValidator owns the minimum confluence threshold.
      // MarketDecision only guarantees directional consistency here.




      //==============================================================
      // BASE CONFIDENCE
      //==============================================================
      // EvidenceQuality já incorpora Strength, Coverage e Agreement.
      // Não reutilizamos Confluence aqui, evitando dupla contagem.
      //==============================================================

      const double originalConfidence =
         CalculateFinalConfidence(
            candidateDecision == DECISION_BUY
            ? bull
            : bear,

            candidateDecision == DECISION_BUY
            ? bear
            : bull,

            c.evidenceQuality
         );


      //==============================================================
      // CONTEXT PENALTY
      //==============================================================

      const double contextualPenalty =
         CalculateContextPenalty(
            c,
            candidateDecision
         );


      double consensusReduction = 0.0;
      if(directionalConsensus >= 25.0 && directionalConsensus < 50.0)
         consensusReduction = 0.10 * (50.0 - directionalConsensus) / 25.0;

      const double consensusAdjustedConfidence =
         originalConfidence * (1.0 - consensusReduction);

      const double contextAdjustedConfidence =
         ClampConfidence(
            consensusAdjustedConfidence *
            contextualPenalty
         );

      const bool btcContextActive =
         IsBTCContextActive(c);

      const double btcConfidenceModifier =
         CalculateBTCContextModifier(c);

      c.btcModifierActive =
         btcContextActive;

      c.btcConfidenceModifier =
         btcConfidenceModifier;

      c.btcModifierApplied =
         btcContextActive;


      //==============================================================
      // MEMPOOL CONTEXT MODIFIER
      //
      // Só entra depois da penalização contextual padrão.
      //
      // Isso preserva:
      //
      //   RawConfidence
      //        ↓
      //   ContextPenalty
      //        ↓
      //   MempoolModifier
      //        ↓
      //   FinalConfidence
      //
      // O Mempool não altera direção.
      //==============================================================

      const double mempoolAdjustedConfidence =
         ApplyMempoolContextModifier(
            contextAdjustedConfidence,
            mempoolContextModifier
         );

      const double finalConfidence =
         ApplyBTCContextModifier(
            mempoolAdjustedConfidence,
            btcConfidenceModifier
         );


      //==============================================================
      // TRACE PENALTY + MEMPOOL
      //==============================================================

      PrintFormat(
         "[MarketDecisionEngine][Cycle=%I64u] "
         "CONFIDENCE | Raw=%.3f | ContextPenalty=%.3f | "
         "ContextAdjusted=%.3f | MempoolActive=%s | "
         "MempoolModifier=%.4f | Final=%.3f | "
         "BTCActive=%s | BTCScore=%.2f | BTCModifier=%.4f | "
         "DirectionalConsensus=%.2f | "
         "EvidenceQuality=%.3f | "
         "EvidenceConfluence=%.2f | ConsensusReduction=%.3f | "
         "ConsensusAdjusted=%.3f",
         c.cycleId,
         originalConfidence,
         contextualPenalty,
         contextAdjustedConfidence,
         mempoolContextActive ? "true" : "false",
         mempoolContextModifier,
         finalConfidence,
         btcContextActive ? "true" : "false",
         c.btcQuantScore,
         btcConfidenceModifier,
         directionalConsensus,
         c.evidenceQuality,
         directionalConfluence,
         consensusReduction,
         consensusAdjustedConfidence
      );

      PrintFormat(
         "[ASTRA][BTC_MODIFIER] "
         "Context=%s | Score=%.2f | Modifier=%.4f | Applied=%s",
         c.btcRegime,
         c.btcQuantScore,
         btcConfidenceModifier,
         c.btcModifierApplied ? "true" : "false"
      );


      //==============================================================
      // GRADE
      //==============================================================

      const ENUM_OPPORTUNITY_GRADE grade =
         DetermineGrade(
            finalConfidence,
            directionalConsensus,
            directionalConfluence,
            c.directionConflict,
            c,
            candidateDecision
         );


      //==============================================================
      // FINAL DECISION
      //==============================================================

      SetDecision(
         c,
         candidateDecision,
         finalConfidence
      );


      c.opportunityGrade =
         grade;


      //==============================================================
      // BUY
      //==============================================================

      if(candidateDecision == DECISION_BUY)
      {
         c.decisionReason =
            c.directionConflict
            ? "BUY dominante com penalização contextual."
            : "BUY dominante pelas evidências disponíveis.";


         c.decisionExplanation =
            StringFormat(
               "RawBull=%.2f | RawBear=%.2f | "
               "Consensus=%.2f | "
               "RawConfluence=%.2f | "
               "EvidenceConfluence=%.2f | "
               "ProbBUY=%.3f | ProbSELL=%.3f | "
               "RawConfidence=%.3f | ContextPenalty=%.3f | "
               "ContextAdjusted=%.3f | "
               "MempoolActive=%s | "
               "MempoolModifier=%.4f | "
               "FinalConfidence=%.3f | "
               "Structure=%s | "
               "BOS=%s | CHOCH=%s | Regime=%s | "
               "Traffic=%s | MTFAligned=%s | Conflict=%s | "
               "Grade=%s",
               bull,
               bear,
               c.consensusScore,
               rawConfluenceScore,
               c.confluenceScore,
               c.probabilityBuy,
               c.probabilitySell,
               originalConfidence,
               contextualPenalty,
               contextAdjustedConfidence,
               mempoolContextActive ? "true" : "false",
               mempoolContextModifier,
               c.finalConfidence,
               EnumToString(c.structuralBias),
               c.bos ? "true" : "false",
               c.choch ? "true" : "false",
               c.RegimeToString(),
               EnumToString(c.trafficLight),
               c.trafficMTFAligned ? "true" : "false",
               c.directionConflict ? "true" : "false",
               c.GradeToString()
            );


         m_reason =
            c.decisionReason;

         m_status =
            "BUY_SIGNAL";

         return true;
      }


      //==============================================================
      // SELL
      //==============================================================

      if(candidateDecision == DECISION_SELL)
      {
         c.decisionReason =
            c.directionConflict
            ? "SELL dominante com penalização contextual."
            : "SELL dominante pelas evidências disponíveis.";


         c.decisionExplanation =
            StringFormat(
               "RawBull=%.2f | RawBear=%.2f | "
               "Consensus=%.2f | "
               "RawConfluence=%.2f | "
               "EvidenceConfluence=%.2f | "
               "ProbBUY=%.3f | ProbSELL=%.3f | "
               "RawConfidence=%.3f | ContextPenalty=%.3f | "
               "ContextAdjusted=%.3f | "
               "MempoolActive=%s | "
               "MempoolModifier=%.4f | "
               "FinalConfidence=%.3f | "
               "Structure=%s | "
               "BOS=%s | CHOCH=%s | Regime=%s | "
               "Traffic=%s | MTFAligned=%s | Conflict=%s | "
               "Grade=%s",
               bull,
               bear,
               c.consensusScore,
               rawConfluenceScore,
               c.confluenceScore,
               c.probabilityBuy,
               c.probabilitySell,
               originalConfidence,
               contextualPenalty,
               contextAdjustedConfidence,
               mempoolContextActive ? "true" : "false",
               mempoolContextModifier,
               c.finalConfidence,
               EnumToString(c.structuralBias),
               c.bos ? "true" : "false",
               c.choch ? "true" : "false",
               c.RegimeToString(),
               EnumToString(c.trafficLight),
               c.trafficMTFAligned ? "true" : "false",
               c.directionConflict ? "true" : "false",
               c.GradeToString()
            );


         m_reason =
            c.decisionReason;

         m_status =
            "SELL_SIGNAL";

         return true;
      }


      //==============================================================
      // FALLBACK
      //==============================================================

      SetWait(
         c,
         "Nenhuma direção dominante.",
         "NO_DIRECTION"
      );

      return true;
   }
};

#endif // ASTRA_MARKETDECISIONENGINE_MQH
