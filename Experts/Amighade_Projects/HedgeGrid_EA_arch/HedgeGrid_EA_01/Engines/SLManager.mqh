//+------------------------------------------------------------------+
//| SLManager.mqh                                                     |
//| SL trigger detection, SL level calculation, SL application       |
//+------------------------------------------------------------------+
#ifndef SL_MANAGER_MQH
#define SL_MANAGER_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"

//+------------------------------------------------------------------+
//| Determine the winning direction                                   |
//| Winning = direction with more positive floating profit            |
//+------------------------------------------------------------------+
ENUM_POSITION_TYPE GetWinningDirection(GridState &state)
  {
   double buyProfit  = CalculateDirectionProfit(POSITION_TYPE_BUY);
   double sellProfit = CalculateDirectionProfit(POSITION_TYPE_SELL);

   state.basketBuyProfit  = buyProfit;
   state.basketSellProfit = sellProfit;

   return (buyProfit >= sellProfit) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
  }

//+------------------------------------------------------------------+
//| Check if SL trigger conditions are met                           |
//| Returns true if SL should be applied                             |
//+------------------------------------------------------------------+
bool CheckSLTrigger(GridState &state)
  {
   if(state.slApplied) return false; // Already applied this cycle

   bool triggered = false;
   string triggerReason = "";

   // Trigger 1: Block lot reached threshold
   if(InpSLTriggerByLot && state.currentBlockLot >= InpSLTriggerLot)
     {
      triggered     = true;
      triggerReason = StringFormat("LOT_THRESHOLD (%.2f >= %.2f)",
                                   state.currentBlockLot, InpSLTriggerLot);
     }

   // Trigger 2: Basket profit positive
   if(InpSLTriggerByProfit && state.basketProfit > 0)
     {
      triggered     = true;
      triggerReason = StringFormat("PROFIT_POSITIVE (%.2f)", state.basketProfit);
     }

   if(triggered)
      LogSLTriggered(triggerReason, 0); // SL level logged separately after calculation

   return triggered;
  }

//+------------------------------------------------------------------+
//| Apply SL to all qualifying positions on winning side             |
//| Qualifying = price has passed position AND price favors position  |
//+------------------------------------------------------------------+
void ApplySLToPositions(ENUM_POSITION_TYPE winningDirection, double slLevel, GridState &state)
  {
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int    appliedCount = 0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)             continue;
      if(PositionGetInteger(POSITION_MAGIC)  != state.magicNumber)   continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != winningDirection) continue;

      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);

      // Check: price must have passed this position (position is in profit territory)
      // AND price is currently in favor of this position direction
      bool qualifies = false;
      if(winningDirection == POSITION_TYPE_BUY)
        {
         // BUY qualifies if current price > entry (price moved up past entry)
         // AND SL level is below entry (SL won't be instantly hit)
         qualifies = (currentPrice > entryPrice && slLevel < entryPrice);
        }
      else
        {
         // SELL qualifies if current price < entry (price moved down past entry)
         // AND SL level is above entry
         qualifies = (currentPrice < entryPrice && slLevel > entryPrice);
        }

      if(qualifies)
        {
         if(ModifyPositionSL(ticket, slLevel))
            appliedCount++;
        }
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
//| Master SL check and apply function                               |
//| Call this after every order fill and on every tick               |
//+------------------------------------------------------------------+
void ProcessSLManager(GridState &state)
  {
   // Update basket profit in state
   state.basketProfit = CalculateBasketProfit();

   if(!CheckSLTrigger(state)) return;

   // Determine winning side and calculate SL
   ENUM_POSITION_TYPE winningDir = GetWinningDirection(state);
   double slLevel = CalculateSLLevel(winningDir);

   if(slLevel <= 0) return; // Could not calculate valid SL

   ApplySLToPositions(winningDir, slLevel, state);
  }


#endif