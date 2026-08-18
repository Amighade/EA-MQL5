//+------------------------------------------------------------------+
//| RunawayGuard.mqh                                                  |
//| NEW ENGINE — protects against a grid that keeps growing one-      |
//| directionally without reversing (e.g. a strong trend feeding      |
//| Pass Refill / Revisit / outside-refill into ever more same-side   |
//| positions, none of them ever closing).                            |
//|                                                                    |
//| This is deliberately independent of the existing SL system        |
//| (SLManager.mqh / ArmSL / TrailWall): that system only ever fires   |
//| when state.basketProfit > 0 — it protects a WINNING side. This    |
//| guard exists for the opposite situation, where one side is        |
//| accumulating risk while likely underwater the whole time it       |
//| builds — the profit gate would never let the existing system      |
//| react to that case at all.                                        |
//|                                                                    |
//| Two independent choices, same separation-of-concerns pattern      |
//| used elsewhere in this codebase (inside maintenance vs. strategy, |
//| SL arm mode vs. trail mode):                                      |
//|   - InpRunawayTrigger : WHEN does this guard consider itself      |
//|                         triggered?                                 |
//|   - InpRunawayAction  : WHAT does it do once triggered?           |
//+------------------------------------------------------------------+
#ifndef RUNAWAY_GUARD_MQH
#define RUNAWAY_GUARD_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "GridBuilder.mqh"      // CountPositionType
#include "SLManager.mqh"        // SnapshotWinners, ApplySLToWinners, CalculateSLCandidate, g_ArmedWinnerTickets
#include "CleanupReset.mqh"     // StartCleanupSequence

//+------------------------------------------------------------------+
//| Call this on EVERY fill, unconditionally, regardless of which    |
//| inside style (if any) is active. This is what lets the guard see |
//| the true fill sequence rather than only what one particular      |
//| strategy brick happens to touch.                                  |
//|                                                                    |
//| A "streak" is N consecutive fills on the SAME side. Any fill on   |
//| the opposite side breaks the streak and starts a new one — this   |
//| also clears runawayTriggered, so the guard re-arms itself for the |
//| next time a runaway leg starts, rather than staying permanently   |
//| tripped after firing once.                                        |
//+------------------------------------------------------------------+
void UpdateRunawayStreak(GridState &state, ENUM_ORDER_TYPE fillDirection)
{
   if(fillDirection == state.runawayStreakDirection)
     {
      state.runawayStreakCount++;
     }
   else
     {
      state.runawayStreakDirection = fillDirection;
      state.runawayStreakCount     = 1;
      state.runawayTriggered       = false;   // streak broke — re-arm
     }
}

//+------------------------------------------------------------------+
//| Places an SL behind the runaway side, unconditionally — no       |
//| basketProfit gate, unlike ArmSL. Reuses the exact same            |
//| snapshot-and-apply mechanism ArmSL already uses (SnapshotWinners  |
//| + ApplySLToWinners), just fed the runaway side explicitly instead |
//| of GetWinningDirection()'s result, since the runaway side is      |
//| very likely the LOSING side, not the winning one.                |
//|                                                                    |
//| SL price comes from CalculateSLCandidate using InpSLArmMode — the |
//| same arm-mode search logic (Mode 1/2/3) already built for the     |
//| normal SL system, just applied here to a different side under a   |
//| different trigger. Once this SL is hit, the existing "any close   |
//| triggers cleanup" logic in OnTradeTransaction (HedgeGrid.mq5)     |
//| takes over automatically — nothing extra needed here for that.   |
//+------------------------------------------------------------------+
void ArmRunawaySL(GridState &state)
{
   ENUM_POSITION_TYPE runawaySide = (state.runawayStreakDirection == ORDER_TYPE_BUY) ?
                                     POSITION_TYPE_BUY : POSITION_TYPE_SELL;

   double slLevel = CalculateSLCandidate(runawaySide, state.magicNumber, InpSLArmMode);
   if(slLevel <= 0)
     {
      LogDebug("[RunawayGuard] Could not compute a valid SL candidate — skipped this attempt.");
      return;
     }

   SnapshotWinners(state.magicNumber, runawaySide);   // despite the name, this just snapshots
                                                        // every open position of the given side —
                                                        // "winners" is SLManager's own terminology,
                                                        // reused here for a losing/runaway side
   if(ArraySize(g_ArmedWinnerTickets) == 0)
     {
      LogDebug("[RunawayGuard] No positions found on the runaway side to protect — skipped.");
      return;
     }

   int applied = ApplySLToWinners(slLevel, state);
   if(applied <= 0)
     {
      LogDebug("[RunawayGuard] ApplySLToWinners placed 0 SLs — broker may have rejected all of them.");
      return;
     }

   state.slWallArmed  = true;
   state.slApplied    = true;
   state.slLevel      = slLevel;
   state.slWinnerSide = (int)runawaySide;

   LogDebug(StringFormat("[RunawayGuard] SL armed behind runaway %s side at %.5f (%d positions).",
                         runawaySide == POSITION_TYPE_BUY ? "BUY" : "SELL", slLevel, applied));
}

