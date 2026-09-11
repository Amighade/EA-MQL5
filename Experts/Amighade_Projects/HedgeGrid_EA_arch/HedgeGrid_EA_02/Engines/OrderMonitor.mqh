//+------------------------------------------------------------------+
//| OrderMonitor.mqh                                                  |
//| Detect filled orders via OnTradeTransaction                      |
//| Track hit direction, lot, price and pass counter                 |
//+------------------------------------------------------------------+
#ifndef ORDER_MONITOR_MQH
#define ORDER_MONITOR_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/DebugLogger.mqh"
#include "../Utils/TradeUtils.mqh"

//+------------------------------------------------------------------+
//| Check if a transaction is a relevant order fill for this EA      |
//| Returns true if the transaction is a position open from our EA   |
//+------------------------------------------------------------------+
bool IsRelevantFill(const MqlTradeTransaction &trans, int magicNumber)
  {
   // We only care about ORDER_STATE_FILLED on our symbol
   if(trans.type   != TRADE_TRANSACTION_ORDER_UPDATE) return false;
   if(trans.symbol != _Symbol)                        return false;

   // Check if order just got filled
   if(trans.order_state != ORDER_STATE_FILLED) return false;

   // Verify magic number by selecting the deal
   // At this point position is already open, check via deal history
   return true; // Magic check done in ProcessOrderFill
  }

//+------------------------------------------------------------------+
//| Check if this is a direction switch from previous hit            |
//| Returns true if direction changed                                 |
//+------------------------------------------------------------------+
bool IsDirectionSwitch(ENUM_ORDER_TYPE newDirection, GridState &state)
  {
   if(!state.cycleActive) return false; // First hit ever, not a switch

   // Compare new direction with last hit direction
   bool wasLastBuy  = (state.lastHitDirection == ORDER_TYPE_BUY);
   bool isNowBuy    = (newDirection == ORDER_TYPE_BUY_STOP ||
                       newDirection == ORDER_TYPE_BUY);

   return (wasLastBuy != isNowBuy);
  }

//+------------------------------------------------------------------+
//| Check for gap fault — order should have been hit but was skipped |
//| Compares current price against all pending orders of EA          |
//| Returns ticket of skipped order if fault found, 0 if clean      |
//+------------------------------------------------------------------+
ulong CheckGapFault(double currentPrice, int magicNumber)
  {
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;

      double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      // BUY STOP should have been hit if price passed above it
      if(orderType == ORDER_TYPE_BUY_STOP && currentPrice > orderPrice + InpGridSpacing)
         return ticket;

      // SELL STOP should have been hit if price passed below it
      if(orderType == ORDER_TYPE_SELL_STOP && currentPrice < orderPrice - InpGridSpacing)
         return ticket;
     }
   return 0;
  }

//+------------------------------------------------------------------+
//| Process a confirmed order fill                                    |
//| Updates GridState with hit info and pass counter                 |
//| Returns true if this was a direction switch                      |
//+------------------------------------------------------------------+
bool ProcessOrderFill(ulong positionTicket, GridState &state)
  {
   // Select the newly opened position
   if(!PositionSelectByTicket(positionTicket)) return false;

   // Verify this position belongs to our EA
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
   if(PositionGetInteger(POSITION_MAGIC) != state.magicNumber) return false;

   // Extract position info
   ENUM_POSITION_TYPE posType   = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double             lot       = PositionGetDouble(POSITION_VOLUME);
   double             fillPrice = PositionGetDouble(POSITION_PRICE_OPEN);

   // Determine order type from position type
   ENUM_ORDER_TYPE hitDirection = (posType == POSITION_TYPE_BUY) ?
                                   ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   // Check if this is a direction switch
   bool switched = IsDirectionSwitch(hitDirection, state);

   // Update pass counter on direction switch
   if(switched)
     {
      int oldCounter = state.passCounter;
      state.passCounter++;
      LogCounterUpdate(oldCounter, state.passCounter);
     }

   // Update last hit info
   state.lastHitDirection = hitDirection;
   state.lastHitLot       = lot;
   state.lastHitPrice     = fillPrice;
   state.lastHitTime      = TimeCurrent();
   state.lastHitTicket    = positionTicket;

   // Mark cycle as active after first fill
   if(!state.cycleActive)
      state.cycleActive = true;

   LogOrderFilled(positionTicket,
                  posType == POSITION_TYPE_BUY ? "BUY" : "SELL",
                  lot, fillPrice);

   return switched;
  }


#endif