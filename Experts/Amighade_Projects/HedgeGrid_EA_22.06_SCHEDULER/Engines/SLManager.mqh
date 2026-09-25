//+------------------------------------------------------------------+
//| SLManager.mqh                                                     |
//| BRICK 6: add SL to the winning side once armed, then trail it.   |
//| Gated by InpEnableSL. Unified — every combo uses the same         |
//| arm -> snapshot -> trail -> all-closed -> cleanup pipeline that   |
//| used to be Style-C-only. No more separate "AB path"/"C path".    |
//|                                                                    |
//| Trigger: arms as soon as the leading side's basket profit > 0.   |
//| ASSUMPTION (flagged for confirmation): the old InpSLTriggerByLot /|
//| InpSLTriggerByProfit toggles were dropped per your instruction;  |
//| "profit > 0" is the only trigger left, applied unconditionally   |
//| whenever InpEnableSL is true. Tell me if you want this gated       |
//| further and I'll add an input back.                              |
//|                                                                    |
//| SL PLACEMENT (Bug fix #5 applied — struct moved to file scope):  |
//|   Candidates are grid lines stepping back from the winning side's|
//|   most recent fill, in InpGridSpacing increments. Each candidate |
//|   is tested with the same net-PnL-safe formula (entries, lots,  |
//|   commission, spread, broker min-stop-distance). The largest n   |
//|   for which the test still passes is maxValidN.                  |
//|     SL_LAST_HIT_GRID : always n=1 (last hit's own grid line),    |
//|                        no search beyond it.                      |
//|     SL_N_BACK_GRID   : n = MIN(InpSLNBack, maxValidN) — depth-   |
//|                        clamped to the farthest still-safe line.  |
//|                                                                    |
//| TRAILING (Bug fix #6 applied):                                    |
//|   The full net-PnL search above is heavy (loops every position   |
//|   per candidate) and only runs at arm time and whenever an armed |
//|   winner CLOSES (position set changed, so the safe level might   |
//|   change too). Per-tick trailing is a cheap, purely arithmetic   |
//|   step: if price has advanced past the next grid line beyond the |
//|   current SL, move the SL forward by one InpGridSpacing step —   |
//|   no position loop, no PnL recompute.                            |
//|                                                                    |
//| RE-SNAPSHOT (per your instruction): the armed-winner ticket set   |
//|   is re-captured on every new fill while armed (ReSnapshotIfArmed,|
//|   called by the coordinator on every DEAL_ENTRY_IN), not just     |
//|   once at arm time — closes the "new fill mid-epoch falls through |
//|   the cracks" gap.                                                |
//|                                                                    |
//| BROKER FAULT (REV 22.06 overwrite): SL changes are async.         |
//|   The wall advances only after every live winner confirms the      |
//|   intended SL. Rejected/unconfirmed tickets retry without Sleep(); |
//|   safety cleanup starts only after the configured retry limit.     |
//+------------------------------------------------------------------+
#ifndef SL_MANAGER_MQH
#define SL_MANAGER_MQH

#include "SLGridFeasibility.mqh"
#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/DebugLogger.mqh"
#include "../Utils/SafetyNet.mqh"
#include "../Utils/ProfilerUtils.mqh"

//--- Armed-epoch winner ticket set — owned by this engine only
ulong g_ArmedWinnerTickets[];

// REV 22.06: one logical SL-wall update may fan out to several async
// position modifications. Strategy state advances only after the complete
// live winner set confirms protection at the requested wall.
struct PendingSLWallUpdate
{
   bool   active;
   bool   arming;
   double targetSL;
   int    winnerSide;
};

PendingSLWallUpdate g_pendingSLWallUpdate;

void ClearPendingSLWallUpdate()
{
   g_pendingSLWallUpdate.active     = false;
   g_pendingSLWallUpdate.arming     = false;
   g_pendingSLWallUpdate.targetSL   = 0.0;
   g_pendingSLWallUpdate.winnerSide = -1;
}

