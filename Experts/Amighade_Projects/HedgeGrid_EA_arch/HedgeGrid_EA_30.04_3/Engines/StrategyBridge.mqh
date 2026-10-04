#ifndef STRATEGY_BRIDGE_MQH
#define STRATEGY_BRIDGE_MQH

#include "../Models/GridState.mqh"
#include "../Models/TransactionItem.mqh"

//+------------------------------------------------------------------+
//| REV 30.04 STRATEGY BOUNDARY                                      |
//|                                                                  |
//| The infrastructure stops here. The exact Rev 22.2 strategy is   |
//| included under Reference_Rev22_2/ for comparison.                |
//|                                                                  |
//| When strategy bricks are migrated, they should be called from    |
//| these few readable functions. Async broker details must stay out |
//| of the strategy modules.                                         |
//+------------------------------------------------------------------+

void Strategy_OnEntryFill(GridState &state,
                          int itemIndex,
                          TransactionItem &tx)
  {
   // Rev 22.2 reference sequence after DEAL_ENTRY_IN:
   //   1) ProcessOrderFill(positionTicket, state)
   //   2) ReSnapshotIfArmed(state)
   //   3) UpdateOppositeGrid(state)
   //   4) ProcessInsideStrategy(state)
   //   5) state.outsideRefillPending = true
   //   6) ProcessSLManager(state)
   //   7) LogHistory(...)
   //
   // Intentionally not enabled in Rev 30.04. This revision exists so the
   // data path can be reviewed before strategy bricks are inserted.
  }

void Strategy_OnExitDeal(GridState &state,
                         int itemIndex,
                         TransactionItem &tx)
  {
   // Rev 22.2 treated non-cleanup exits as a reason to start full cleanup.
   // Put that policy here if desired; infrastructure never infers whole-cycle cleanup.
  }

void Strategy_Fast_pattern(GridState &state)
  {
   // Future home for cheap/high-frequency strategy decisions, e.g. SL checks.
  }
void Strategy_Fast(GridState &state)
  {
   static uint testItemId = 0;
   static bool deleteRequested = false;
   static bool testFinished = false;

   if(!InpRunAsyncRoundTripTest || testFinished ||
      state.lifecycle == GRID_CLEANUP || state.safetyStopPending)
      return;

   // Create exactly one test pending order.
   if(testItemId == 0)
     {
      MqlTick quote = {};
      if(!SymbolInfoTick(_Symbol, quote)) return;

      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize <= 0.0) tickSize = _Point;

      long stopPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double rawPrice = quote.ask + (stopPoints + 10) * _Point;
      double price = NormalizeDouble(MathCeil(rawPrice / tickSize) * tickSize, _Digits);
      double lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

      testItemId = RequestPlacePending(state, ORDER_TYPE_BUY_STOP, price, lot);
      if(testItemId == 0)
        {
         Print("[ASYNC TEST] Could not create test order item.");
         testFinished = true;
        }
      return;
     }

   int idx = FindItemById(state, testItemId);

   // Reconciliation removed the item after the delete was confirmed.
   if(idx < 0)
     {
      Print(deleteRequested
            ? "[ASYNC TEST] PASS: pending order placed and deleted."
            : "[ASYNC TEST] FAIL: test item disappeared before delete.");
      testFinished = true;
      return;
     }

   if(state.items[idx].actionStatus == ACTION_FAILED)
     {
      PrintFormat("[ASYNC TEST] FAIL: action rejected, retcode=%d.",
                  state.items[idx].lastRetcode);
      testFinished = true;
      return;
     }

   // Request deletion only after the broker confirms the order is live
   // and the PLACE action has completed.
   if(!deleteRequested &&
      state.items[idx].kind == ITEM_ORDER &&
      state.items[idx].brokerPresent &&
      state.items[idx].action == ACTION_NONE &&
      state.items[idx].actionStatus == ACTION_IDLE &&
      state.items[idx].orderTicket > 0)
      deleteRequested = RequestDeleteOrder(state, state.items[idx].orderTicket);
  }
void Strategy_Medium(GridState &state)
  {
   // Future home for grid lifecycle / refill / structural strategy decisions.
  }

void Strategy_Background(GridState &state)
  {
   // Future home for low-priority diagnostics only.
  }

#endif
