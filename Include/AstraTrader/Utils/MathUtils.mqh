//+------------------------------------------------------------------+
//| MathUtils.mqh                                                    |
//| Astra Trader AI                                                  |
//|                                                                  |
//| Funcoes matematicas e utilitarios compartilhados pelo pipeline.  |
//|                                                                  |
//| Responsabilidades:                                               |
//|   - normalizacao de lote                                         |
//|   - normalizacao de preco                                        |
//|   - normalizacao Z-Score                                         |
//|   - clamp de valores                                             |
//+------------------------------------------------------------------+
#ifndef ASTRA_MATHUTILS_MQH
#define ASTRA_MATHUTILS_MQH

//==================================================================
// NORMALIZE LOT SIZE
//==================================================================
// Ajusta o lote de acordo com:
//   SYMBOL_VOLUME_MIN
//   SYMBOL_VOLUME_MAX
//   SYMBOL_VOLUME_STEP
//
// Retorna 0.0 se as especificacoes do simbolo forem invalidas.
//==================================================================
double NormalizeLotSize(
   const string symbol,
   double rawLots)
{
   if(symbol=="")
      return 0.0;

   if(!MathIsValidNumber(rawLots))
      return 0.0;

   double minLot=
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_MIN
      );

   double maxLot=
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_MAX
      );

   double step=
      SymbolInfoDouble(
         symbol,
         SYMBOL_VOLUME_STEP
      );

   if(minLot<=0.0 || maxLot<=0.0 || step<=0.0)
      return 0.0;

   //===============================================================
   // LIMITA AO RANGE DO SIMBOLO
   //===============================================================
   rawLots=
      MathMax(
         minLot,
         MathMin(
            maxLot,
            rawLots
         )
      );

   //===============================================================
   // AJUSTA AO VOLUME STEP
   //===============================================================
   double steps=
      MathFloor(
         rawLots/step
      );

   double normalized=
      steps*step;

   //===============================================================
   // PROTECAO CONTRA ARREDONDAMENTO ABAIXO DO MINIMO
   //===============================================================
   if(normalized<minLot)
      normalized=minLot;

   if(normalized>maxLot)
      normalized=maxLot;

   //===============================================================
   // NORMALIZACAO DECIMAL
   //===============================================================
   int volumeDigits=0;

   double testStep=step;

   while(
      volumeDigits<8 &&
      MathAbs(testStep-MathRound(testStep))>0.00000001
   )
   {
      testStep*=10.0;
      volumeDigits++;
   }

   return NormalizeDouble(
      normalized,
      volumeDigits
   );
}

//==================================================================
// NORMALIZE PRICE
//==================================================================
// Ajusta o preco ao tick size real do simbolo e depois aos digits.
//==================================================================
double NormalizePrice(
   const string symbol,
   double rawPrice)
{
   if(symbol=="")
      return 0.0;

   if(!MathIsValidNumber(rawPrice))
      return 0.0;

   double tickSize=
      SymbolInfoDouble(
         symbol,
         SYMBOL_TRADE_TICK_SIZE
      );

   if(tickSize<=0.0)
   {
      tickSize=
         SymbolInfoDouble(
            symbol,
            SYMBOL_POINT
         );
   }

   int digits=
      (int)SymbolInfoInteger(
         symbol,
         SYMBOL_DIGITS
      );

   if(tickSize>0.0)
   {
      rawPrice=
         MathRound(
            rawPrice/tickSize
         )*tickSize;
   }

   return NormalizeDouble(
      rawPrice,
      digits
   );
}

//==================================================================
// Z-SCORE NORMALIZATION
//==================================================================
// Formula:
//
// Z = (value - mean) / stdDev
//
// Se o desvio padrao for zero, retorna 0.0.
//==================================================================
double ZScoreNormalize(
   const double value,
   const double mean,
   const double stdDev)
{
   if(!MathIsValidNumber(value))
      return 0.0;

   if(!MathIsValidNumber(mean))
      return 0.0;

   if(!MathIsValidNumber(stdDev))
      return 0.0;

   if(stdDev<=0.0)
      return 0.0;

   return (value-mean)/stdDev;
}

//==================================================================
// CLAMP SCORE
//==================================================================
// Limita um valor entre minV e maxV.
//==================================================================
double ClampScore(
   double value,
   const double minV=0.0,
   const double maxV=100.0)
{
   if(!MathIsValidNumber(value))
      return minV;

   double lower=minV;
   double upper=maxV;

   // Protecao caso os limites sejam fornecidos invertidos.
   if(lower>upper)
   {
      double temp=lower;
      lower=upper;
      upper=temp;
   }

   return MathMax(
      lower,
      MathMin(
         upper,
         value
      )
   );
}

#endif // ASTRA_MATHUTILS_MQH