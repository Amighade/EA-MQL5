//+------------------------------------------------------------------+
//| SLManager.mqh                                                     |
//| BRICK 6: add SL to the winning side once armed, then trail it.   |
//| Gated by InpEnableSL. Unified — every combo uses the same         |
//| arm -> snapshot -> trail -> all-closed -> cleanup pipeline that   |
//| used to be Style-C-only. No more separate "AB path"/"C path".    |
//|                                                                    |
//| Trigger: arms once state.lastHitDirection's side profit > 0,     |
//| computed O(1) from the incremental {volume, avgEntry} aggregate   |
//| (see OrderMonitor::UpdateSideVolumeAggregate), not from looping   |
//| positions or from account-wide floating P/L.                      |
//|                                                                    |
//| [REV-2026-09-12-BACKBONE]: once armed, InpCloseLosersAtArm        |
//| (selectable, see Inputs.mqh) controls whether the losing side is  |
//| bulk-closed immediately (ArmSL) or left open until the normal     |
//| cleanup path. Both are supported so they can be compared.         |
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
//| BROKER FAULT (updated): if ModifyPositionSL fails after its one   |
//|   immediate retry (no Sleep), that ticket is closed instead of    |
//|   nuking the whole basket. TriggerSafetyStop only fires if the    |
//|   close itself also fails (unprotectable AND unclosable).         |
//|   See ApplySLToWinners for the full reasoning.                    |
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

//--- Armed-epoch winner ticket set — owned by this engine only
ulong g_ArmedWinnerTickets[];

//+------------------------------------------------------------------+
//| [REV-2026-09-12-BACKBONE] why: removed CollectAllPositions,       |
//| SLPosInfo, and NetPnLAtCandidate entirely -- all three existed to |
//| feed a per-position loop into the old net-PnL check. That check   |
//| now lives in SLGridFeasibility.mqh's NetBasketAtCandidate(),      |
//| which uses the O(1) incremental {volume, avgEntry} aggregate on   |
//| GridState instead (see OrderMonitor::UpdateSideVolumeAggregate).  |
//| GetWinningDirection() also removed -- winner side now comes from  |
//| state.lastHitDirection (the actual agreed trigger), never from    |
//| comparing basketBuyProfit/basketSellProfit.                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Grid-line SL candidate search (Brick 6 core algorithm).           |
//| [REV-2026-09-12-BACKBONE] why: the old CountMatchingPositions      |
//| early-exit guard is gone -- SL_FindCandidate is already O(1) or    |
//| bounded by InpSLNBack now (no position loop left inside it at     |
//| all), so there's no expensive work left to guard against. Kept as |
//| a thin wrapper (not inlined into callers) on purpose -- ArmSL and |
//| TrailWall both call this single choke point rather than           |
//| SL_FindCandidate directly, so they can never independently drift  |
//| the way TrailWall/TrailWall_orgn once did.                        |
//+------------------------------------------------------------------+
double CalculateSLCandidate(GridState &state, ENUM_POSITION_TYPE winnerSide, int magicNumber,
                            ENUM_SL_MODE mode)
{
   return SL_FindCandidate(state, winnerSide, magicNumber, mode);
}
//+------------------------------------------------------------------+
//| Apply SL to every ticket in the armed-winner snapshot.            |
//| Returns applied count (0..N). A ticket that can't be protected is |
//| closed instead (see below) — it no longer aborts the whole batch, |
//| so this never returns -1 anymore. The -1 checks in ArmSL/TrailWall|
//| are kept as harmless dead guards rather than ripped out.          |
//|                                                                    |
//| [REV-2026-09-11-CPU-FIX] why: TriggerSafetyStop on every SL-modify |
//| rejection nuked the whole basket for what's often one transient   |
//| requote -- disproportionate, and rejections were frequent.        |
//| Design change (agreed): a modify failure used to be treated as a  |
//| basket-wide emergency (TriggerSafetyStop closes/deletes           |
//| everything). That's a wildly disproportionate response to one     |
//| ticket getting rejected. New behavior:                            |
//|   1. ModifyPositionSL already pre-validates via ValidateStopPrice |
//|      and now does at most one immediate retry, no Sleep.          |
//|   2. If it still fails, close JUST that ticket instead of the     |
//|      whole basket. A ticket closed this way looks identical to    |
//|      one closed by a real SL hit to AllWinnersClosed() / the rest |
//|      of this file — no special-casing needed elsewhere.           |
//|   3. Only if the close ALSO fails (now genuinely unprotectable    |
//|      AND unclosable) do we escalate to TriggerSafetyStop — that   |
//|      case still deserves the nuclear response.                    |
//+------------------------------------------------------------------+
int ApplySLToWinners(double slLevel, GridState &state)
{
   int    count  = 0;
   double slNorm = NormalizeDouble(slLevel, _Digits);

   for(int i = 0; i < ArraySize(g_ArmedWinnerTickets); i++)
     {
      ulong t = g_ArmedWinnerTickets[i];
      if(!PositionSelectByTicket(t)) continue; // already closed, skip

      double oldNorm = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
      if(oldNorm == slNorm && slNorm > 0.0) { count++; continue; }

      if(ModifyPositionSL(t, slLevel))
        {
         count++;
         continue;
        }

      // Modify failed even after ModifyPositionSL's own one retry.
      // Can't protect it -> close it, rather than nuke the whole basket.
      LogDebug(StringFormat("SL_MODIFY_FAILED ticket=%I64u -> closing position instead", t));
      if(!ClosePosition(t))
        {
         // Genuinely unprotectable AND unclosable — this is the case
         // that still warrants the emergency stop.
         TriggerSafetyStop(state, StringFormat("SL_MODIFY_AND_CLOSE_FAILED ticket=%I64u", t));
         return -1;
        }
     }
   return count;
}

