//+------------------------------------------------------------------+
//| StatePersistence.mqh                                              |
//| Save and restore GridState via GlobalVariables                   |
//| Used for mid-session reconnects only                             |
//| EA always starts fresh on full restart (by design)               |
//+------------------------------------------------------------------+
#pragma once

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/DebugLogger.mqh"

//+------------------------------------------------------------------+
//| Build a unique key prefix for this EA instance                   |
//| Format: HG_SYMBOL_TIMEFRAME_                                     |
//+------------------------------------------------------------------+
string GetKeyPrefix()
  {
   return "HG_" + _Symbol + "_" + IntegerToString(_Period) + "_";
  }

//+------------------------------------------------------------------+
//| Save critical GridState fields to GlobalVariables                |
//| Only fields needed to resume mid-cycle are saved                 |
//+------------------------------------------------------------------+
void SaveState(const GridState &state)
  {
   string p = GetKeyPrefix();

   GlobalVariableSet(p + "cycleActive",     (double)state.cycleActive);
   GlobalVariableSet(p + "gridPlaced",      (double)state.gridPlaced);
   GlobalVariableSet(p + "passCounter",     (double)state.passCounter);
   GlobalVariableSet(p + "lotMode",         (double)state.lotMode);
   GlobalVariableSet(p + "anchorBuy",       state.anchorBuy);
   GlobalVariableSet(p + "anchorSell",      state.anchorSell);
   GlobalVariableSet(p + "lastHitDir",      (double)state.lastHitDirection);
   GlobalVariableSet(p + "lastHitLot",      state.lastHitLot);
   GlobalVariableSet(p + "lastHitPrice",    state.lastHitPrice);
   GlobalVariableSet(p + "currentBlockLot", state.currentBlockLot);
   GlobalVariableSet(p + "slApplied",       (double)state.slApplied);
   GlobalVariableSet(p + "slLevel",         state.slLevel);
   GlobalVariableSet(p + "magicNumber",     (double)state.magicNumber);

   LogDebug("State saved to GlobalVariables.");
  }

//+------------------------------------------------------------------+
//| Load GridState from GlobalVariables                              |
//| Returns true if valid saved state was found                      |
//+------------------------------------------------------------------+
bool LoadState(GridState &state)
  {
   string p = GetKeyPrefix();

   // Check if saved state exists
   if(!GlobalVariableCheck(p + "cycleActive"))
     {
      LogDebug("No saved state found.");
      return false;
     }

   state.cycleActive      = (bool)GlobalVariableGet(p + "cycleActive");
   state.gridPlaced       = (bool)GlobalVariableGet(p + "gridPlaced");
   state.passCounter      = (int)GlobalVariableGet(p + "passCounter");
   state.lotMode          = (ENUM_LOT_MODE)(int)GlobalVariableGet(p + "lotMode");
   state.anchorBuy        = GlobalVariableGet(p + "anchorBuy");
   state.anchorSell       = GlobalVariableGet(p + "anchorSell");
   state.lastHitDirection = (ENUM_ORDER_TYPE)(int)GlobalVariableGet(p + "lastHitDir");
   state.lastHitLot       = GlobalVariableGet(p + "lastHitLot");
   state.lastHitPrice     = GlobalVariableGet(p + "lastHitPrice");
   state.currentBlockLot  = GlobalVariableGet(p + "currentBlockLot");
   state.slApplied        = (bool)GlobalVariableGet(p + "slApplied");
   state.slLevel          = GlobalVariableGet(p + "slLevel");
   state.magicNumber      = (int)GlobalVariableGet(p + "magicNumber");

   LogDebug("State loaded from GlobalVariables.");
   return true;
  }

//+------------------------------------------------------------------+
//| Clear all saved GlobalVariables for this EA instance             |
//| Call after full cycle reset                                      |
//+------------------------------------------------------------------+
void ClearState()
  {
   string p = GetKeyPrefix();
   string keys[] = {"cycleActive","gridPlaced","passCounter","lotMode",
                    "anchorBuy","anchorSell","lastHitDir","lastHitLot",
                    "lastHitPrice","currentBlockLot","slApplied","slLevel","magicNumber"};

   for(int i = 0; i < ArraySize(keys); i++)
      GlobalVariableDel(p + keys[i]);

   LogDebug("Saved state cleared from GlobalVariables.");
  }
