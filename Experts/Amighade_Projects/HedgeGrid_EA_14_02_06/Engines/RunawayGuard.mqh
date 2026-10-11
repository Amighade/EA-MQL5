#ifndef RUNAWAY_GUARD_MQH
#define RUNAWAY_GUARD_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "GridBuilder.mqh"
#include "SLManager.mqh"
#include "CleanupReset.mqh"

double GetRunawayLevelSLDistance( double spread, double minStop)
{
   switch(InpRunawaySLMode)
     {
      case RA_SL_TIGHT:        return spread + minStop;
      case RA_SL_GRID_SPACING: return InpGridSpacing * InpRunawaySLRangeFraction;
      case RA_SL_GAP_FRAC:     return InpInitialGap * InpRunawaySLRangeFraction;
      default:                    return 0.0;   // RA_SL_NONE
     }
}

// Call once per processed opening deal.
void UpdateRunawayStreak(GridState &state,
                         ENUM_ORDER_TYPE fillDirection)
{
   if(fillDirection != ORDER_TYPE_BUY &&
      fillDirection != ORDER_TYPE_SELL)
      return;

   if(fillDirection == state.runawayStreakDirection)
      state.runawayStreakCount++;
   else
     {
      state.runawayStreakDirection = fillDirection;
      state.runawayStreakCount = 1;
      state.runawayTriggered = false;
     }
}

// Returns: 1 = armed, 0 = not armed, -1 = safety stop occurred.
int ArmRunawaySL(GridState &state)
{
   ENUM_POSITION_TYPE side =
      (state.runawayStreakDirection == ORDER_TYPE_BUY)
      ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

   double anchor = SL_GetAnchorPrice(state, side,
                                    state.magicNumber);
   double slLevel = 0.0;
   double minStop = MinStopDistancePrice(_Symbol);
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;

   // Same price rules as normal SL selection, without its profit gate.
   double SLDistance = GetRunawayLevelSLDistance(spread, minStop);

   if(SLDistance <= 0.0)
      return -1;

   slLevel = (state.runawayStreakDirection == ORDER_TYPE_BUY) ? anchor - SLDistance : anchor + SLDistance;

   if(!SL_BrokerOK(side, slLevel))
      return -1;

   SnapshotWinners(state.magicNumber, side);

   if(ArraySize(g_ArmedWinnerTickets) == 0)
      return 0;

   int applied = ApplySLToWinners(slLevel, state);

   if(applied < 0)
      return -1; // ApplySLToWinners already triggered safety closing.

   if(applied == 0)
      return 0;

   state.slWallArmed = true;
   state.slApplied = true;
   state.slLevel = slLevel;
   state.slWinnerSide = (int)side;

   LogDebug(StringFormat(
      "[RunawayGuard] SL armed on %s side. SL=%.5f Applied=%d",
      side == POSITION_TYPE_BUY ? "BUY" : "SELL",
      slLevel, applied));

   return 1;
}

// Returns false when the caller must stop further strategy work.
bool ProcessRunawayGuard(GridState &state)
{
   if(state.cleanupInProgress)
      return false;

   if(state.runawayTriggered || state.slWallArmed)
      return true;

   if(state.runawayStreakDirection != ORDER_TYPE_BUY &&
      state.runawayStreakDirection != ORDER_TYPE_SELL)
      return true;

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

   if(!conditionMet)
      return true;

   switch(InpRunawayAction)
     {
      case RUNAWAY_ACTION_ADD_SL:
        {
         int result = ArmRunawaySL(state);

         if(result < 0)
            {
            StartCleanupSequence(state);
            return false;
            }
         if(result > 0)
            state.runawayTriggered = true;

         // Unsuccessful arming can retry on a later opening fill.
         return true;
        }

      case RUNAWAY_ACTION_CLOSE_ALL:
         LogDebug("[RunawayGuard] Trigger reached; starting cleanup.");
         StartCleanupSequence(state);
         state.runawayTriggered = true;
         return false;
     }

   return true;
}

void ResetRunawayGuard(GridState &state)
{
   state.runawayStreakCount = 0;
   state.runawayStreakDirection = (ENUM_ORDER_TYPE)WRONG_VALUE;
   state.runawayTriggered = false;
}

#endif