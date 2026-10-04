#ifndef STRATEGY_BRIDGE_MQH
#define STRATEGY_BRIDGE_MQH

#include "../Models/GridState.mqh"
#include "../Models/TransactionItem.mqh"

//+------------------------------------------------------------------+
//| REV 30.01 STRATEGY BOUNDARY                                      |
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
   // Intentionally not enabled in Rev 30.01. This revision exists so the
   // data path can be reviewed before strategy bricks are inserted.
  }

void Strategy_OnExitDeal(GridState &state,
                         int itemIndex,
                         TransactionItem &tx)
  {
   // Rev 22.2 treated non-cleanup exits as a reason to start full cleanup.
   // The exact policy will be connected here after the user reviews 30.01.
  }

void Strategy_Fast(GridState &state)
  {
   // Future home for cheap/high-frequency strategy decisions, e.g. SL checks.
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
