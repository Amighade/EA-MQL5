//+------------------------------------------------------------------+
//| MarginCheck.mqh                                                   |
//| Margin validation before grid placement                          |
//+------------------------------------------------------------------+
#ifndef MARGIN_CHECK_MQH
#define MARGIN_CHECK_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "../Utils/SizingUtils.mqh"

//+------------------------------------------------------------------+
//| Calculate margin required for one order at given lot             |
//+------------------------------------------------------------------+
double GetMarginForLot(double lot)
{
   double margin = 0.0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lot,
                       SymbolInfoDouble(_Symbol, SYMBOL_ASK), margin))
     {
      LogDebug(StringFormat("[MarginCheck] OrderCalcMargin failed for lot=%.2f err=%d", lot, GetLastError()));
      return 0.0;
     }
   return margin;
}


//+------------------------------------------------------------------+
//| Calculate total margin required for full grid (both sides)       |
//+------------------------------------------------------------------+
double GetRequiredMargin()
{
   int    levels      = InpInitialGridLevels;
   double totalMargin = 0.0;

   for(int i = 1; i <= levels; i++)
     {
      double lot = GetLot(i);
      // Both BUY and SELL sides
      totalMargin += GetMarginForLot(lot) * 2;
     }
   return totalMargin;
}

#endif
