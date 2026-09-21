//+------------------------------------------------------------------+
//| MarginCheck.mqh                                                   |
//| Margin validation before grid placement                          |
//| Returns lot mode recommendation and triggers alarm if needed     |
//+------------------------------------------------------------------+
#pragma once

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/DebugLogger.mqh"

//+------------------------------------------------------------------+
//| Calculate margin required for one order at given lot             |
//+------------------------------------------------------------------+
double GetMarginForLot(double lot)
  {
   double margin = 0.0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lot,
                       SymbolInfoDouble(_Symbol, SYMBOL_ASK), margin))
      return 0.0;
   return margin;
  }

//+------------------------------------------------------------------+
//| Calculate total margin required for full grid (both sides)       |
//+------------------------------------------------------------------+
double GetRequiredMargin(ENUM_LOT_MODE lotMode)
  {
   int    levels    = (lotMode == LOT_FULL) ? InpGridLevels : InpGridLevels / 2;
   double lotStep   = InpInitialLotStep;
   double totalMargin = 0.0;

   for(int i = 1; i <= levels; i++)
     {
      double lot = 0.0;
      if(InpStrategyStyle == STYLE_A)
         lot = MathMin(lotStep * i, InpInitialLotCap);
      else
         lot = InpFixedLot;

      // Both sides (BUY + SELL) so multiply by 2
      totalMargin += GetMarginForLot(lot) * 2;
     }
   return totalMargin;
  }

//+------------------------------------------------------------------+
//| Check margin and return recommended lot mode                     |
//| Updates GridState.marginWarning and GridState.lotMode            |
//+------------------------------------------------------------------+
ENUM_LOT_MODE CheckMargin(GridState &state)
  {
   double freeMargin    = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double requiredFull  = GetRequiredMargin(LOT_FULL);
   double requiredHalf  = GetRequiredMargin(LOT_HALF);

   // Check against minimum allowed margin input
   if(freeMargin < InpMinAllowedMargin)
     {
      state.marginWarning = true;
      LogMarginWarning(freeMargin, InpMinAllowedMargin);
      Alert(StringFormat("HedgeGrid: FREE MARGIN %.2f below minimum %.2f. EA blocked.",
                         freeMargin, InpMinAllowedMargin));
      return LOT_HALF; // Safest fallback
     }

   // Check if full ladder is affordable
   if(freeMargin >= requiredFull + InpMinAllowedMargin)
     {
      state.marginWarning = false;
      return LOT_FULL;
     }

   // Check if half ladder is affordable
   if(freeMargin >= requiredHalf + InpMinAllowedMargin)
     {
      state.marginWarning = true;
      LogMarginWarning(freeMargin, requiredFull);
      Alert(StringFormat("HedgeGrid: Margin low. Switching to HALF ladder. Free=%.2f Required=%.2f",
                         freeMargin, requiredFull));
      return LOT_HALF;
     }

   // Neither affordable — block EA
   state.marginWarning = true;
   LogMarginWarning(freeMargin, requiredHalf);
   Alert("HedgeGrid: CRITICAL MARGIN. Cannot place even half ladder. EA blocked. Please check account.");
   return LOT_HALF; // Return half as safest, caller must check marginWarning flag
  }
