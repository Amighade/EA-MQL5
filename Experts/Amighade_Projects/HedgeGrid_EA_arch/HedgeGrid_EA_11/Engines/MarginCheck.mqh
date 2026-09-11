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
double GetRequiredMargin(ENUM_LOT_MODE lotMode)
{
   int    levels      = GetMaxLevels(lotMode);
   double totalMargin = 0.0;

   for(int i = 1; i <= levels; i++)
     {
      double lot = GetLot(i, lotMode);
      // Both BUY and SELL sides
      totalMargin += GetMarginForLot(lot) * 2;
     }
   return totalMargin;
}

//+------------------------------------------------------------------+
//| Check margin and return recommended lot mode                     |
//+------------------------------------------------------------------+
ENUM_LOT_MODE CheckMargin(GridState &state)
{
   double freeMargin   = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double requiredFull = GetRequiredMargin(LOT_FULL);
   double requiredHalf = GetRequiredMargin(LOT_HALF);

   // Below absolute minimum — block EA
   if(freeMargin < InpMinAllowedMargin)
     {
      state.marginWarning = true;
      LogMarginWarning(freeMargin, InpMinAllowedMargin);
      Alert(StringFormat("HedgeGrid: FREE MARGIN %.2f below minimum %.2f. EA blocked.",
                         freeMargin, InpMinAllowedMargin));
      return LOT_HALF;
     }

   // Full ladder affordable
   if(freeMargin >= requiredFull + InpMinAllowedMargin)
     {
      state.marginWarning = false;
      return LOT_FULL;
     }

   // Half ladder affordable
   if(freeMargin >= requiredHalf + InpMinAllowedMargin)
     {
      state.marginWarning = true;
      LogMarginWarning(freeMargin, requiredFull);
      Alert(StringFormat("HedgeGrid: Low margin — switching to HALF ladder. Free=%.2f Required=%.2f",
                         freeMargin, requiredFull));
      return LOT_HALF;
     }

   // Critical — block
   state.marginWarning = true;
   Alert("HedgeGrid: CRITICAL MARGIN. Cannot place grid. Check account.");
   return LOT_HALF;
}

#endif
