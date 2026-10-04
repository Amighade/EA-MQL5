#ifndef STRATEGY_BRIDGE_MQH
#define STRATEGY_BRIDGE_MQH

#include "../Models/GridState.mqh"
#include "../Models/TransactionItem.mqh"

const int GRID_CLEANUP_TEST_LEVEL = -31000;

void StartCleanup(GridState &state, string reason);

bool g_gridCleanupTestFillSeen = false;
bool g_gridCleanupTestFailed = false;

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
   if(InpRunGridCleanupTest && itemIndex >= 0 &&
      itemIndex < ArraySize(state.items) &&
      state.items[itemIndex].level == GRID_CLEANUP_TEST_LEVEL)
     {
      g_gridCleanupTestFillSeen = true;
      PrintFormat("[GRID TEST] Fill: deal=%I64u sourceOrder=%I64u position=%I64u; starting cleanup.",
                  tx.dealTicket, tx.orderTicket, tx.positionTicket);
      StartCleanup(state, "Grid cleanup test: first pending order filled");
      return;
     }

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

void Strategy_Fast(GridState &state)
  {
   static bool testStarted = false;
   static bool testFinished = false;

   if(!InpRunGridCleanupTest || testFinished) return;

   // Report a completed test only after cleanup has reset the cycle and the
   // terminal confirms that this EA owns no live positions or pending orders.
   if(testStarted)
     {
      // If a position appeared in a broker scan before its DEAL callback was
      // consumed, the test still starts cleanup from the confirmed live item.
      if(!g_gridCleanupTestFillSeen && !g_gridCleanupTestFailed)
         for(int i = 0; i < ArraySize(state.items); i++)
            if(state.items[i].kind == ITEM_POSITION &&
               state.items[i].level == GRID_CLEANUP_TEST_LEVEL &&
               state.items[i].brokerPresent)
              {
               g_gridCleanupTestFillSeen = true;
               PrintFormat("[GRID TEST] Reconciled fill: position=%I64u; starting cleanup.",
                           state.items[i].positionTicket);
               StartCleanup(state, "Grid cleanup test: filled position found by reconciliation");
               break;
              }

      if(!g_gridCleanupTestFillSeen && !g_gridCleanupTestFailed)
         for(int i = 0; i < ArraySize(state.items); i++)
            if(state.items[i].level == GRID_CLEANUP_TEST_LEVEL &&
               state.items[i].actionStatus == ACTION_FAILED)
              {
               g_gridCleanupTestFailed = true;
               PrintFormat("[GRID TEST] Placement failed: item=%u retcode=%d; cleaning remaining test orders.",
                           state.items[i].id, state.items[i].lastRetcode);
               StartCleanup(state, "Grid cleanup test: pending order rejected");
               break;
              }

      if(state.lifecycle == GRID_IDLE && ArraySize(state.items) == 0 &&
         CountLiveTerminalPositions(state.magicNumber) == 0 &&
         CountLiveTerminalOrders(state.magicNumber) == 0)
        {
         if(g_gridCleanupTestFillSeen && !g_gridCleanupTestFailed)
            Print("[GRID TEST] PASS: a pending order filled; all EA positions and pending orders were removed.");
         else
            Print("[GRID TEST] FAIL: grid ended without a confirmed test fill; broker state is flat.");
         testFinished = true;
        }
      return;
     }

   // Do not mix the test grid with existing EA trades or another cycle.
   if(state.lifecycle != GRID_IDLE || ArraySize(state.items) > 0)
     {
      Print("[GRID TEST] Not started: EA trade book must be empty and idle.");
      testFinished = true;
      return;
     }

   MqlTick quote = {};
   if(!SymbolInfoTick(_Symbol, quote) || quote.ask <= 0.0 || quote.bid <= 0.0)
      return;

   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0) tickSize = _Point;
   double gap = 0.5;
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minimumOffset = (double)stopsLevel * _Point + tickSize;
   double firstOffset = MathCeil(MathMax(gap, minimumOffset) / gap) * gap;
   double lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lot <= 0.0) return;

   testStarted = true;
   int queued = 0;
   for(int level = 0; level < 3; level++)
     {
      double buyRaw = quote.ask + firstOffset + level * gap;
      double sellRaw = quote.bid - firstOffset - level * gap;
      double buyPrice = NormalizeDouble(MathCeil(buyRaw / tickSize - 1.0e-9) * tickSize, _Digits);
      double sellPrice = NormalizeDouble(MathFloor(sellRaw / tickSize + 1.0e-9) * tickSize, _Digits);

      uint buyId = RequestPlacePending(state, ORDER_TYPE_BUY_STOP, buyPrice, lot, 0.0, 0.0,
                                       GRID_CLEANUP_TEST_LEVEL);
      if(buyId > 0)
        {
         queued++;
         PrintFormat("[GRID TEST] Queued BUY_STOP item=%u price=%.2f lot=%.2f.",
                     buyId, buyPrice, lot);
        }
      uint sellId = RequestPlacePending(state, ORDER_TYPE_SELL_STOP, sellPrice, lot, 0.0, 0.0,
                                        GRID_CLEANUP_TEST_LEVEL);
      if(sellId > 0)
        {
         queued++;
         PrintFormat("[GRID TEST] Queued SELL_STOP item=%u price=%.2f lot=%.2f.",
                     sellId, sellPrice, lot);
        }
     }

   if(queued != 6)
     {
      g_gridCleanupTestFailed = true;
      PrintFormat("[GRID TEST] Could queue only %d of 6 orders; cleaning up.", queued);
      StartCleanup(state, "Grid cleanup test: could not build all pending orders");
      return;
     }

   PrintFormat("[GRID TEST] Queued 3 buy stops and 3 sell stops, gap=%.2f, lot=%.2f.",
               gap, lot);
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