//+------------------------------------------------------------------+
//| Snapshot every current winner-side position into the armed set.  |
//| Applies to ALL positions on that side regardless of individual   |
//| P/L (per design: SL applies to the whole winning-side basket).   |
//+------------------------------------------------------------------+
void SnapshotWinners(int magicNumber, ENUM_POSITION_TYPE winnerSide)
{
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
}

//+------------------------------------------------------------------+
//| Re-snapshot on every new fill while armed (closes the epoch gap).|
//| Call from coordinator on every DEAL_ENTRY_IN.                    |
//+------------------------------------------------------------------+
void ReSnapshotIfArmed(GridState &state)
{
   if(!state.slWallArmed) return;
   SnapshotWinners(state.magicNumber, (ENUM_POSITION_TYPE)state.slWinnerSide);
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
   state.slAllWinnersClosed = false;
   state.slApplied = false;
   state.slLevel = 0;
   state.slWallArmed = false;
   state.slWinnerSide = -1;
}

//+------------------------------------------------------------------+
//| Arm the SL wall: compute initial safe level, snapshot, apply,     |
//| then deal with the losing side (Brick 6 + new backbone).          |
//|                                                                    |
//| [REV-2026-09-12-BACKBONE] Sequence, per the agreed backbone:      |
//|   1. Arm winners with SL (unchanged mechanism).                   |
//|   2. If InpCloseLosersAtArm: bulk-close every loser-side position |
//|      in ONE loop (no ordering needed -- unlike winner cleanup,    |
//|      there's no "wait for next confirmation" pacing rationale for |
//|      losers, they're not being closed in any profit sequence),    |
//|      then bulk-delete every loser-side pending order.             |
//|   3. Reset the winner-side aggregate to 0 (frozen from here on --  |
//|      trailing doesn't need live profit, confirmed). Loser-side    |
//|      aggregate is only reset if it was actually purged in step 2  |
//|      -- if InpCloseLosersAtArm is false, it keeps updating so     |
//|      NetBasketAtCandidate() during trailing still sees real       |
//|      numbers for that intentionally-still-open side.              |
//|                                                                    |
//| NOTE (flagged, not resolved): closing the loser side the moment   |
//| the winner side ticks barely positive removes the hedge for that  |
//| cycle -- a real reversal right after would realize a loss with    |
//| nothing left open to absorb it. That's a strategy trade-off, not  |
//| an engineering one; InpCloseLosersAtArm exists so both can be     |
//| compared rather than committing to one permanently.               |
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

   // [REV-2026-09-13-CLOSE-SAFETY] why: bulk-close was replaced with the
   // same paced, confirmation-based mechanism the winner-side cleanup
   // already uses -- avoids the broker rate-limit risk a burst of
   // simultaneous close requests carries (TRADE_RETCODE_TOO_MANY_REQUESTS
   // exists for a reason). InpCloseLosersBulk still allows a bulk
   // first-pass for comparison; either way, StartLoserPurgeSequence
   // below rescans and picks up whatever's still open, so the recheck
   // path is identical regardless of which mode ran first. Orders are
   // NOT paced -- deleting a resting (not yet triggered) pending order
   // has no broker-burst risk the way closing a live position does, so
   // they stay a single bulk call, unconditionally, immediately.
   if(InpCloseLosersAtArm)
     {
      DeleteOrdersBySide(state.magicNumber, loserSide);
      if(InpCloseLosersBulk)
         CloseAllPositionsBySide(state.magicNumber, loserSide);

      StartLoserPurgeSequence(state, loserSide);
      ExecuteNextLoserPurgeStep(state, loserSide);

      // Freeze the loser-side aggregate NOW, not when the paced close
      // finishes -- once the purge decision is made, NetBasketAtCandidate
      // shouldn't keep counting a side that's committed to closing, even
      // while a few of its positions are still draining through pulses.
      if(loserSide == POSITION_TYPE_BUY) { state.buyVolume = 0; state.buyAvgEntry = 0; }
      else                               { state.sellVolume = 0; state.sellAvgEntry = 0; }
     }

   // Winner side is always frozen from here -- trailing owns it via
   // g_ArmedWinnerTickets/the SL order itself, not this aggregate.
   if(winnerSide == POSITION_TYPE_BUY) { state.buyVolume = 0; state.buyAvgEntry = 0; }
   else                                { state.sellVolume = 0; state.sellAvgEntry = 0; }

   state.slWallArmed  = true;
   state.slApplied    = true;
   state.slLevel      = slLevel;
   state.slWinnerSide = (int)winnerSide;
   LogSLTriggered("SL_ARMED", slLevel);
}

