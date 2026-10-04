#ifndef STRATEGY_BRIDGE_MQH
#define STRATEGY_BRIDGE_MQH

#include "../Models/GridState.mqh"
#include "../Models/TransactionItem.mqh"
#include "StrategyGrid.mqh"
#include "StrategyProtection.mqh"

// Maps broker events and scheduler tiers to the strategy modules.
// Strategy modules set intents through Request...(); AsyncTrade sends them.

void Strategy_OnEntryFill(GridState &state,
                          int itemIndex,
                          TransactionItem &tx)
  {
   StrategyRecordEntry(state, itemIndex, tx);
  }

void Strategy_OnExitDeal(GridState &state,
                         int itemIndex,
                         TransactionItem &tx)
  {
   Strategy_OnExit(state, itemIndex, tx);
  }

void Strategy_Fast(GridState &state)
  {
   StrategyProcessSL(state);
  }

void Strategy_Medium(GridState &state)
  {
   Strategy_MediumGrid(state);
  }

void Strategy_Background(GridState &state)
  {
   // Future home for low-priority diagnostics only.
  }

#endif
