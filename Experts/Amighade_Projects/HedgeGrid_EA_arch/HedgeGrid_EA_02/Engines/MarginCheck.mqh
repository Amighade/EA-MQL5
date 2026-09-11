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

//+------------------------------------------------------------------+
//| Calculate margin required for one order at given lot             |
//+------------------------------------------------------------------+
double GetMarginForLot(double lot)
{
   bool okAfter = true;
   double margin = 0.0;
   okAfter = OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lot,
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK), margin);
   return margin;
}

//+------------------------------------------------------------------+
//| Calculate total margin required for full grid (both sides)       |
//+------------------------------------------------------------------+
double GetRequiredMargin(ENUM_LOT_MODE lotMode)
{
   int    levels      = (lotMode == LOT_FULL) ? InpGridLevels : InpGridLevels / 2;
   double totalMargin = 0.0;

   for(int i = 1; i <= levels; i++)
     {
      double lot = 0.0;
      if(InpStrategyStyle == STYLE_A)
         lot = MathMin(InpInitialLotStep * i, InpInitialLotCap);
      else
         lot = InpFixedLot;

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
