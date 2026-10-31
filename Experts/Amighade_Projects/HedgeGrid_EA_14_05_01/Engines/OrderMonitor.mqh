//+------------------------------------------------------------------+
//| OrderMonitor.mqh                                                  |
//| Process confirmed fills (DEAL_ADD / DEAL_ENTRY_IN) from the      |
//| coordinator. Tracks last-hit and farthest-hit info (the latter    |
//| feeds Brick 2's SHIFT_FARTHEST_HIT option) and the pass counter   |
//| (feeds Brick 1's lot-increase mode A).                            |
//|                                                                    |
//| Bug fix (minor #7): CheckGapFault now returns the expected price |
//| via an output parameter instead of the caller re-reading          |
//| OrderGetDouble after the order may already be gone.               |
//+------------------------------------------------------------------+
#ifndef ORDER_MONITOR_MQH
#define ORDER_MONITOR_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/DebugLogger.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/LevelVisitUtils.mqh"
//+------------------------------------------------------------------+
//| Check if this is a direction switch from previous hit            |
//+------------------------------------------------------------------+
bool IsDirectionSwitch(ENUM_ORDER_TYPE newDirection, GridState &state)
  {
   if(!state.cycleActive) return false; // First hit ever, not a switch

   bool wasLastBuy  = (state.lastHitDirection == ORDER_TYPE_BUY);
   bool isNowBuy    = (newDirection == ORDER_TYPE_BUY_STOP ||
                       newDirection == ORDER_TYPE_BUY);

   return (wasLastBuy != isNowBuy);
  }

//+------------------------------------------------------------------+
//| Incrementally maintain per-side {volume, avgEntry} from deal      |
//| history -- the O(1) input SideProfitAtPrice() needs. Called from  |
//| OnTradeTransaction for BOTH DEAL_ENTRY_IN (open) and OUT/INOUT/   |
//| OUT_BY (close) deals, any DEAL_REASON.                            |
//|                                                                    |
//| Side is derived from deal_type + dealEntry, not PositionGetInteger|
//| on the position ticket -- a fully-closing OUT deal can leave the  |
//| position unselectable by the time this runs, but a BUY deal       |
//| closing always means a SELL position (and vice versa), so this    |
//| works even then.                                                   |
//|                                                                    |
//| Winner side freezes once armed (trailing owns it via              |
//| g_ArmedWinnerTickets/SL orders, not this aggregate -- confirmed no |
//| live profit needed for trailing). Loser side keeps updating post- |
//| arm ONLY when InpCloseLosersAtArm is false (losers deliberately   |
//| left open) so SL_FindCandidate's net-check still sees them.       |
//+------------------------------------------------------------------+
void UpdateSideVolumeAggregate(GridState &state, ENUM_DEAL_TYPE dealType,
                               ENUM_DEAL_ENTRY dealEntry, double lot, double price)
{
   bool isOpen = (dealEntry == DEAL_ENTRY_IN);

   // A BUY deal opens/adds-to a BUY position, but CLOSES a SELL position
   // (and vice versa) -- this is why side can't just be "dealType".
   ENUM_POSITION_TYPE side;
   if(isOpen)
      side = (dealType == DEAL_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   else
      side = (dealType == DEAL_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;

   if(side == POSITION_TYPE_BUY)
     {
      if(isOpen)
        {
         double newVol = state.buyVolume + lot;
         if(newVol > 0) state.buyAvgEntry = (state.buyAvgEntry * state.buyVolume + price * lot) / newVol;
         state.buyVolume = newVol;
        }
      else
        {
         state.buyVolume -= lot;
         if(state.buyVolume <= 0.0000001) { state.buyVolume = 0; state.buyAvgEntry = 0; }
        }
     }
   else
     {
      if(isOpen)
        {
         double newVol = state.sellVolume + lot;
         if(newVol > 0) state.sellAvgEntry = (state.sellAvgEntry * state.sellVolume + price * lot) / newVol;
         state.sellVolume = newVol;
        }
      else
        {
         state.sellVolume -= lot;
         if(state.sellVolume <= 0.0000001) { state.sellVolume = 0; state.sellAvgEntry = 0; }
        }
     }
}
//+------------------------------------------------------------------+
//| Process a confirmed order fill                                    |
//| Updates GridState with hit info, pass counter, and farthest-hit  |
//| tracking. Returns true if this was a direction switch.           |
//+------------------------------------------------------------------+
bool ProcessOrderFill(ulong positionTicket, ENUM_DEAL_TYPE dealType,
                      double lot, double fillPrice, GridState &state)
  {
   if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL)
      return false;
   if(positionTicket == 0 || lot <= 0.0 || fillPrice <= 0.0)
      return false;

   ENUM_POSITION_TYPE posType = (dealType == DEAL_TYPE_BUY)
                                ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

   ENUM_ORDER_TYPE hitDirection = (dealType == DEAL_TYPE_BUY)
                                 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   bool switched = IsDirectionSwitch(hitDirection, state);

   if(switched)
     {
      int oldCounter = state.passCounter;
      state.passCounter++;
      LogCounterUpdate(oldCounter, state.passCounter);
     }

   state.prevHitPrice     = state.lastHitPrice;
   state.prevHitDirection = state.lastHitDirection;
 
   state.lastHitDirection  = hitDirection;
   state.lastHitLot        = lot;
   state.lastHitPrice      = fillPrice;
   state.lastHitTime       = TimeCurrent();
   state.lastHitTicket     = positionTicket;

   RegisterLevelVisit(state, fillPrice, posType == POSITION_TYPE_BUY ? 1 : 0, lot);

   // Farthest-hit tracking (Brick 2: SHIFT_FARTHEST_HIT)
   if(posType == POSITION_TYPE_BUY)
     {
      if(state.farthestHitBuy == 0.0 || fillPrice > state.farthestHitBuy)
         state.farthestHitBuy = fillPrice;
     }
   else
     {
      if(state.farthestHitSell == 0.0 || fillPrice < state.farthestHitSell)
         state.farthestHitSell = fillPrice;
     }

   if(!state.cycleActive)
      state.cycleActive = true;

   if(hitDirection == state.runawayStreakDirection)
      state.runawayStreakCount++;
   else
     {
      state.runawayStreakDirection = hitDirection;
      state.runawayStreakCount = 1;
      state.runawayTriggered = false;
     }
     
   LogOrderFilled(positionTicket,
                  posType == POSITION_TYPE_BUY ? "BUY" : "SELL",
                  lot, fillPrice);

   return switched;
  }

#endif
