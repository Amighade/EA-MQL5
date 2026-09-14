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
//| Check for gap fault — order should have been hit but was skipped |
//| Returns ticket of skipped order (0 if clean) and writes the      |
//| expected fill price into expectedPrice BEFORE the caller does     |
//| anything else that might deselect/delete the order.               |
//+------------------------------------------------------------------+
ulong CheckGapFault(double currentPrice, int magicNumber, double &expectedPrice)
  {
   expectedPrice = 0.0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;

      double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(orderType == ORDER_TYPE_BUY_STOP && currentPrice > orderPrice + InpGridSpacing)
        { expectedPrice = orderPrice; return ticket; }

      if(orderType == ORDER_TYPE_SELL_STOP && currentPrice < orderPrice - InpGridSpacing)
        { expectedPrice = orderPrice; return ticket; }
     }
   return 0;
  }

//+------------------------------------------------------------------+
//| [REV-2026-09-12-BACKBONE]                                          |
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

   if(state.slWallArmed)
     {
      bool isWinnerSide = ((int)side == state.slWinnerSide);
      if(isWinnerSide) return;                 // frozen -- trailing owns this side now
      if(InpCloseLosersAtArm) return;           // losers purged -- nothing left to track
      // else: losers intentionally left open -- fall through, keep tracking
     }

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
bool ProcessOrderFill(ulong positionTicket, GridState &state)
  {
   if(!PositionSelectByTicket(positionTicket)) return false;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
   if(PositionGetInteger(POSITION_MAGIC) != state.magicNumber) return false;

   ENUM_POSITION_TYPE posType   = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double             lot       = PositionGetDouble(POSITION_VOLUME);
   double             fillPrice = PositionGetDouble(POSITION_PRICE_OPEN);

   ENUM_ORDER_TYPE hitDirection = (posType == POSITION_TYPE_BUY) ?
                                   ORDER_TYPE_BUY : ORDER_TYPE_SELL;

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

   LogOrderFilled(positionTicket,
                  posType == POSITION_TYPE_BUY ? "BUY" : "SELL",
                  lot, fillPrice);

   return switched;
  }

#endif
