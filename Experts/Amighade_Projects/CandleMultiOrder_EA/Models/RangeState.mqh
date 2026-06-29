//+------------------------------------------------------------------+
//| RangeState.mqh                                                    |
//| Range anchor persistence via GlobalVariables                     |
//| Saves/loads gbuyEntry_range, gsellEntry_range, grange            |
//+------------------------------------------------------------------+
#ifndef CMO_RANGE_STATE_MQH
#define CMO_RANGE_STATE_MQH

#include "../Inputs.mqh"
#include "EAState.mqh"

//+------------------------------------------------------------------+
//| Build unique key prefix: EA_SYMBOL_PERIOD_                       |
//+------------------------------------------------------------------+
string GetRangeKeyPrefix()
{
   return "EA_" + _Symbol + "_" + IntegerToString(_Period) + "_";
}

//+------------------------------------------------------------------+
//| Save range anchors to GlobalVariables                            |
//+------------------------------------------------------------------+
void SaveRangeState()
{
   string p = GetRangeKeyPrefix();
   GlobalVariableSet(p + "BUY_RANGE",  gbuyEntry_range);
   GlobalVariableSet(p + "SELL_RANGE", gsellEntry_range);
   GlobalVariableSet(p + "GRANGE",     grange);
}

//+------------------------------------------------------------------+
//| Load range anchors from GlobalVariables                          |
//+------------------------------------------------------------------+
void LoadRangeState()
{
   string p    = GetRangeKeyPrefix();
   string kBuy  = p + "BUY_RANGE";
   string kSell = p + "SELL_RANGE";
   string kRange= p + "GRANGE";

   if(GlobalVariableCheck(kBuy))  gbuyEntry_range  = GlobalVariableGet(kBuy);
   if(GlobalVariableCheck(kSell)) gsellEntry_range = GlobalVariableGet(kSell);
   if(GlobalVariableCheck(kRange))grange           = GlobalVariableGet(kRange);
}

//+------------------------------------------------------------------+
//| Clear saved range state                                          |
//+------------------------------------------------------------------+
void ClearRangeState()
{
   string p = GetRangeKeyPrefix();
   GlobalVariableDel(p + "BUY_RANGE");
   GlobalVariableDel(p + "SELL_RANGE");
   GlobalVariableDel(p + "GRANGE");
}

#endif