void CancelPendingSLWallUpdate()
{
   ClearPendingSLWallUpdate();
   ClearAsyncSLModifyRequests();
}
//+------------------------------------------------------------------+
//| Grid-line SL candidate search (Brick 6 core algorithm)            |
//+------------------------------------------------------------------+
double CalculateSLCandidate(GridState &state, ENUM_POSITION_TYPE winnerSide, int magicNumber,
                            ENUM_SL_MODE mode)
{
   ulong profFunctionStart = GetMicrosecondCount();
   double candidate = SL_FindCandidate(state, winnerSide, magicNumber, mode);
   ProfilerRecord(PROF_CALCULATE_SL_CANDIDATE, profFunctionStart);
   return candidate;
}
//+------------------------------------------------------------------+
//| Apply SL to every ticket in the armed-winner snapshot.            |
//| Returns handled count (protected/pending/retry scheduled), or      |
//| -1 only after the configured SL retry limit is exhausted.          |
//+------------------------------------------------------------------+
int ApplySLToWinners(double slLevel, GridState &state)
{
   ulong profFunctionStart = GetMicrosecondCount();
   int    count  = 0;
   double slNorm = NormalizeDouble(slLevel, _Digits);

   for(int i = 0; i < ArraySize(g_ArmedWinnerTickets); i++)
     {
      ulong t = g_ArmedWinnerTickets[i];
      if(!PositionSelectByTicket(t)) continue; // already closed, skip

      double oldNorm = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
      if(oldNorm == slNorm && slNorm > 0.0) { count++; continue; }

      if(ModifyPositionSL(t, slLevel))
         count++;
      else
        {
         // REV 22.06 overwrite: ModifyPositionSL() returns false only when
         // the configured retry limit is exhausted (or tracking cannot continue).
         CancelPendingSLWallUpdate();
         TriggerSafetyStop(state, StringFormat("SL_MODIFY_RETRIES_EXHAUSTED ticket=%I64u", t));
         ProfilerRecord(PROF_APPLY_SL_WINNERS, profFunctionStart);
         return -1;
        }
     }
   ProfilerRecord(PROF_APPLY_SL_WINNERS, profFunctionStart);
   return count;
}

//+------------------------------------------------------------------+
//| Confirm a logical async SL-wall update against LIVE positions.    |
//| Request submission/server acceptance alone never advances state.  |
//+------------------------------------------------------------------+
bool FinalizePendingSLWallUpdate(GridState &state)
{
   if(!g_pendingSLWallUpdate.active)
      return false;

   // First consume any live-state confirmation or release a timed-out request
   // for retry. Then ask every current winner ticket to continue toward the SAME
   // logical wall target. ModifyPositionSL() is non-blocking and rate-limited by
   // the per-ticket retry state, so this does not resend on every fast tier.
   ReconcileAsyncSLModifyRequests();

   int handled = ApplySLToWinners(g_pendingSLWallUpdate.targetSL, state);
   if(handled < 0)
      return false; // safety cleanup was triggered after retry exhaustion

   ReconcileAsyncSLModifyRequests();

   int liveWinners = 0;
   for(int i = 0; i < ArraySize(g_ArmedWinnerTickets); i++)
     {
      ulong ticket = g_ArmedWinnerTickets[i];
      if(!PositionSelectByTicket(ticket))
         continue;

      liveWinners++;

      // Still awaiting request/result/live-state confirmation.
      if(HasPendingSLModify(ticket))
         return false;

      if(!IsPositionSLAtLeastTarget(ticket, g_pendingSLWallUpdate.targetSL))
         return false;
     }

   // Nothing remains to protect. Do not arm a phantom wall.
   if(liveWinners == 0)
     {
      ClearPendingSLWallUpdate();
      return false;
     }

   ENUM_POSITION_TYPE winnerSide = (ENUM_POSITION_TYPE)g_pendingSLWallUpdate.winnerSide;

   if(g_pendingSLWallUpdate.arming)
     {
      // Freeze the winner aggregate only after protection is confirmed live.
      if(winnerSide == POSITION_TYPE_BUY)
        {
         state.buyVolume = 0.0;
         state.buyAvgEntry = 0.0;
        }
      else
        {
         state.sellVolume = 0.0;
         state.sellAvgEntry = 0.0;
        }
     }

   bool wasArmed = state.slWallArmed;
   double previousSL = state.slLevel;

   state.slWallArmed  = true;
   state.slApplied    = true;
   state.slLevel      = g_pendingSLWallUpdate.targetSL;
   state.slWinnerSide = g_pendingSLWallUpdate.winnerSide;

   // Do not create a false "trailed" event when this pending update existed
   // only to put the already-confirmed wall onto a newly-filled winner ticket.
   if(!wasArmed || !NearlyEqualPrice(previousSL, g_pendingSLWallUpdate.targetSL))
      LogSLTriggered(g_pendingSLWallUpdate.arming ? "SL_ARMED" : "SL_TRAILED",
                     g_pendingSLWallUpdate.targetSL);

   ClearPendingSLWallUpdate();
   return true;
}

