#ifndef ASTRA_MARKETSTRUCTUREENGINE_MQH
#define ASTRA_MARKETSTRUCTUREENGINE_MQH

#property strict

#include <AstraTrader\Analysis\AnalysisContext.mqh>

//+------------------------------------------------------------------+
//| MarketStructureEngine                                            |
//| Astra Trader AI                                                  |
//|                                                                  |
//| CAMADA 2 - MARKET STRUCTURE                                      |
//|                                                                  |
//| Responsabilidade:                                                |
//| - consumir exclusivamente o AnalysisContext                      |
//| - analisar HH / HL / LH / LL                                    |
//| - identificar estrutura bullish / bearish / neutral              |
//| - identificar BOS                                                |
//| - identificar CHOCH                                              |
//| - calcular score estrutural                                      |
//| - atualizar exclusivamente os campos da camada Structure         |
//|                                                                  |
//| IMPORTANTE:                                                       |
//| - NAO executa CopyRates()                                        |
//| - NAO executa SymbolSelect()                                     |
//| - NAO acessa dados externos do mercado                           |
//| - NAO modifica Decision, Risk ou Execution                        |
//| - utiliza exclusivamente context.marketBars[]                    |
//+------------------------------------------------------------------+
class MarketStructureEngine
{
private:

//=================================================================
// CONFIGURAÇÃO
//=================================================================

int    m_fractalDepth;
double m_breakTolerancePoints;
double m_minStructureScore;

//=================================================================
// NORMALIZA PREÇO
//=================================================================

double NormalizePrice(
const AnalysisContext &context,
const double value
) const
{
if(value <= 0.0)
return 0.0;

  if(context.digits < 0)
     return value;

  return NormalizeDouble(
     value,
     context.digits
  );
 }

//=================================================================
// LIMPA SOMENTE MARKET STRUCTURE
//=================================================================

void ResetStructure(
AnalysisContext &context
) const
{
context.structuralBias =
BIAS_NEUTRAL;

  context.bos =
     false;

  context.choch =
     false;

  context.higherHigh =
     false;

  context.higherLow =
     false;

  context.lowerHigh =
     false;

  context.lowerLow =
     false;

  context.structuralScore =
     0.0;

  context.lastSwingHighPrice =
     0.0;

  context.lastSwingHighTime =
     0;

  context.lastSwingLowPrice =
     0.0;

  context.lastSwingLowTime =
     0;

  context.structureState =
     LAYER_NEUTRAL;
 }

//=================================================================
// VALIDA CONTEXTO
//=================================================================

bool ValidateContext(
const AnalysisContext &context
) const
{
if(context.symbol == "")
return false;

  if(context.primaryTF == PERIOD_CURRENT)
     return false;

  if(!context.marketDataReady)
     return false;

  if(!context.marketHistoryReady)
     return false;

  if(context.marketBarsCount < 3)
     return false;

  if(ArraySize(context.marketBars) < 3)
     return false;

  return true;
 }

//=================================================================
// VALIDA BARRA
//=================================================================

bool IsValidBar(
const MqlRates &bar
) const
{
if(bar.time <= 0)
return false;

  if(bar.open <= 0.0)
     return false;

  if(bar.high <= 0.0)
     return false;

  if(bar.low <= 0.0)
     return false;

  if(bar.close <= 0.0)
     return false;

  if(bar.high < bar.low)
     return false;

  if(bar.high < bar.open)
     return false;

  if(bar.high < bar.close)
     return false;

  if(bar.low > bar.open)
     return false;

  if(bar.low > bar.close)
     return false;

  return true;
 }

//=================================================================
// ENCONTRA FRACTAL DE ALTA
//=================================================================

bool IsSwingHigh(
const MqlRates &bars[],
const int count,
const int index
) const
{
int depth =
m_fractalDepth;

  if(depth < 1)
     depth = 1;

  if(index < depth)
     return false;

  if(index + depth >= count)
     return false;

  double center =
     bars[index].high;

  if(center <= 0.0)
     return false;

  for(int i = 1; i <= depth; i++)
    {
     if(center <= bars[index - i].high)
        return false;

     if(center <= bars[index + i].high)
        return false;
    }

  return true;
 }

//=================================================================
// ENCONTRA FRACTAL DE BAIXA
//=================================================================

bool IsSwingLow(
const MqlRates &bars[],
const int count,
const int index
) const
{
int depth =
m_fractalDepth;

  if(depth < 1)
     depth = 1;

  if(index < depth)
     return false;

  if(index + depth >= count)
     return false;

  double center =
     bars[index].low;

  if(center <= 0.0)
     return false;

  for(int i = 1; i <= depth; i++)
    {
     if(center >= bars[index - i].low)
        return false;

     if(center >= bars[index + i].low)
        return false;
    }

  return true;
 }

//=================================================================
// ENCONTRA ÚLTIMO SWING HIGH
//
// O array é série:
//
// [0] = candle atual
// [1] = candle anterior
//
// Portanto procuramos do índice mais recente confirmado para o passado.
// O candle aberto (índice 0) nunca confirma um swing estrutural.
//=================================================================

bool FindLatestSwingHigh(
const MqlRates &bars[],
const int count,
int &index,
double &price,
datetime &time
) const
{
index = -1;
price = 0.0;
time = 0;

  if(count < 3)
     return false;

  int depth =
     m_fractalDepth;

  if(depth < 1)
     depth = 1;

  int start =
     depth + 1;

  int end =
     count - depth - 1;

  if(end < start)
     return false;

  for(int i = start; i <= end; i++)
    {
     if(!IsSwingHigh(
           bars,
           count,
           i
        ))
        continue;

     index =
        i;

     price =
        bars[i].high;

     time =
        bars[i].time;

     return true;
    }

  return false;
 }

//=================================================================
// ENCONTRA SEGUNDO SWING HIGH
//=================================================================

bool FindPreviousSwingHigh(
const MqlRates &bars[],
const int count,
const int latestIndex,
int &index,
double &price,
datetime &time
) const
{
index = -1;
price = 0.0;
time = 0;

  if(count < 3)
     return false;

  int depth =
     m_fractalDepth;

  if(depth < 1)
     depth = 1;

  int start =
     latestIndex + 1;

  int end =
     count - depth - 1;

  if(start > end)
     return false;

  for(int i = start; i <= end; i++)
    {
     if(!IsSwingHigh(
           bars,
           count,
           i
        ))
        continue;

     index =
        i;

     price =
        bars[i].high;

     time =
        bars[i].time;

     return true;
    }

  return false;
 }


//=================================================================
// ENCONTRA ÚLTIMO SWING LOW
//=================================================================

bool FindLatestSwingLow(
const MqlRates &bars[],
const int count,
int &index,
double &price,
datetime &time
) const
{
index = -1;
price = 0.0;
time = 0;

  if(count < 3)
     return false;

  int depth =
     m_fractalDepth;

  if(depth < 1)
     depth = 1;

  int start =
     depth + 1;

  int end =
     count - depth - 1;

  if(end < start)
     return false;

  for(int i = start; i <= end; i++)
    {
     if(!IsSwingLow(
           bars,
           count,
           i
        ))
        continue;

     index =
        i;

     price =
        bars[i].low;

     time =
        bars[i].time;

     return true;
    }

  return false;
 }

//=================================================================
// ENCONTRA SEGUNDO SWING LOW
//=================================================================

bool FindPreviousSwingLow(
const MqlRates &bars[],
const int count,
const int latestIndex,
int &index,
double &price,
datetime &time
) const
{
index = -1;
price = 0.0;
time = 0;

  if(count < 3)
     return false;

  int depth =
     m_fractalDepth;

  if(depth < 1)
     depth = 1;

  int start =
     latestIndex + 1;

  int end =
     count - depth - 1;

  if(start > end)
     return false;

  for(int i = start; i <= end; i++)
    {
     if(!IsSwingLow(
           bars,
           count,
           i
        ))
        continue;

     index =
        i;

     price =
        bars[i].low;

     time =
        bars[i].time;

     return true;
    }

  return false;
 }

//=================================================================
// DISTÂNCIA DE BREAK EM PONTOS
//=================================================================

double BreakTolerance(
const AnalysisContext &context
) const
{
if(context.point <= 0.0)
return 0.0;

  if(m_breakTolerancePoints <= 0.0)
     return 0.0;

  return
     m_breakTolerancePoints *
     context.point;
 }


//=================================================================
// DETECTA BREAKOUT BULLISH
//=================================================================

bool DetectBullishBreak(
const AnalysisContext &context,
const double swingHigh
) const
{
if(swingHigh <= 0.0)
return false;

  double price =
     context.close;

  if(price <= 0.0)
     price =
        context.price;

  if(price <= 0.0)
     return false;

  double tolerance =
     BreakTolerance(
        context
     );

  return
     price >
     swingHigh + tolerance;
 }

//=================================================================
// DETECTA BREAKOUT BEARISH
//=================================================================

bool DetectBearishBreak(
const AnalysisContext &context,
const double swingLow
) const
{
if(swingLow <= 0.0)
return false;

  double price =
     context.close;

  if(price <= 0.0)
     price =
        context.price;

  if(price <= 0.0)
     return false;

  double tolerance =
     BreakTolerance(
        context
     );

  return
     price <
     swingLow - tolerance;
 }


//=================================================================
// CALCULA SCORE ESTRUTURAL
//=================================================================

double CalculateStructureScore(
   const bool hh,
   const bool hl,
   const bool lh,
   const bool ll,
   const bool bos,
   const bool choch
) const
{
   double score = 0.0;
   
   int bullishSignals = 0;
   int bearishSignals = 0;
   
   // Pesos base
   if(hh) { score += 25.0; bullishSignals++; }
   if(hl) { score += 25.0; bullishSignals++; }
   if(lh) { score += 25.0; bearishSignals++; }
   if(ll) { score += 25.0; bearishSignals++; }
   
   // BÔNUS por tendência LIMPA (HH+HL ou LH+LL)
   if(hh && hl) score += 15.0;  // Bullish consistente
   if(lh && ll) score += 15.0;  // Bearish consistente
   
   // PENALIDADE por estrutura MISTA (sinais conflitantes)
   if(bullishSignals > 0 && bearishSignals > 0)
   {
      score *= 0.60;  // Reduz em 40% a confiança em estruturas confusas
   }
   
   // Bônus por BOS/CHOCH (confirmam força)
   if(bos)   score += 20.0;
   if(choch) score += 15.0;
   
   if(score > 100.0) score = 100.0;
   if(score < 0.0)   score = 0.0;
   
   return score;
}

//=================================================================
// DETERMINA BIAS
//=================================================================

ENUM_BIAS DetermineBias(
const bool hh,
const bool hl,
const bool lh,
const bool ll,
const bool bullishBreak,
const bool bearishBreak
) const
{
if(bullishBreak && !bearishBreak)
return BIAS_BULLISH;


  if(bearishBreak && !bullishBreak)
     return BIAS_BEARISH;

  int bullishPoints =
     0;

  int bearishPoints =
     0;

  if(hh)
     bullishPoints++;

  if(hl)
     bullishPoints++;

  if(lh)
     bearishPoints++;

  if(ll)
     bearishPoints++;

  if(bullishPoints > bearishPoints)
     return BIAS_BULLISH;

  if(bearishPoints > bullishPoints)
     return BIAS_BEARISH;

  return BIAS_NEUTRAL;
 }


//=================================================================
// DETERMINA ESTADO ESTRUTURAL
//
// O contrato atual utiliza ENUM_LAYER_STATE:
//
// LAYER_VALID
// LAYER_INVALID
// LAYER_NEUTRAL
//
// A estrutura não cria enums próprios como
// STRUCTURE_STATE_BULLISH ou STRUCTURE_STATE_BREAK.
//=================================================================

ENUM_LAYER_STATE DetermineState(
const ENUM_BIAS bias,
const double score,
const bool bos,
const bool choch
) const
{
if(score < m_minStructureScore)
return LAYER_NEUTRAL;

  if(bos || choch)
     return LAYER_VALID;

  if(bias == BIAS_BULLISH ||
     bias == BIAS_BEARISH)
     return LAYER_VALID;

  return LAYER_NEUTRAL;
 }

//=================================================================
// CONVERSÃO DE ESTADO PARA STRING
//=================================================================

string LayerStateToString(
const ENUM_LAYER_STATE state
) const
{
   if(state == LAYER_VALID)
      return "VALID";

   if(state == LAYER_INVALID)
      return "INVALID";

   return "NEUTRAL";
}

//=================================================================
// LOG DE ESTRUTURA
//=================================================================

void PrintStructure(
const AnalysisContext &context
) const
{
PrintFormat(
"[MarketStructureEngine] "
"Symbol=%s | TF=%s | Bias=%s | "
"HH=%s HL=%s LH=%s LL=%s | "
"BOS=%s CHOCH=%s | Score=%.2f | "
"State=%s | LastHigh=%.5f | LastLow=%.5f",
context.symbol,
EnumToString((ENUM_TIMEFRAMES)context.primaryTF),
EnumToString((ENUM_BIAS)context.structuralBias),
context.higherHigh ? "true" : "false",
context.higherLow ? "true" : "false",
context.lowerHigh ? "true" : "false",
context.lowerLow ? "true" : "false",
context.bos ? "true" : "false",
context.choch ? "true" : "false",
context.structuralScore,
LayerStateToString(context.structureState),
context.lastSwingHighPrice,
context.lastSwingLowPrice
);
}

public:

//=================================================================
// CONSTRUTOR
//=================================================================

MarketStructureEngine()
{
   m_fractalDepth = 5;            // Era 2
   m_breakTolerancePoints = 5.0;  // 5 pontos de folga no BOS
   m_minStructureScore = 20.0;
}

//=================================================================
// CONSTRUTOR CONFIGURÁVEL
//=================================================================

MarketStructureEngine(
const int fractalDepth,
const double breakTolerancePoints,
const double minStructureScore
)
{
m_fractalDepth =
fractalDepth;

  if(m_fractalDepth < 1)
     m_fractalDepth = 2;

  m_breakTolerancePoints =
     breakTolerancePoints;

  if(m_breakTolerancePoints < 0.0)
     m_breakTolerancePoints = 0.0;

  m_minStructureScore =
     minStructureScore;

  if(m_minStructureScore < 0.0)
     m_minStructureScore = 0.0;

  if(m_minStructureScore > 100.0)
     m_minStructureScore = 100.0;
 }

//=================================================================
// SET FRACTAL DEPTH
//=================================================================

void SetFractalDepth(
const int depth
)
{
if(depth < 1)
return;

  m_fractalDepth =
     depth;
 }

//=================================================================
// GET FRACTAL DEPTH
//=================================================================

int GetFractalDepth() const
{
return m_fractalDepth;
}

//=================================================================
// SET BREAK TOLERANCE
//=================================================================

void SetBreakTolerancePoints(
const double points
)
{
if(points < 0.0)
return;

  m_breakTolerancePoints =
     points;
 }


//=================================================================
// GET BREAK TOLERANCE
//=================================================================

double GetBreakTolerancePoints() const
{
return m_breakTolerancePoints;
}

//=================================================================
// SET MINIMUM SCORE
//=================================================================

void SetMinimumStructureScore(
const double score
)
{
if(score < 0.0)
return;

  if(score > 100.0)
     return;

  m_minStructureScore =
     score;
 }

//=================================================================
// GET MINIMUM SCORE
//=================================================================

double GetMinimumStructureScore() const
{
return m_minStructureScore;
}

//=================================================================
// ANALYZE
//=================================================================

bool Analyze(
AnalysisContext &context
)
{
//==============================================================
// LIMPAR SOMENTE A CAMADA DE STRUCTURE
//==============================================================

  ResetStructure(
     context
  );


  //==============================================================
  // VALIDAR CONTEXTO
  //==============================================================

  if(!ValidateContext(
        context
     ))
    {
     context.structureState =
        LAYER_INVALID;

     context.validationMessage =
        "MarketStructureEngine: "
        "AnalysisContext invalido ou market data indisponivel.";

     return false;
    }


  //==============================================================
  // VALIDAR HISTÓRICO
  //==============================================================

  int count =
     context.marketBarsCount;

  if(count > ArraySize(
        context.marketBars
     ))
     count =
        ArraySize(
           context.marketBars
        );

  if(count < 3)
    {
     context.structureState =
        LAYER_INVALID;

     context.validationMessage =
        "MarketStructureEngine: "
        "historico insuficiente.";

     return false;
    }


  //==============================================================
  // VALIDAR PRIMEIRAS BARRAS
  //==============================================================

  if(!IsValidBar(
        context.marketBars[0]
     ) ||
     !IsValidBar(
        context.marketBars[1]
     ) ||
     !IsValidBar(
        context.marketBars[2]
     ))
    {
     context.structureState =
        LAYER_INVALID;

     context.validationMessage =
        "MarketStructureEngine: "
        "barras fundamentais invalidas.";

     return false;
    }


  //==============================================================
  // LOCALIZAR SWINGS
  //==============================================================

  int latestHighIndex =
     -1;

  int previousHighIndex =
     -1;

  int latestLowIndex =
     -1;

  int previousLowIndex =
     -1;

  double latestHighPrice =
     0.0;

  double previousHighPrice =
     0.0;

  double latestLowPrice =
     0.0;

  double previousLowPrice =
     0.0;

  datetime latestHighTime =
     0;

  datetime previousHighTime =
     0;

  datetime latestLowTime =
     0;

  datetime previousLowTime =
     0;


  bool hasLatestHigh =
     FindLatestSwingHigh(
        context.marketBars,
        count,
        latestHighIndex,
        latestHighPrice,
        latestHighTime
     );


  bool hasPreviousHigh =
     false;

  if(hasLatestHigh)
    {
     hasPreviousHigh =
        FindPreviousSwingHigh(
           context.marketBars,
           count,
           latestHighIndex,
           previousHighIndex,
           previousHighPrice,
           previousHighTime
        );
    }


  bool hasLatestLow =
     FindLatestSwingLow(
        context.marketBars,
        count,
        latestLowIndex,
        latestLowPrice,
        latestLowTime
     );


  bool hasPreviousLow =
     false;

  if(hasLatestLow)
    {
     hasPreviousLow =
        FindPreviousSwingLow(
           context.marketBars,
           count,
           latestLowIndex,
           previousLowIndex,
           previousLowPrice,
           previousLowTime
        );
    }


  //==============================================================
  // REGISTRAR ÚLTIMOS SWINGS
  //==============================================================

  if(hasLatestHigh)
    {
     context.lastSwingHighPrice =
        NormalizePrice(
           context,
           latestHighPrice
        );

     context.lastSwingHighTime =
        latestHighTime;
    }

  if(hasLatestLow)
    {
     context.lastSwingLowPrice =
        NormalizePrice(
           context,
           latestLowPrice
        );

     context.lastSwingLowTime =
        latestLowTime;
    }


  //==============================================================
  // DETECTAR HH / LH
  //==============================================================

  bool higherHighDetected =
     false;

  bool lowerHighDetected =
     false;

  if(hasLatestHigh &&
     hasPreviousHigh &&
     latestHighPrice > previousHighPrice)
    {
     higherHighDetected =
        true;
    }

  if(hasLatestHigh &&
     hasPreviousHigh &&
     latestHighPrice < previousHighPrice)
    {
     lowerHighDetected =
        true;
    }


  //==============================================================
  // DETECTAR HL / LL
  //==============================================================

  bool higherLowDetected =
     false;

  bool lowerLowDetected =
     false;

  if(hasLatestLow &&
     hasPreviousLow &&
     latestLowPrice > previousLowPrice)
    {
     higherLowDetected =
        true;
    }

  if(hasLatestLow &&
     hasPreviousLow &&
     latestLowPrice < previousLowPrice)
    {
     lowerLowDetected =
        true;
    }


  //==============================================================
  // GRAVAR HH / HL / LH / LL
  //==============================================================

  context.higherHigh =
     higherHighDetected;

  context.higherLow =
     higherLowDetected;

  context.lowerHigh =
     lowerHighDetected;

  context.lowerLow =
     lowerLowDetected;


  //==============================================================
  // DETECTAR BOS
  //
  // BOS bullish:
  // fechamento acima do último swing high.
  //
  // BOS bearish:
  // fechamento abaixo do último swing low.
  //==============================================================

  bool bullishBreak =
     false;

  bool bearishBreak =
     false;

  if(hasLatestHigh)
    {
     bullishBreak =
        DetectBullishBreak(
           context,
           latestHighPrice
        );
    }

  if(hasLatestLow)
    {
     bearishBreak =
        DetectBearishBreak(
           context,
           latestLowPrice
        );
    }


  //==============================================================
  // BOS
  //==============================================================

  context.bos =
     bullishBreak ||
     bearishBreak;


  //==============================================================
  // BIAS PREVIOUS / CURRENT
  //
  // Como o AnalysisContext não possui um campo separado para
  // "previous structural bias", o CHOCH é inferido pela quebra
  // atual em direção oposta à estrutura dominante observada
  // pelos HH/HL/LH/LL.
  //==============================================================

  ENUM_BIAS currentBias =
     DetermineBias(
        higherHighDetected,
        higherLowDetected,
        lowerHighDetected,
        lowerLowDetected,
        bullishBreak,
        bearishBreak
     );


  //==============================================================
  // DETECTAR CHOCH
  //==============================================================

  bool chochDetected =
     false;

  if(bullishBreak)
    {
     if(lowerHighDetected ||
        lowerLowDetected)
       {
        chochDetected =
           true;
       }
    }

  if(bearishBreak)
    {
     if(higherHighDetected ||
        higherLowDetected)
       {
        chochDetected =
           true;
       }
    }

  context.choch =
     chochDetected;


  //==============================================================
  // BIAS
  //==============================================================

  context.structuralBias =
     currentBias;


  //==============================================================
  // SCORE
  //==============================================================

  context.structuralScore =
     CalculateStructureScore(
        higherHighDetected,
        higherLowDetected,
        lowerHighDetected,
        lowerLowDetected,
        context.bos,
        context.choch
     );


  //==============================================================
  // ESTADO
  //==============================================================

  context.structureState =
     DetermineState(
        context.structuralBias,
        context.structuralScore,
        context.bos,
        context.choch
     );


  //==============================================================
  // VALIDAR EXISTÊNCIA DE ESTRUTURA
  //==============================================================

  bool structureFound =
     hasLatestHigh ||
     hasLatestLow;

  if(!structureFound)
    {
     context.structuralBias =
        BIAS_NEUTRAL;

     context.structuralScore =
        0.0;

     context.structureState =
        LAYER_NEUTRAL;

     context.validationMessage =
        "MarketStructureEngine: "
        "nenhum swing estrutural confirmado.";

     return true;
    }


  //==============================================================
  // GARANTIR CONSISTÊNCIA DO SCORE
  //==============================================================

  if(context.structuralScore < 0.0)
     context.structuralScore =
        0.0;

  if(context.structuralScore > 100.0)
     context.structuralScore =
        100.0;


  //==============================================================
  // MENSAGEM DE STATUS
  //==============================================================

  if(context.bos &&
     context.choch)
    {
     context.validationMessage =
        "MarketStructureEngine: "
        "BOS e CHOCH detectados.";
    }
  else
  if(context.bos)
    {
     context.validationMessage =
        "MarketStructureEngine: "
        "BOS detectado.";
    }
  else
  if(context.choch)
    {
     context.validationMessage =
        "MarketStructureEngine: "
        "CHOCH detectado.";
    }
  else
  if(context.structuralBias == BIAS_BULLISH)
    {
     context.validationMessage =
        "MarketStructureEngine: "
        "estrutura bullish identificada.";
    }
  else
  if(context.structuralBias == BIAS_BEARISH)
    {
     context.validationMessage =
        "MarketStructureEngine: "
        "estrutura bearish identificada.";
    }
  else
    {
     context.validationMessage =
        "MarketStructureEngine: "
        "estrutura neutra.";
    }


  //==============================================================
  // DEBUG
  //==============================================================

  PrintStructure(
     context
  );


  return true;
 }

//=================================================================
// UPDATE
//=================================================================

bool Update(
AnalysisContext &context
)
{
return Analyze(
context
);
}

//=================================================================
// PROCESS
//=================================================================

bool Process(
AnalysisContext &context
)
{
return Analyze(
context
);
}

//=================================================================
// IS VALID
//=================================================================

bool IsValid(
const AnalysisContext &context
) const
{
if(!ValidateContext(
context
))
return false;

  if(context.structureState ==
     LAYER_INVALID)
     return false;

  return true;
 }
 
//=================================================================
// GETTERS
//=================================================================

ENUM_BIAS GetBias(
const AnalysisContext &context
) const
{
return context.structuralBias;
}

bool GetBOS(
const AnalysisContext &context
) const
{
return context.bos;
}

bool GetCHOCH(
const AnalysisContext &context
) const
{
return context.choch;
}

bool HigherHigh(
const AnalysisContext &context
) const
{
return context.higherHigh;
}

bool HigherLow(
const AnalysisContext &context
) const
{
return context.higherLow;
}

bool LowerHigh(
const AnalysisContext &context
) const
{
return context.lowerHigh;
}

bool LowerLow(
const AnalysisContext &context
) const
{
return context.lowerLow;
}

double GetStructureScore(
const AnalysisContext &context
) const
{
return context.structuralScore;
}

double GetLastHigh(
const AnalysisContext &context
) const
{
return context.lastSwingHighPrice;
}

double GetLastLow(
const AnalysisContext &context
) const
{
return context.lastSwingLowPrice;
}

datetime GetLastHighTime(
const AnalysisContext &context
) const
{
return context.lastSwingHighTime;
}

datetime GetLastLowTime(
const AnalysisContext &context
) const
{
return context.lastSwingLowTime;
}

ENUM_LAYER_STATE GetState(
const AnalysisContext &context
) const
{
return context.structureState;
}

//=================================================================
// COMPATIBILIDADE SEM CONTEXTO INTERNO
//
// Estes métodos não mantêm estado próprio.
// O AnalysisContext continua sendo a única fonte de verdade.
//=================================================================

ENUM_BIAS GetTrend(
const AnalysisContext &context
) const
{
return context.structuralBias;
}

bool IsBullish(
const AnalysisContext &context
) const
{
return
context.structuralBias ==
BIAS_BULLISH;
}

bool IsBearish(
const AnalysisContext &context
) const
{
return
context.structuralBias ==
BIAS_BEARISH;
}

bool IsNeutral(
const AnalysisContext &context
) const
{
return
context.structuralBias ==
BIAS_NEUTRAL;
}

string GetStatus(
const AnalysisContext &context
) const
{
if(context.structureState ==
LAYER_INVALID)
return "INVALID";

  if(context.structureState ==
     LAYER_VALID)
     return "VALID";

  return "NEUTRAL";
 }

string GetLastErrorDescription() const
{
return
"MarketStructureEngine: "
"analise estrutural baseada no AnalysisContext.";
}
};

//+------------------------------------------------------------------+
//| FIM                                                              |
//+------------------------------------------------------------------+
#endif // ASTRA_MARKETSTRUCTUREENGINE_MQH
