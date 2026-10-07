#ifndef RUNAWAY_GUARD_MQH
#define RUNAWAY_GUARD_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "GridBuilder.mqh"
#include "SLManager.mqh"
#include "CleanupReset.mqh"

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
   if(InpRunawaySLArmMode == SL_NONE)
      return 0;

   ENUM_POSITION_TYPE side =
      (state.runawayStreakDirection == ORDER_TYPE_BUY)
      ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

   double anchor = SL_GetAnchorPrice(state, side,
                                    state.magicNumber);
   double currentSL = state.slLevel;
   double slLevel = 0.0;

   // Same price rules as normal SL selection, without its profit gate.
   switch(InpRunawaySLArmMode)
     {
      case SL_P_LEVEL:
        {
         double minStop = MinStopDistancePrice(_Symbol);
         slLevel = (side == POSITION_TYPE_BUY)
                   ? SymbolInfoDouble(_Symbol, SYMBOL_BID) - minStop
                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK) + minStop;
        }
         break;

      case SL_FIRST_GRID:
         slLevel = SL_GetGridLevel(anchor, 1, side);
         break;

      case SL_NEAREST_P_GRID:
      case SL_FAREST_P_GRID:
        {
         bool nearFirst = (InpRunawaySLArmMode == SL_NEAREST_P_GRID);
         int start = nearFirst ? 1 : InpSLNBack;
         int stop  = nearFirst ? InpSLNBack : 1;
         int step  = nearFirst ? 1 : -1;

         if(InpSLNBack < 1)
            return 0;

         for(int n = start;
             nearFirst ? (n <= stop) : (n >= stop);
             n += step)
           {
            double candidate = SL_GetGridLevel(anchor, n, side);

            if(candidate <= 0.0)
               continue;
            if(!SL_IsProgress(side, candidate, currentSL))
               continue;
            if(!SL_BrokerOK(side, candidate))
               continue;

            slLevel = candidate;
            break;
           }
        }
         break;

      default:
         return 0;
     }

   if(slLevel <= 0.0)
      return 0;
   if(!SL_IsProgress(side, slLevel, currentSL))
      return 0;
   if(!SL_BrokerOK(side, slLevel))
      return 0;

   SnapshotWinners(state.magicNumber, side);

   if(ArraySize(g_ArmedWinnerTickets) == 0)
      return 0;

   int applied = ApplySLToWinners(slLevel, state);

   if(applied < 0)
      return -1; // ApplySLToWinners already triggered safety closing.

   if(applied == 0)
      return 0;

   // Read actual protection rather than storing an adjusted request price.
   double actualSL = 0.0;

   for(int i = 0; i < ArraySize(g_ArmedWinnerTickets); i++)
     {
      if(!PositionSelectByTicket(g_ArmedWinnerTickets[i]))
         continue;

      double positionSL = PositionGetDouble(POSITION_SL);
      if(positionSL <= 0.0)
         continue;

      // Track the least protective SL among the protected positions.
      if(actualSL == 0.0)
         actualSL = positionSL;
      else if(side == POSITION_TYPE_BUY)
         actualSL = MathMin(actualSL, positionSL);
      else
         actualSL = MathMax(actualSL, positionSL);
     }

   if(actualSL <= 0.0)
      return 0;

   state.slWallArmed = true;
   state.slApplied = true;
   state.slLevel = actualSL;
   state.slWinnerSide = (int)side;

   LogDebug(StringFormat(
      "[RunawayGuard] SL armed on %s side. SL=%.5f Applied=%d",
      side == POSITION_TYPE_BUY ? "BUY" : "SELL",
      actualSL, applied));

   return 1;
}

// Returns false when the caller must stop further strategy work.
bool ProcessRunawayGuard(GridState &state)
{
   if(state.cleanupInProgress)
      return false;

   if(InpRunawayTrigger == RUNAWAY_TRIGGER_NONE ||
      InpRunawayN <= 0)
      return true;

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
            return false;

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