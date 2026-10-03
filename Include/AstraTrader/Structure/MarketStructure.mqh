//+------------------------------------------------------------------+
//|              MarketStructureEngine.mqh v2                        |
//|                         ASTRA AI                                 |
//|          Advanced Institutional Structure Engine                 |
//+------------------------------------------------------------------+

#ifndef __MARKET_STRUCTURE_ENGINE_MQH__
#define __MARKET_STRUCTURE_ENGINE_MQH__


//==================================================================
// Classe principal
//==================================================================

class MarketStructureEngine
{


private:


//--------------------------------------------------
// Estrutura básica
//--------------------------------------------------

double lastHigh;

double lastLow;


bool higherHigh;

bool lowerLow;


string trend;


//--------------------------------------------------
// Smart Money Concepts
//--------------------------------------------------

string BOS;

string Liquidity;

string OrderBlock;

string FVG;



//==================================================================
// Inicialização
//==================================================================


public:


MarketStructureEngine()
{


lastHigh = 0;

lastLow = 0;


higherHigh = false;

lowerLow = false;


trend = "NEUTRA";


BOS = "SEM BOS";

Liquidity = "SEM LIQUIDEZ";

OrderBlock = "SEM ORDER BLOCK";

FVG = "SEM FVG";


}



//==================================================================
// Atualização principal
//==================================================================


void Update()
{


int highIndex = 
iHighest(
Symbol(),
PERIOD_CURRENT,
MODE_HIGH,
50,
1
);



int lowIndex =
iLowest(
Symbol(),
PERIOD_CURRENT,
MODE_LOW,
50,
1
);



if(highIndex < 0 || lowIndex < 0)
return;



double previousHigh = lastHigh;

double previousLow  = lastLow;



lastHigh =
iHigh(
Symbol(),
PERIOD_CURRENT,
highIndex
);



lastLow =
iLow(
Symbol(),
PERIOD_CURRENT,
lowIndex
);




//==================================================
// Higher High / Lower Low
//==================================================


higherHigh = false;

lowerLow = false;



if(previousHigh > 0)
{

if(lastHigh > previousHigh)
higherHigh = true;

}



if(previousLow > 0)
{

if(lastLow < previousLow)
lowerLow = true;

}



//==================================================
// Tendência estrutural
//==================================================


double price =
SymbolInfoDouble(
Symbol(),
SYMBOL_BID
);



double midpoint =
(lastHigh + lastLow) / 2.0;



if(price > midpoint)
{

trend = "ALTA";

}

else
if(price < midpoint)
{

trend = "BAIXA";

}

else
{

trend = "NEUTRA";

}



//==================================================
// BOS - Break Of Structure
//==================================================


BOS = "SEM BOS";



if(higherHigh)
{

BOS = "BOS ALTA";

}



if(lowerLow)
{

BOS = "BOS BAIXA";

}



//==================================================
// Liquidez
//==================================================


Liquidity = "NEUTRA";



double range =
lastHigh - lastLow;



double distanceHigh =
lastHigh - price;



double distanceLow =
price - lastLow;



if(range > 0)
{


if(distanceHigh < range * 0.20)
{

Liquidity = "LIQUIDEZ SUPERIOR";

}



else
if(distanceLow < range * 0.20)
{

Liquidity = "LIQUIDEZ INFERIOR";

}


}



//==================================================
// Order Block simplificado
//==================================================


if(trend=="ALTA")
{

OrderBlock = "OB COMPRA";

}


else
if(trend=="BAIXA")
{

OrderBlock = "OB VENDA";

}


else
{

OrderBlock = "SEM ORDER BLOCK";

}



//==================================================
// Fair Value Gap simplificado
//==================================================


double high1 =
iHigh(
Symbol(),
PERIOD_CURRENT,
1
);


double low1 =
iLow(
Symbol(),
PERIOD_CURRENT,
1
);


double high3 =
iHigh(
Symbol(),
PERIOD_CURRENT,
3
);


double low3 =
iLow(
Symbol(),
PERIOD_CURRENT,
3
);




if(low1 > high3)
{

FVG = "FVG COMPRA";

}


else
if(high1 < low3)
{

FVG = "FVG VENDA";

}


else
{

FVG = "SEM FVG";

}



}



//==================================================================
// Get Trend
//==================================================================


string GetTrend()
{

return trend;

}



//==================================================================
// Máxima estrutural
//==================================================================


double GetLastHigh()
{

return lastHigh;

}



//==================================================================
// Mínima estrutural
//==================================================================


double GetLastLow()
{

return lastLow;

}



//==================================================================
// Higher High
//==================================================================


bool HigherHigh()
{

return higherHigh;

}



//==================================================================
// Lower Low
//==================================================================


bool LowerLow()
{

return lowerLow;

}



//==================================================================
// BOS
//==================================================================


string GetBOS()
{

return BOS;

}



//==================================================================
// Liquidez
//==================================================================


string GetLiquidity()
{

return Liquidity;

}



//==================================================================
// Order Block
//==================================================================


string GetOrderBlock()
{

return OrderBlock;

}



//==================================================================
// FVG
//==================================================================


string GetFVG()
{

return FVG;

}



//==================================================================
// Resumo completo
//==================================================================


string GetStructure()
{


string result;



result =
"TENDENCIA: "
+ trend;



result +=
" | BOS: "
+ BOS;



result +=
" | LIQUIDEZ: "
+ Liquidity;



result +=
" | OB: "
+ OrderBlock;



result +=
" | FVG: "
+ FVG;



if(higherHigh)
result += " | HH";



if(lowerLow)
result += " | LL";



return result;


}



};


#endif