//+------------------------------------------------------------------+
//| Cheap per-tick trail: step SL forward by one grid spacing when   |
//| price has advanced past the next line. No position/PnL loop.    |
//+------------------------------------------------------------------+
void TrailWall_orgn(GridState &state)
{
   if(!state.slWallArmed) return;

   ENUM_POSITION_TYPE winnerSide = (ENUM_POSITION_TYPE)state.slWinnerSide;
   double price = (winnerSide == POSITION_TYPE_BUY) ?
                  SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double newSL = state.slLevel;
   bool   stepped = false;

   ReSnapshotIfArmed(g_state);
      
   // Step forward one grid line at a time while price has passed the next one
   while(true)
     {
      double nextLevel = (winnerSide == POSITION_TYPE_BUY) ?
                         newSL + InpGridSpacing : newSL - InpGridSpacing;
      bool passed = (winnerSide == POSITION_TYPE_BUY) ?
                    (price > nextLevel) : (price < nextLevel);
      if(!passed) break;
      newSL = AlignToTick(_Symbol, nextLevel);
      stepped = true;
     }

   if(stepped)
     {
      int applied = ApplySLToWinners(newSL, state);
      if(applied < 0) return; // safety stop already triggered
      if(applied > 0) state.slLevel = newSL;
     }

   // Check if all armed winners have closed (SL hit) -> signal coordinator
   if(AllWinnersClosed())
     {
      state.slAllWinnersClosed = true;
      state.slWallArmed        = false;
      LogDebug("[SLManager] All armed winners closed — signalling coordinator to start cleanup.");
     }
}

