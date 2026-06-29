//+------------------------------------------------------------------+
//| PlacementEngine.mqh                                               |
//| Breakout order placement and pending order management            |
//+------------------------------------------------------------------+
#ifndef CMO_PLACEMENT_ENGINE_MQH
#define CMO_PLACEMENT_ENGINE_MQH

#include "../Inputs.mqh"
#include "../Models/EAState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/CandleUtils.mqh"
#include "EntryEngine.mqh"
#include "LotEngine.mqh"
#include "ResetEngine.mqh"

//+------------------------------------------------------------------+
//| Manage existing pending orders — cancel wrong side, modify price |
//+------------------------------------------------------------------+
void ManageOpenPendingOrder(PosLists &poslists)
{
   int nWNSL    = ArraySize(poslists.lstWNSL);
   SortByOpenTimeAscending(poslists.lstWNSL);

   // Determine expected pending type based on last unprotected position
   ENUM_ORDER_TYPE expectedType = (ENUM_ORDER_TYPE)-1;
   if(nWNSL > 0)
     {
      int lastSide = poslists.lstWNSL[nWNSL-1].type;
      expectedType = (lastSide==POSITION_TYPE_BUY ? ORDER_TYPE_SELL_STOP : ORDER_TYPE_BUY_STOP);
     }

   int total = OrdersTotal();
   for(int i = total-1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;

      long type = OrderGetInteger(ORDER_TYPE);
      if(type!=ORDER_TYPE_BUY_STOP && type!=ORDER_TYPE_SELL_STOP) continue;

      // Cancel wrong-side pending
      if(expectedType!=(ENUM_ORDER_TYPE)-1 && type!=expectedType)
        {
         if(EnableDebugLogs)
            PrintFormat("[PlacementEngine] Cancel wrong-side pending ticket=%I64u type=%d expected=%d",
                        ticket, type, expectedType);
         CancelPendingOrder(ticket);
         continue;
        }

      // Modify price/lot if needed
      double oldPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      double oldLot   = OrderGetDouble(ORDER_VOLUME_CURRENT);
      double oldSL    = OrderGetDouble(ORDER_SL);
      double oldTP    = OrderGetDouble(ORDER_TP);
      double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double spread   = ask - bid;

      // Recompute entry
      long   ptype    = type;
      double buyEntry = 0.0, sellEntry = 0.0;
      ComputeEntry(buyEntry, sellEntry, poslists, ptype);

      double newEntry = (type==ORDER_TYPE_BUY_STOP) ?
                        ClampPendingEntry(_Symbol, ORDER_TYPE_BUY_STOP,  buyEntry) :
                        ClampPendingEntry(_Symbol, ORDER_TYPE_SELL_STOP, sellEntry);
      newEntry = AlignToTick(_Symbol, newEntry);

      double newLot = ComputeNextLotSizeINC_EntryAware((ENUM_ORDER_TYPE)type, newEntry, poslists);
      if(newLot <= 0) continue;

      bool priceDiff = false;
      if(type==ORDER_TYPE_BUY_STOP)
         priceDiff = !NearlyEqualPrice(newEntry,oldPrice,spread) && (newEntry<oldPrice);
      else
         priceDiff = !NearlyEqualPrice(newEntry,oldPrice,spread) && (newEntry>oldPrice);

      bool lotDiff = !NearlyEqualVol(newLot, oldLot);

      if(!priceDiff && !lotDiff) continue;

      if(!lotDiff)
        {
         ModifyPendingOrderWithWidening(ticket, _Symbol, (ENUM_ORDER_TYPE)type,
                                        newEntry, oldSL, oldTP);
         continue;
        }

      // Replace with new lot
      TradeActionResult placed = PlacePendingOrderWithWidening(
         _Symbol, (ENUM_ORDER_TYPE)type, newLot, newEntry, 0.0, 0.0);
      if(placed.success)
         CancelPendingOrder(ticket);
     }
}

//+------------------------------------------------------------------+
//| Place breakout orders based on trend and position state          |
//+------------------------------------------------------------------+
void PlaceBreakoutOrders(const string sym, PosLists &poslists)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread  = ask - bid;
   double minStop = (double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   int nAll      = ArraySize(poslists.lstAll);
   int nAllDeals = ArraySize(poslists.lstAllDeals);
   SortByOpenTimeAscending(poslists.lstAllDeals);

   long last_position_type = (nAllDeals > 0) ? poslists.lstAllDeals[nAllDeals-1].type : -1;

   ENUM_ORDER_TYPE ptype = (ENUM_ORDER_TYPE)-1;
   double buyEntry = 0.0, sellEntry = 0.0;
   ComputeEntry(buyEntry, sellEntry, poslists, ptype);

   // Validate entries
   if(buyEntry  <= ask + minStop) buyEntry  = ask + minStop + spread;
   if(sellEntry >= bid - minStop) sellEntry = bid - minStop - spread;

   double lot = ComputeNextLotSizeINC(ptype, buyEntry, sellEntry, poslists);
   if(lot <= 0) return;

   ENUM_ORDER_TYPE pendingType  = (ENUM_ORDER_TYPE)-1;
   double          pendLot      = 0.0;
   double          pendEntry    = 0.0;
   bool            wantOrder    = false;

   // Case 1: No positions, downtrend → place BUY
   if(nAllDeals==0 && IsDownTrend())
     { pendingType=ORDER_TYPE_BUY_STOP;  pendLot=lot; pendEntry=buyEntry;  wantOrder=true; }
   // Case 2: No positions, uptrend → place SELL
   else if(nAllDeals==0 && IsUpTrend())
     { pendingType=ORDER_TYPE_SELL_STOP; pendLot=lot; pendEntry=sellEntry; wantOrder=true; }
   // Case 5: Last position is SELL → place BUY
   else if(nAllDeals!=0 && last_position_type==POSITION_TYPE_SELL)
     { pendingType=ORDER_TYPE_BUY_STOP;  pendLot=lot; pendEntry=buyEntry;  wantOrder=true; }
   // Case 6: Last position is BUY → place SELL
   else if(nAllDeals!=0 && last_position_type==POSITION_TYPE_BUY)
     { pendingType=ORDER_TYPE_SELL_STOP; pendLot=lot; pendEntry=sellEntry; wantOrder=true; }

   if(!wantOrder) return;

   TradeActionResult placeRes = PlacePendingOrderWithWidening(
      _Symbol, pendingType, pendLot, pendEntry, 0.0, 0.0);

   if(placeRes.success) return;

   if(EnableDebugLogs)
      PrintFormat("[PlacementEngine] Placement failed rc=%u lastErr=%d",
                  placeRes.retcode, placeRes.lastError);

   // Fatal failure → close current range
   SendFailAction action = ClassifySendFailure(placeRes.sent,
                                               (MqlTradeResult){placeRes.retcode},
                                               placeRes.lastError);
   if(action == FAIL_FATAL)
      CloseCurrentRangeNonEpoch();
}

#endif
