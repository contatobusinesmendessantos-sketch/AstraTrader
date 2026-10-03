//+------------------------------------------------------------------+
//|                    ASTRA AI - Brain Engine                      |
//|                    Market Intelligence Core                     |
//+------------------------------------------------------------------+

#ifndef __ASTRA_BRAIN_MQH__
#define __ASTRA_BRAIN_MQH__



class AstraBrain
{


private:


string MarketContext;

string StructureState;

string LiquidityState;

string InstitutionalZone;

string FinalDecision;


int Score;



public:



AstraBrain()
{

MarketContext="NEUTRO";

StructureState="NENHUMA";

LiquidityState="NENHUMA";

InstitutionalZone="NENHUMA";

FinalDecision="AGUARDANDO";

Score=0;

}



//--------------------------------------------------
// Atualiza interpretação
//--------------------------------------------------

void Analyze(
string trend,
string bos,
string choch,
string liquidity,
string orderblock,
string fvg,
int buyScore,
int sellScore
)
{


Score=0;



//==============================
// Contexto
//==============================


if(trend=="ALTA")
{

MarketContext="CONTEXTO COMPRADOR";

}


else
if(trend=="BAIXA")
{

MarketContext="CONTEXTO VENDEDOR";

}


else
{

MarketContext="MERCADO INDEFINIDO";

}



//==============================
// Estrutura
//==============================


StructureState=
trend+" | "+bos+" | "+choch;



//==============================
// Liquidez
//==============================


LiquidityState=liquidity;



//==============================
// Zona institucional
//==============================


InstitutionalZone=
orderblock+" + "+fvg;



//==============================
// Decisão
//==============================


if(buyScore>sellScore)
{

Score=buyScore;

}


else
{

Score=sellScore;

}



if(Score>=80)
{

FinalDecision=
"SETUP FORTE";

}


else
if(Score>=60)
{

FinalDecision=
"SETUP MODERADO";

}


else
{

FinalDecision=
"SEM ENTRADA";

}


}



//--------------------------------------------------


string GetContext()
{

return MarketContext;

}



//--------------------------------------------------

string GetStructure()
{

return StructureState;

}



//--------------------------------------------------

string GetLiquidity()
{

return LiquidityState;

}



//--------------------------------------------------

string GetZone()
{

return InstitutionalZone;

}



//--------------------------------------------------

string GetDecision()
{

return FinalDecision;

}



//--------------------------------------------------

int GetScore()
{

return Score;

}


};



#endif