void TrailWall(GridState &state)
{
   //ENUM_POSITION_TYPE winnerSide = GetWinningDirection(state);
   ENUM_POSITION_TYPE winnerSide = (ENUM_POSITION_TYPE)state.slWinnerSide;
   double slLevel = CalculateSLCandidate(state, winnerSide, state.magicNumber, InpSLTrailMode);
   // [REV-2026-09-11-CPU-FIX] why: removed an unguarded Print(...)//AGH debug
   // leftover that fired every tick while the SL wall was armed.

   if(slLevel <= 0) return; // not safe yet, try again next tick

   // [REV-2026-09-11-CPU-FIX] why: this SnapshotWinners() call re-scanned every
   // open position every tick while armed for no benefit.
   // Perf: removed the unconditional SnapshotWinners() call that used to
   // sit here -- it re-scanned every open position every tick, but the
   // armed-winner set only ever changes on a new fill, which is already
   // captured correctly and exclusively via ReSnapshotIfArmed (called
   // from the coordinator on every fill while armed) and the initial
   // snapshot in ArmSL. Re-running it here every tick just rebuilt the
   // same array over and over for no reason.
   if(ArraySize(g_ArmedWinnerTickets) == 0) return;

   int applied = ApplySLToWinners(slLevel, state);
   if(applied < 0) return; // safety stop already triggered
   if(applied == 0) return;
   
   ulong t = g_ArmedWinnerTickets[0];
   if(!PositionSelectByTicket(t))
   {
   ResetSLManager(state);
   } 
   else
   {
   slLevel = PositionGetDouble(POSITION_SL);
   
   state.slWallArmed  = true;
   state.slApplied    = true;
   state.slLevel      = slLevel;
   state.slWinnerSide = (int)winnerSide;
   LogSLTriggered("SL_ARMED", slLevel);
   }
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
//|                                                                    |
//| [REV-2026-09-12-BACKBONE] why: replaced AccountInfoDouble         |
//| (ACCOUNT_PROFIT) with the per-side O(1) aggregate. ACCOUNT_PROFIT |
//| is account-wide -- floating P/L from every symbol and magic on    |
//| the account, not just this EA's own basket. Fine on an account    |
//| running only this EA; wrong the moment anything else trades on    |
//| it (flagged, not yet handled -- user is aware, to revisit if this |
//| account ever runs more than one EA/symbol).                       |
//|                                                                    |
//| The check is scoped to state.lastHitDirection specifically (the   |
//| most recent fill's side), not "whichever side happens to be       |
//| positive" -- per the agreed trigger: the recent fill names the    |
//| candidate winner, and ITS profit crossing positive is what arms.  |
//+------------------------------------------------------------------+
void ProcessSLManager(GridState &state)
{
   if(state.slWallArmed)
     {
      if(InpSLTrailMode != SL_NONE) TrailWall(state);
      return;
     }

   if(InpSLArmMode == SL_NONE) return;

   ENUM_POSITION_TYPE candidateSide = (state.lastHitDirection == ORDER_TYPE_BUY) ?
                                      POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   double vol   = (candidateSide == POSITION_TYPE_BUY) ? state.buyVolume   : state.sellVolume;
   double entry = (candidateSide == POSITION_TYPE_BUY) ? state.buyAvgEntry : state.sellAvgEntry;
   double price = (candidateSide == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                        : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double profit = SideProfitAtPrice(candidateSide, vol, entry, price);
   if(profit <= 0) return;
   ArmSL(state);
}
#endif