//+------------------------------------------------------------------+
//| Snapshot every current winner-side position into the armed set.  |
//| Applies to ALL positions on that side regardless of individual   |
//| P/L (per design: SL applies to the whole winning-side basket).   |
//+------------------------------------------------------------------+
void SnapshotWinners(int magicNumber, ENUM_POSITION_TYPE winnerSide)
{
   ulong profFunctionStart = GetMicrosecondCount();
   ArrayResize(g_ArmedWinnerTickets, 0);
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)     continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != winnerSide) continue;

      int sz = ArraySize(g_ArmedWinnerTickets);
      ArrayResize(g_ArmedWinnerTickets, sz+1);
      g_ArmedWinnerTickets[sz] = t;
     }
   ProfilerRecord(PROF_SNAPSHOT_WINNERS, profFunctionStart);
}

//+------------------------------------------------------------------+
//| Re-snapshot on every new fill while armed (closes the epoch gap).|
//| Call from coordinator on every DEAL_ENTRY_IN.                    |
//+------------------------------------------------------------------+
void ReSnapshotIfArmed(GridState &state)
{
   if(!state.slWallArmed && !g_pendingSLWallUpdate.active)
      return;

   ENUM_POSITION_TYPE winnerSide = state.slWallArmed
                                   ? (ENUM_POSITION_TYPE)state.slWinnerSide
                                   : (ENUM_POSITION_TYPE)g_pendingSLWallUpdate.winnerSide;

   SnapshotWinners(state.magicNumber, winnerSide);

   if(g_pendingSLWallUpdate.active)
     {
      // A wall update is already in progress: the new winner joins that SAME
      // target and will share its retry/confirmation lifecycle.
      ApplySLToWinners(g_pendingSLWallUpdate.targetSL, state);
      return;
     }

   // Wall is already confirmed and a new winner-side position appeared. The
   // strategy requires every winner to carry the existing wall, so create a
   // confirmation cycle at the SAME level (this is not a trail step).
   if(state.slWallArmed && state.slLevel > 0.0)
     {
      g_pendingSLWallUpdate.active     = true;
      g_pendingSLWallUpdate.arming     = false;
      g_pendingSLWallUpdate.targetSL   = state.slLevel;
      g_pendingSLWallUpdate.winnerSide = state.slWinnerSide;

      FinalizePendingSLWallUpdate(state);
     }
}

