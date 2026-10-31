#ifndef RUNAWAY_GUARD_MQH
#define RUNAWAY_GUARD_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "GridBuilder.mqh"
#include "SLManager.mqh"
#include "CleanupReset.mqh"

// Returns false when the caller must stop further strategy work.
void ProcessRunawayGuard(GridState &state)
{
   if(InpRunawayN == 0 || InpRunawaySLArmMode == SL_NONE) return ;

   bool conditionMet = false;

   switch(InpRunawayTrigger)
     {
      case RUNAWAY_TRIGGER_CONSECUTIVE:
         conditionMet =
            (state.runawayStreakCount >= InpRunawayN &&
             state.passCounter == 0);
         break;

      case RUNAWAY_TRIGGER_GRID_DEPTH:
        {
         ENUM_POSITION_TYPE side =
            (state.runawayStreakDirection == ORDER_TYPE_BUY)
            ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

         conditionMet =
            (CountPositionType(side, state.magicNumber) >= InpRunawayN);
        }
         break;

      case RUNAWAY_TRIGGER_PASSCOUNTER:
         conditionMet = (state.passCounter >= InpRunawayN);
         break;
     }

   if(conditionMet)
   state.runawayTriggered = true;
}

void ResetRunawayGuard(GridState &state)
{
   state.runawayStreakCount = 0;
   state.runawayStreakDirection = (ENUM_ORDER_TYPE)WRONG_VALUE;
   state.runawayTriggered = false;
}

#endif