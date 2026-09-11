//+------------------------------------------------------------------+
//| SLManager.mqh                                                     |
//| SL trigger detection, level calculation and application          |
//+------------------------------------------------------------------+
#ifndef SL_MANAGER_MQH
#define SL_MANAGER_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
// Style C SL manager — included here so ProcessSLManager master can route to it
#include "StyleC/SLManager_C.mqh"

//+------------------------------------------------------------------+
//| Determine winning direction (higher floating profit)             |
//+------------------------------------------------------------------+
ENUM_POSITION_TYPE GetWinningDirection(GridState &state)
{
   double buyProfit  = CalculateDirectionProfit(POSITION_TYPE_BUY,  state.magicNumber);
   double sellProfit = CalculateDirectionProfit(POSITION_TYPE_SELL, state.magicNumber);

   state.basketBuyProfit  = buyProfit;
   state.basketSellProfit = sellProfit;

   return (buyProfit >= sellProfit) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
}

//+------------------------------------------------------------------+
//| Check if SL trigger conditions are met                           |
//+------------------------------------------------------------------+
bool CheckSLTrigger(GridState &state)
{
   if(state.slApplied) return false; // Already applied this cycle

   bool   triggered = false;
   string reason    = "";

   if(InpSLTriggerByLot && state.currentBlockLot >= InpSLTriggerLot)
     {
      triggered = true;
      reason    = StringFormat("LOT_THRESHOLD (%.2f >= %.2f)",
                               state.currentBlockLot, InpSLTriggerLot);
     }

   if(InpSLTriggerByProfit && state.basketProfit > 0)
     {
      triggered = true;
      reason    = StringFormat("PROFIT_POSITIVE (%.2f)", state.basketProfit);
     }

   if(triggered)
      LogSLTriggered(reason, 0);

   return triggered;
}

//+------------------------------------------------------------------+
//| Apply SL to qualifying positions on winning side                 |
//| Qualifying = price has passed position AND price favors direction |
//+------------------------------------------------------------------+
void ApplySLToPositions(ENUM_POSITION_TYPE winningDirection,
                        double slLevel,
                        GridState &state)
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int    appliedCount = 0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != state.magicNumber) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != winningDirection) continue;

      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      bool   qualifies  = false;

      if(winningDirection == POSITION_TYPE_BUY)
        {
         // BUY qualifies: price moved above entry AND SL is below entry
         qualifies = (currentPrice > entryPrice && slLevel < entryPrice);
        }
      else
        {
         // SELL qualifies: price moved below entry AND SL is above entry
         qualifies = (currentPrice < entryPrice && slLevel > entryPrice);
        }

      if(qualifies && ModifyPositionSL(ticket, slLevel))
         appliedCount++;
     }

   if(appliedCount > 0)
     {
      state.slApplied = true;
      state.slLevel   = slLevel;
      LogSLTriggered("SL_APPLIED", slLevel);
      LogDebug(StringFormat("SL applied to %d positions at %.2f", appliedCount, slLevel));
     }
}

//+------------------------------------------------------------------+
//| Master SL check and apply — call after every fill and on tick   |
//| Style C: routes to SLManager_C (ABWCL style arming + trailing)  |
//+------------------------------------------------------------------+
void ProcessSLManager(GridState &state)
{
   // Style C uses ABWCL-style SL manager — handled in SLManager_C.mqh
   if(InpStrategyStyle == STYLE_C)
     {
      ProcessSLManager_C(state);
      return;
     }

   state.basketProfit = CalculateBasketProfit(state.magicNumber);

   if(!CheckSLTrigger(state)) return;

   ENUM_POSITION_TYPE winningDir = GetWinningDirection(state);
   double slLevel = CalculateSLLevel(winningDir, state.magicNumber);

   if(slLevel <= 0) return;

   ApplySLToPositions(winningDir, slLevel, state);
}

#endif
