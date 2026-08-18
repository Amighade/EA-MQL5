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
#include "../Utils/PositionOrderSnapshot.mqh"
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
   RefreshPositionSnapshot(state);
   
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
