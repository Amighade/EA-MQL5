#ifndef RUNAWAY_GUARD_MQH
#define RUNAWAY_GUARD_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "GridBuilder.mqh"
#include "SLManager.mqh"
#include "CleanupReset.mqh"

void ProcessRunawayGuard(GridState &state)
{
   if(InpRunawayN == 0 || InpRunawaySLArmMode == SL_NONE) return ;

   if(state.passCounter >= InpRunawayN)
      state.runawayTriggered = true;
}

void ResetRunawayGuard(GridState &state)
{
   state.runawayStreakCount = 0;
   state.runawayStreakDirection = (ENUM_ORDER_TYPE)WRONG_VALUE;
   state.runawayTriggered = false;
}

#endif