//+------------------------------------------------------------------+
//| Main entry point — call once per fill, AFTER UpdateRunawayStreak  |
//| has already been called for that same fill.                       |
//+------------------------------------------------------------------+
void ProcessRunawayGuard(GridState &state)
{
   if(InpRunawayTrigger == RUNAWAY_TRIGGER_NONE) return;
   if(state.runawayTriggered) return;
   if(state.slWallArmed)       return;   // normal SL system already has an SL armed — don't fight it
   if(state.cleanupInProgress) return;   // closing already outranks everything else

   bool conditionMet = false;

   switch(InpRunawayTrigger)
     {
      //--------------------------------------------------------------
      // TRIGGER 1: N consecutive fills on the same side, no reversal
      // in between. Most direct reading of "runaway" — literally a
      // one-directional streak, regardless of what grid depth or
      // passCounter value that streak happens to correspond to.
      //--------------------------------------------------------------
      case RUNAWAY_TRIGGER_CONSECUTIVE:
         conditionMet = (state.runawayStreakCount >= InpRunawayN
                           & state.passCounter == 0);
         break;

      //--------------------------------------------------------------
      // TRIGGER 2: total open position COUNT on the runaway side has
      // reached N. Not the same as "N consecutive" — this counts ALL
      // open positions on that side regardless of whether the streak
      // was interrupted along the way, so it can trigger even after
      // some back-and-forth, as long as enough positions have piled
      // up on one side overall.
      //--------------------------------------------------------------
      case RUNAWAY_TRIGGER_GRID_DEPTH:
        {
         ENUM_POSITION_TYPE side = (state.runawayStreakDirection == ORDER_TYPE_BUY) ?
                                    POSITION_TYPE_BUY : POSITION_TYPE_SELL;
         conditionMet = (CountPositionType(side, state.magicNumber) >= InpRunawayN);
        }
         break;

      //--------------------------------------------------------------
      // TRIGGER 3: state.passCounter (shared with Brick 1 lot-increase
      // and Brick 3 Pass Refill — see the field's comment in
      // GridState.mqh) has reached N reversals. Only meaningful if
      // Pass Refill or Mode A lot-increase is actually the active
      // strategy, since passCounter only moves when one of those is
      // running.
      //--------------------------------------------------------------
      case RUNAWAY_TRIGGER_PASSCOUNTER:
         conditionMet = (state.passCounter >= InpRunawayN);
         break;
     }

   if(!conditionMet) return;

   state.runawayTriggered = true;   // set BEFORE acting, so a re-entrant
                                     // call during the action itself
                                     // (e.g. StartCleanupSequence firing
                                     // more events) can't re-trigger

   switch(InpRunawayAction)
     {
      case RUNAWAY_ACTION_ADD_SL:
         ArmRunawaySL(state);
         break;

      case RUNAWAY_ACTION_CLOSE_ALL:
         LogDebug("[RunawayGuard] Trigger condition met — closing everything.");
         StartCleanupSequence(state);
         break;
     }
}

//+------------------------------------------------------------------+
//| Reset — call from ResetGridState, same as every other brick's     |
//| state gets cleared on a fresh cycle.                              |
//+------------------------------------------------------------------+
void ResetRunawayGuard(GridState &state)
{
   state.runawayStreakCount     = 0;
   state.runawayStreakDirection = WRONG_VALUE;
   state.runawayTriggered       = false;
}

#endif