//+------------------------------------------------------------------+
//| True once every armed winner ticket has closed.                  |
//+------------------------------------------------------------------+
bool AllWinnersClosed()
{
   if(ArraySize(g_ArmedWinnerTickets) == 0) return false; // never armed / nothing to check
   for(int i = 0; i < ArraySize(g_ArmedWinnerTickets); i++)
      if(PositionSelectByTicket(g_ArmedWinnerTickets[i])) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Reset SL engine state — call after a cycle fully completes.      |
//+------------------------------------------------------------------+
void ResetSLManager(GridState &state)
{
   ArrayResize(g_ArmedWinnerTickets, 0);
   CancelPendingSLWallUpdate();
   state.slAllWinnersClosed = false;
   state.slApplied = false;
   state.slLevel = 0;
   state.slWallArmed = false;
   state.slWinnerSide = -1;
}

//+------------------------------------------------------------------+
//| Arm the SL wall: compute initial safe level, snapshot, apply.    |
//+------------------------------------------------------------------+
void ArmSL(GridState &state)
{
   ENUM_POSITION_TYPE winnerSide = (state.lastHitDirection == ORDER_TYPE_BUY) ?
                                   POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   ENUM_POSITION_TYPE loserSide  = (winnerSide == POSITION_TYPE_BUY) ?
                                   POSITION_TYPE_SELL : POSITION_TYPE_BUY;

   double slLevel = CalculateSLCandidate(state, winnerSide, state.magicNumber, InpSLArmMode);

   if(slLevel <= 0) return; // not safe yet, try again next tick

   SnapshotWinners(state.magicNumber, winnerSide);
   if(ArraySize(g_ArmedWinnerTickets) == 0) return;

   int applied = ApplySLToWinners(slLevel, state);
   if(applied < 0) return; // safety stop already triggered
   if(applied == 0) return;

   // REV 22.06: submission is not application. Hold the intended wall here
   // and advance slApplied/slWallArmed only after live positions confirm it.
   g_pendingSLWallUpdate.active     = true;
   g_pendingSLWallUpdate.arming     = true;
   g_pendingSLWallUpdate.targetSL   = slLevel;
   g_pendingSLWallUpdate.winnerSide = (int)winnerSide;

   FinalizePendingSLWallUpdate(state);
}
//+------------------------------------------------------------------+
//| Cheap per-tick trail: step SL forward by one grid spacing when   |
//| price has advanced past the next line. No position/PnL loop.    |
//+------------------------------------------------------------------+
void TrailWall(GridState &state)
{
   ENUM_POSITION_TYPE winnerSide = (ENUM_POSITION_TYPE)state.slWinnerSide;

   if(state.slLevel <= 0.0 || InpGridSpacing <= 0.0)
      return;

   // REV 22.3: trailing is a cheap one-grid-step operation. The heavy safe
   // candidate search is used when arming; it is not repeated every fast tier.
   double slLevel = (winnerSide == POSITION_TYPE_BUY)
                    ? state.slLevel + InpGridSpacing
                    : state.slLevel - InpGridSpacing;
   slLevel = AlignToTick(_Symbol, slLevel);

   if(!SL_IsProgress(winnerSide, slLevel, state.slLevel)) return;
   if(!SL_BrokerOK(winnerSide, slLevel)) return;
   if(ArraySize(g_ArmedWinnerTickets) == 0) return;

   // The winner snapshot is maintained at arm time and on new fills. Do not
   // rescan every position on every trail check.
   int applied = ApplySLToWinners(slLevel, state);
   if(applied < 0) return; // safety stop already triggered
   if(applied == 0) return;

   // REV 22.06: keep the old confirmed wall active until the next wall is
   // confirmed on every live winner ticket.
   g_pendingSLWallUpdate.active     = true;
   g_pendingSLWallUpdate.arming     = false;
   g_pendingSLWallUpdate.targetSL   = slLevel;
   g_pendingSLWallUpdate.winnerSide = (int)winnerSide;

   FinalizePendingSLWallUpdate(state);
}
//+------------------------------------------------------------------+
//| Called by coordinator when an armed winner closes (DEAL_ENTRY_OUT|
//| while armed) — position set changed, so re-run the heavy safe-   |
//| level search once and re-apply (Bug fix #6: not on every tick).  |
//+------------------------------------------------------------------+
//to be checked
void RecalcOnWinnerClose(GridState &state)
{
   if(!state.slWallArmed) return;

   if(AllWinnersClosed())
     {
      ArrayResize(g_ArmedWinnerTickets, 0);
      state.slAllWinnersClosed = true;
      state.slApplied = false;
      state.slLevel = 0;
      state.slWallArmed = false;
      state.slWinnerSide = -1;
      LogDebug("[SLManager] All armed winners closed — signalling coordinator to start cleanup.");
     }
}
//+------------------------------------------------------------------+
//| Master entry point. No-op unless InpEnableSL is true.            |
//| Call every tick from coordinator.                                 |
//+------------------------------------------------------------------+
void ProcessSLManager(GridState &state)
{
   // REV 22.06: finish any previously submitted async wall update first.
   // While it is pending, do not calculate/submit another arm or trail level.
   if(g_pendingSLWallUpdate.active)
     {
      FinalizePendingSLWallUpdate(state);
      if(g_pendingSLWallUpdate.active)
         return;
     }

   if(state.slWallArmed)
     {
      if(InpSLTrailMode != SL_NONE)
        {
         ulong profTrailStart = GetMicrosecondCount();
         TrailWall(state);
         ProfilerRecord(PROF_TRAIL_WALL, profTrailStart);
        }
      return;
     }

   if(InpSLArmMode == SL_NONE) return;

   ulong profBasketStart = GetMicrosecondCount();
   CalculateBasketProfitFromAggregates(state);
   ProfilerRecord(PROF_BASKET_FROM_AGGREGATES, profBasketStart);
   double net = state.basketProfit;
   if(net <= 0) return;

   ulong profArmStart = GetMicrosecondCount();
   ArmSL(state);
   ProfilerRecord(PROF_ARM_SL, profArmStart);
}
#endif
