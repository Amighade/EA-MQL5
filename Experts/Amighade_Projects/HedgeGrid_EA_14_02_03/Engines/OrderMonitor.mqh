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
bool UpdateSideVolumeAggregate_old(GridState &state, ulong dealTicket)
{
   if(!HistoryDealSelect(dealTicket))
      return false;

   long typeValue, entryValue;
   double lot;

   if(!HistoryDealGetInteger(dealTicket, DEAL_TYPE, typeValue) ||
      !HistoryDealGetInteger(dealTicket, DEAL_ENTRY, entryValue) ||
      !HistoryDealGetDouble(dealTicket, DEAL_VOLUME, lot))
      return false;

   ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)typeValue;
   ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)entryValue;

   if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL)
      return true;

   bool isOpen = (dealEntry == DEAL_ENTRY_IN);
   bool isClose = (dealEntry == DEAL_ENTRY_OUT ||
                   dealEntry == DEAL_ENTRY_OUT_BY);

   // Netting reversals require separate close/open accounting.
   if(!isOpen && !isClose)
      return false;

   if(lot <= 0)
      return false;

   double entryPrice = 0;

   if(isOpen)
   {
      if(!HistoryDealGetDouble(dealTicket, DEAL_PRICE, entryPrice))
         return false;
   }
   else
   {
      long positionId, closeTime;

      if(!HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID, positionId) ||
         !HistoryDealGetInteger(dealTicket, DEAL_TIME_MSC, closeTime))
         return false;

      if(positionId <= 0 ||
         !HistorySelectByPosition((ulong)positionId))
         return false;

      double openingVolume = 0;
      double openingValue = 0;

      ENUM_DEAL_TYPE openingType =
         (dealType == DEAL_TYPE_BUY) ? DEAL_TYPE_SELL : DEAL_TYPE_BUY;

      int total = HistoryDealsTotal();

      for(int i = 0; i < total; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0)
            return false;

         long historyEntry, historyType, historyTime;

         if(!HistoryDealGetInteger(ticket, DEAL_ENTRY, historyEntry) ||
            !HistoryDealGetInteger(ticket, DEAL_TYPE, historyType) ||
            !HistoryDealGetInteger(ticket, DEAL_TIME_MSC, historyTime))
            return false;

         if(historyEntry != DEAL_ENTRY_IN ||
            historyType != openingType)
            continue;

         // Exclude opening fills later than this closing deal.
         if(historyTime > closeTime ||
            (historyTime == closeTime && ticket >= dealTicket))
            continue;

         double fillVolume, fillPrice;

         if(!HistoryDealGetDouble(ticket, DEAL_VOLUME, fillVolume) ||
            !HistoryDealGetDouble(ticket, DEAL_PRICE, fillPrice))
            return false;

         if(fillVolume <= 0 || fillPrice <= 0)
            return false;

         openingVolume += fillVolume;
         openingValue += fillVolume * fillPrice;
      }

      if(openingVolume <= 0)
         return false;

      entryPrice = openingValue / openingVolume;
   }

   if(entryPrice <= 0)
      return false;

   ENUM_POSITION_TYPE side =
      (dealType == DEAL_TYPE_BUY)
      ? (isOpen ? POSITION_TYPE_BUY : POSITION_TYPE_SELL)
      : (isOpen ? POSITION_TYPE_SELL : POSITION_TYPE_BUY);

   double volume = (side == POSITION_TYPE_BUY)
                   ? state.buyVolume : state.sellVolume;

   double average = (side == POSITION_TYPE_BUY)
                    ? state.buyAvgEntry : state.sellAvgEntry;

   if(!isOpen && lot > volume + 0.0000001)
      return false;

   double newVolume = isOpen ? volume + lot : volume - lot;
   double newAverage = 0;

   if(newVolume <= 0.0000001)
      newVolume = 0;
   else
   {
      double value = volume * average;
      value += (isOpen ? 1.0 : -1.0) * lot * entryPrice;
      newAverage = value / newVolume;

      if(newAverage <= 0)
         return false;
   }

   // Commit only after all required data has been obtained.
   if(side == POSITION_TYPE_BUY)
   {
      state.buyVolume = newVolume;
      state.buyAvgEntry = newAverage;
   }
   else
   {
      state.sellVolume = newVolume;
      state.sellAvgEntry = newAverage;
   }

   return true;
}


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
