//+------------------------------------------------------------------+
//| HedgeGrid.mq5                                                     |
//| Main EA coordinator — "brick" architecture (v14.00)                |
//| Rules:                                                           |
//|   - Every behavior is an independent, toggleable brick            |
//|     (see Inputs.mqh). No more hardcoded Style A/B/C engines.      |
//|   - Engines own their logic; GridState is the only shared data.   |
//|   - No engine calls another engine directly — only Utils/ helpers.|
//|     The coordinator (this file) is the only place allowed to      |
//|     orchestrate multiple engines together (e.g. the candle-open   |
//|     grid-build check below, which needs both MarginCheck and      |
//|     GridBuilder).                                                  |
//|   - Closing always outranks opening/modifying (cleanupInProgress  |
//|     gates every other brick off until a cleanup sequence ends).   |
//|   - Grid building happens ONLY at candle-open, never at OnInit,   |
//|     never immediately on session start.                            |
//+------------------------------------------------------------------+
#property copyright "HedgeGrid EA"
#property version   "10.00"
#property strict

#include "Inputs.mqh"
#include "Models/GridState.mqh"
#include "Utils/DebugLogger.mqh"
#include "Utils/HistoryLogger.mqh"
#include "Utils/MathUtils.mqh"
#include "Utils/BarUtils.mqh"
#include "Utils/SizingUtils.mqh"
#include "Utils/TradeUtils.mqh"
#include "Utils/CloseOrderUtils.mqh"
#include "Utils/TelegramUtils.mqh"
#include "Utils/SafetyNet.mqh"
#include "Utils/SessionFilter.mqh"
#include "Engines/MarginCheck.mqh"
#include "Engines/GridBuilder.mqh"
#include "Engines/OrderMonitor.mqh"
#include "Engines/GridUpdater.mqh"
#include "Engines/ShiftingEngine.mqh"
#include "Engines/SLManager.mqh"
#include "Engines/CleanupReset.mqh"
#include "Engines/Recentering.mqh"
#include "Dashboard/ChartPanel.mqh"
#include "Utils/StatePersistence.mqh"

GridState g_state;

//+------------------------------------------------------------------+
//| Items 9/10: at the start of each new candle, check whether a     |
//| grid needs to be built, and build one if not.                    |
//| This lives in the coordinator (not a separate "engine") because  |
//| it orchestrates two engines (MarginCheck + GridBuilder) — engines |
//| never call each other directly, only the coordinator may.         |
//|                                                                    |
//| This is the ONLY place a grid gets built after EA start:          |
//|   - OnInit no longer builds a grid (item 11).                     |
//|   - OnTick no longer builds immediately when a session starts.    |
//| On the EA's very first run, gridPlaced starts false, so the first |
//| candle-open tick after start builds the first grid automatically.|
//+------------------------------------------------------------------+
void CheckAndBuildGrid(GridState &state)
{
   //if(!IsNewBar(state.lastBarGridCheck)) return;
   if(!state.sessionAllowed)             return;
   if(state.gridPlaced)                  return;
   if(state.cleanupInProgress)           return; // closing always outranks opening
   if(InpGridAnchorMode == ANCHOR_PREV_BAR_RANGE)
     {
      ENUM_TIMEFRAMES tf = (Timeframe == 0) ? (ENUM_TIMEFRAMES)Period() : Timeframe;
      double prevHigh = iHigh(_Symbol, tf, 1);
      double prevLow  = iLow(_Symbol, tf, 1);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
      if(bid < prevLow || bid > prevHigh)
         return;   // price outside prev bar's range — wait, re-check next tick
   
      double range   = prevHigh - prevLow;
      double spread  = ask - bid;
      double minStop = MinStopDistancePrice(_Symbol);
   
      if(range < spread + minStop)
         return;   // range fundamentally too small for a valid grid, no matter where price sits
   
      if((prevHigh - ask) < minStop || (bid - prevLow) < minStop)
         return;   // range is wide enough overall, but price sits too close to one specific edge
     }

   
   state.lotMode = CheckMargin(state);
   if(state.marginWarning && AccountInfoDouble(ACCOUNT_MARGIN_FREE) < InpMinAllowedMargin)
     {
      LogDebug("[Coordinator] Margin still insufficient — skipping build this candle.");
      return;
     }
   //Print(__FILE__,__LINE__," state.gridPlaced: ",state.gridPlaced);
   BuildGrid(SymbolInfoDouble(_Symbol, SYMBOL_BID), state.lotMode, state);
   LogDebug("[Coordinator] New candle, no grid present — grid built.");
}

//+------------------------------------------------------------------+
//| OnInit                                                            |
//| Item 11: does NOT build a grid. Editing an input on a running     |
//| chart (which forces OnDeinit -> OnInit) no longer nukes an        |
//| existing grid. The first candle-open tick after EA start builds   |
//| the first grid automatically (gridPlaced starts false).           |
//+------------------------------------------------------------------+
int OnInit()
{
   g_state.magicNumber = (InpMagicNumber == 0) ? GenerateMagicNumber() : InpMagicNumber;
   InitTradeUtils(g_state.magicNumber);
   if(!InitHistoryLogger()) LogDebug("Warning: History logger failed.");
   
   int reason = UninitializeReason();
   bool preserve = (reason == REASON_PARAMETERS || reason == REASON_CHARTCHANGE ||
                    reason == REASON_RECOMPILE  || reason == REASON_CHARTCLOSE ||
                    reason == REASON_CLOSE);

   if(reason == REASON_ACCOUNT)
     {
      ResetGridState(g_state);
      g_state.gridPlaced = (CountPositions(g_state.magicNumber) > 0) ||
                           (CountOrderType(ORDER_TYPE_BUY_STOP,  g_state.magicNumber) > 0) ||
                           (CountOrderType(ORDER_TYPE_SELL_STOP, g_state.magicNumber) > 0);
      LogDebug("[Init] Account switch — state re-derived from broker, not restored from file.");
     }
   else if(preserve && LoadGridState(g_state))
     {
      LogDebug(StringFormat("[Init] State restored (reason=%d).", reason));
     }
   else
     {
      ResetGridState(g_state);
      if(preserve)
         LogDebug("[Init] Preserve reason but no valid saved state found — fresh start.");
     }
   
   g_state.sessionAllowed = IsSessionAllowed();
   g_state.lotMode        = CheckMargin(g_state);
   SetTelegramRoute();

   if(g_state.marginWarning)
     {
      if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < InpMinAllowedMargin)
        { LogDebug("CRITICAL: Insufficient margin. EA blocked."); return INIT_FAILED; }
     }

   InitDashboard();
   EventSetTimer(InpTimerIntervalSec);

   LogDebug(StringFormat("HedgeGrid started. Magic=%d LotMode=%s. Grid builds on next candle-open.",
                         g_state.magicNumber,
                         g_state.lotMode==LOT_FULL?"FULL":"HALF"));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeinitDashboard();
   DeinitHistoryLogger();
   EventKillTimer();
   LogDebug(StringFormat("HedgeGrid stopped. Reason=%d", reason));
   
   if(reason == REASON_REMOVE || reason == REASON_TEMPLATE ||
      reason == REASON_PROGRAM || reason == REASON_INITFAILED)
   { ExecuteEmergencyClose(g_state); ResetSLManager(g_state); }

   bool preserve = (reason == REASON_PARAMETERS || reason == REASON_CHARTCHANGE ||
                    reason == REASON_RECOMPILE  || reason == REASON_CHARTCLOSE ||
                    reason == REASON_CLOSE);

   if(preserve)
      SaveGridState(g_state);
   else
     {
      string fname = GetStateFileName(g_state.magicNumber);
      if(FileIsExist(fname)) FileDelete(fname);
     }
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   bool prevSession = g_state.sessionAllowed;
   // [REV-2026-09-15-CPU-VOLATILITY] why: session windows change only at
   // minute boundaries, so do not repeat the UTC/DST/window calculation on
   // every market tick. This is a cheap cache lookup in the hot path.
   g_state.sessionAllowed = GetCachedSessionAllowed(g_state);

   // ------------------------------------------------------------
   // Reconciliation: recognize known-stuck shapes and delegate to
   // the one real owner for each — never hand-write the fields here.
   // ------------------------------------------------------------

   // [REV-2026-09-13-CLOSE-SAFETY] Unified recheck/backstop for BOTH the
   // winner-side cleanup and the loser-purge sequence. This replaces the
   // old "only fires when CountPositions()==0" version, which caught a
   // completely-missed final pulse but NOT a genuinely stuck close (one
   // that failed and has nothing left to re-trigger it). Runs every ~2s,
   // not every tick, same throttle as before.
   //
   // Stagnation, not just "count > 0", is what triggers a retry: the
   // remaining count is compared to what it was on the LAST check. If it
   // changed, real progress is happening via normal confirmations --
   // don't interfere, that would risk a duplicate close on a ticket
   // that's already legitimately in flight. Only genuinely unchanged
   // counts across a full ~2s window count as "stuck" and get retried;
   // after InpCloseStuckAlarmAfter consecutive stuck checks, alarm via
   // the same SendTelegramMessage TriggerSafetyStop already uses.
   if(TimeCurrent() - g_state.lastCleanupUnstickCheck >= 2)
     {
      g_state.lastCleanupUnstickCheck = TimeCurrent();

      if(g_state.cleanupInProgress)
        {
         int remaining = CountPositions(g_state.magicNumber);
         if(remaining == 0)
           {
            g_state.cleanupStuckCount = 0;
            bool done = ExecuteNextCloseStep(g_state);
            if(done)
              {
               ResetSLManager(g_state);
               if(g_state.refillNeeded)
                 {
                  ProcessInsideMaintenance(g_state);
                  g_state.refillNeeded = false;
                 }
              }
           }
         else if(remaining == g_state.lastCleanupRemainingCount)
           {
            g_state.cleanupStuckCount++;
            ExecuteNextCloseStep(g_state); // retry -- genuinely stagnant
            if(g_state.cleanupStuckCount >= InpCloseStuckAlarmAfter)
               SendTelegramMessage(StringFormat(
                  "HedgeGrid ALARM: cleanup stuck, %d position(s) not closing.", remaining));
           }
         else
            g_state.cleanupStuckCount = 0; // count changed -- normal progress, don't interfere

         g_state.lastCleanupRemainingCount = remaining;
        }

      if(g_state.loserPurgeInProgress)
        {
         ENUM_POSITION_TYPE loserSide = ((ENUM_POSITION_TYPE)g_state.slWinnerSide == POSITION_TYPE_BUY)
                                         ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
         int remaining = CountPositionsBySide(g_state.magicNumber, loserSide);

         if(remaining == g_state.lastLoserPurgeRemainingCount)
           {
            g_state.loserPurgeStuckCount++;
            ExecuteNextLoserPurgeStep(g_state, loserSide); // retry -- genuinely stagnant
            if(g_state.loserPurgeStuckCount >= InpCloseStuckAlarmAfter)
               SendTelegramMessage(StringFormat(
                  "HedgeGrid ALARM: loser purge stuck, %d position(s) not closing.", remaining));
           }
         else
            g_state.loserPurgeStuckCount = 0; // count changed (or just completed) -- fine

         g_state.lastLoserPurgeRemainingCount = remaining;
        }

      // [REV-2026-09-15-CPU-VOLATILITY] backstop only: this state/broker
      // consistency check is intentionally rate-limited with the cleanup
      // reconciliation above. The grid lifecycle itself still runs through
      // the normal event/candle path; this merely catches an orphaned shape.
      if(g_state.gridPlaced && !g_state.cleanupInProgress &&
         CountPositions(g_state.magicNumber) == 0 &&
         CountOrders(g_state.magicNumber) == 0)
        {
         ResetGridBuilder(g_state);
        }
     }
  
   // ------------------------------------------------------------
   // [REV-2026-09-12-BACKBONE] The real cleanup trigger now -- a winner
   // (or any non-self-caused) close was recorded by OnTradeTransaction.
   // This is the "OnTick decides and acts" half of the flag; the
   // reconciliation block above stays as a rare-miss backstop only.
   // ------------------------------------------------------------
   if(g_state.winnerStoppedOut)
     {
      // Clear unconditionally, whether or not we act on it -- otherwise a
      // burst of several near-simultaneous SL hits (each setting this flag
      // while cleanup from the first one is already running) would leave
      // it stuck true and wrongly re-trigger cleanup on some later,
      // unrelated tick after the real cleanup already finished.
      g_state.winnerStoppedOut = false;
      if(!g_state.cleanupInProgress)
        {
         StartCleanupSequence(g_state);
         bool done = ExecuteNextCloseStep(g_state);
         if(done)
           {
            ResetSLManager(g_state);
            if(g_state.refillNeeded)
              {
               ProcessInsideMaintenance(g_state);
               g_state.refillNeeded = false;
              }
           }
        }
     }

   // [REV-2026-09-15-CPU-VOLATILITY] why: phantom-grid detection used to
   // run PositionsTotal()+OrdersTotal() scans on EVERY tick. That is pure
   // reconciliation/backstop work, not latency-sensitive trading logic.
   // It now runs inside the existing ~2s reconciliation window above, so
   // volatile tick bursts do not multiply two broker-state scans.
   
   // Orphaned wall: armed but nothing left for it to watch.
   if(g_state.slWallArmed && !g_state.cycleActive)
     {
      ResetSLManager(g_state);
     }
        
   if(!prevSession && g_state.sessionAllowed)
      LogSessionChange(true, GetActiveSessionName());
   if(prevSession && !g_state.sessionAllowed)
      LogSessionChange(false, "Session ended");
      
   // (Unstick already handled above for the cleanupInProgress + no positions case)

   // [REV-2026-09-11-CPU-FIX]
   // Perf: skip the full position-loop profit recompute while cleanup is
   // running -- OnTick returns right below before anything this tick
   // would use the result, so it was a wasted scan on every cleanup tick.
   //if(!g_state.cleanupInProgress)
   //   CalculateBasketProfits(g_state);

   // Closing always outranks opening/modifying — nothing else runs while
   // a cleanup sequence is in progress (it progresses via confirmations
   // in OnTradeTransaction, not per-tick).
   if(g_state.cleanupInProgress) return;

   if(InpGridAnchorMode == ANCHOR_PREV_BAR_RANGE && IsNewBar(g_state.lastBarGridFirstSL) &&
      g_state.gridPlaced && !g_state.cycleActive)   // gridPlaced but nothing's filled yet
     {
      DeleteAllOrders(g_state.magicNumber);
      ResetGridBuilder(g_state);   // clears gridPlaced, anchors, etc. — next CheckAndBuildGrid call rebuilds fresh
     }
   // the ONLY place a grid is ever built.
   CheckAndBuildGrid(g_state);

   if(g_state.needsGridVerification)
     {
      g_state.needsGridVerification = false;   // check runs exactly once, regardless of outcome
   
      if(!VerifyFreshGrid(g_state, g_state.lotMode))
        {
         LogDebug("[Coordinator] Fresh grid failed verification — resetting.");
         TriggerSafetyStop(g_state, "GRID_VERIFICATION_FAILED");
        }
     }

   // recenter (fresh grid only)
   if(ProcessRecentering(g_state))
      BuildGrid(SymbolInfoDouble(_Symbol, SYMBOL_BID), g_state.lotMode, g_state);

   // continuous SL arm/trail check
   if(g_state.cycleActive)
      ProcessSLManager(g_state);
   
   if(g_state.outsideRefillPending)
     {
      RefillOutside(g_state);
      g_state.outsideRefillPending = false;
     }
}

//+------------------------------------------------------------------+
//| OnTradeTransaction                                                |
//| Bug fixes applied:                                                 |
//|  #1 SL-hit detection delay -> handled synchronously here, not     |
//|     deferred to OnTick.   |
//|  #2 Normal fill vs SL close misidentification -> uses              |
//|     deal history (deal_entry via HistoryDealGetInteger) instead of deal_type alone.       |
//|  #3 isDeal filter -> only TRADE_TRANSACTION_DEAL_ADD now.          |
//|  Big A/B fix -> ANY close (DEAL_ENTRY_OUT), regardless of brick   |
//|     combo, is treated as a signal to start cleanup (unless an     |
//|     armed SL wall is still mid-sequence, expecting more closes).  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   // Bug fix #3: only DEAL_ADD is relevant — DEAL_UPDATE/DEAL_DELETE never
   // fire for normal trade activity, and TRADE_TRANSACTION_POSITION does
   // not carry deal history (needed for the #2 fix), so it is dropped too.
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(trans.symbol != _Symbol) return;
   if(trans.deal_type != DEAL_TYPE_BUY && trans.deal_type != DEAL_TYPE_SELL) return;

   // MqlTradeTransaction has no deal_entry field directly — it must be
   // read from deal history via the deal ticket (trans.deal).
   if(!HistoryDealSelect(trans.deal)) return;
   ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

   // ------------------------------------------------------------
   // CLEANUP IN PROGRESS — close one position per confirmation.
   // Closing always outranks opening: nothing else runs here.
   // ------------------------------------------------------------
   if(g_state.cleanupInProgress)
     {
      bool done = ExecuteNextCloseStep(g_state);
      if(done)
        {
         ResetSLManager(g_state); // coordinator's job — CleanupReset never reaches into SLManager
         if(g_state.refillNeeded)
           {
            ProcessInsideMaintenance(g_state);
            g_state.refillNeeded = false;
           }
        }
      return;
     }

   // ------------------------------------------------------------
   // [REV-2026-09-13-CLOSE-SAFETY] LOSER PURGE IN PROGRESS — same idea,
   // one loser-side position per confirmation. Without this gateway,
   // these closes (DEAL_REASON_EXPERT) would just fall through to the
   // close branch below, get correctly excluded from winnerStoppedOut,
   // and then... nothing would ever advance loserPurgeIndex. This is
   // what actually drives the paced purge pulse-by-pulse.
   // ------------------------------------------------------------
   if(g_state.loserPurgeInProgress)
     {
      ENUM_POSITION_TYPE loserSide = ((ENUM_POSITION_TYPE)g_state.slWinnerSide == POSITION_TYPE_BUY)
                                      ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
      ExecuteNextLoserPurgeStep(g_state, loserSide);
      return;
     }

   ulong positionTicket = trans.position;
   if(positionTicket == 0) return;

   // ------------------------------------------------------------
   // A position CLOSED (deal entry OUT / INOUT / OUT_BY).
   // [REV-2026-09-12-BACKBONE] why: this used to treat ANY close as an
   // unconditional cleanup trigger. That broke the moment ArmSL started
   // bulk-closing the loser side on its own (DEAL_REASON_EXPERT) --
   // those closes would have immediately re-triggered cleanup right
   // after arming, undoing the whole "protect winners, wait for their
   // SL" design. Fix: only DEAL_REASON_EXPERT (our own trade requests --
   // loser purge here, or cleanup's own closes, though those are already
   // intercepted above before reaching this branch) is excluded. Every
   // other reason (SL, SO, manual/client/mobile/web) still sets the
   // signal, preserving the original "any unexpected close is a safety
   // trigger" intent for everything that isn't self-caused.
   //
   // Per the "transactions record, ticks decide" rule agreed this
   // session: this only sets a flag. OnTick is the only place that
   // actually calls StartCleanupSequence.
   // ------------------------------------------------------------
   if(dealEntry == DEAL_ENTRY_OUT ||
      dealEntry == DEAL_ENTRY_INOUT ||
      dealEntry == DEAL_ENTRY_OUT_BY)
     {
      double closeLot = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
      UpdateSideVolumeAggregate(g_state, trans.deal_type, dealEntry, closeLot, 0.0);

      ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON);
      if(reason != DEAL_REASON_EXPERT)
         g_state.winnerStoppedOut = true;

      return;
     }

   if(dealEntry != DEAL_ENTRY_IN) return; // if just A position opened

   // ------------------------------------------------------------
   // NORMAL FLOW — a new position opened.
   // ------------------------------------------------------------

   // Gap fault check (minor bug fix: expected price passed explicitly,
   // not re-read from a possibly-gone order after the fact).
   double currentPrice  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double expectedPrice = 0.0;
   /*ulong  faultTicket    = CheckGapFault(currentPrice, g_state.magicNumber, expectedPrice);
   if(faultTicket != 0)
     {
      g_state.gapFaultDetected = true;
      LogGapFault(expectedPrice, currentPrice, faultTicket);
      TriggerSafetyStop(g_state, StringFormat("GAP_FAULT ticket=%I64u expected=%.5f", faultTicket, expectedPrice));
      return;
     }*/

   ProcessOrderFill(positionTicket, g_state);

   // [REV-2026-09-12-BACKBONE]: keep the O(1) aggregate current for the
   // pre-arm decision. Uses the fill's own deal fields, not the position
   // (matches UpdateSideVolumeAggregate's OUT-side reasoning for symmetry,
   // and ProcessOrderFill above may have already changed what
   // PositionGetDouble would report anyway).
   double openLot   = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
   double openPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   UpdateSideVolumeAggregate(g_state, trans.deal_type, dealEntry, openLot, openPrice);

   // Re-snapshot the armed-winner set on every new fill (closes the
   // "new fill mid-epoch" gap — confirmed: re-snapshot every time).
   // KNOWN FOLLOW-UP (flagged, not fixed this pass): this still does a
   // full SnapshotWinners() rebuild rather than appending just the one
   // new ticket -- discussed as a good idea, not yet implemented.
   ReSnapshotIfArmed(g_state);

   // Brick 1 / Brick 2 — each is a no-op internally if its toggle is off.
   UpdateOppositeGrid(g_state);
   
   //ShiftGrid(g_state);

   //ProcessInsideStrategy(g_state);
      
   // was: RefillOutside(g_state);
   g_state.outsideRefillPending = true;

   // [REV-2026-09-12-BACKBONE] why: removed the direct ProcessSLManager()
   // call that used to run here on every fill. Arm/trail decisions (and
   // now the loser-purge burst inside ArmSL) are execution, not
   // monitoring -- per the "transactions record, ticks decide" rule,
   // this belongs in OnTick only. OnTick already calls ProcessSLManager
   // every tick while cycleActive, so this costs at most one tick of
   // latency (sub-second), not a missed arm.

   LogHistory("ORDER_FILL",
              g_state.lastHitPrice,
              g_state.lastHitDirection==ORDER_TYPE_BUY?"BUY":"SELL",
              g_state.lastHitLot,
              g_state.passCounter,
              g_state.currentBlockLot,
              g_state.basketProfit,
              g_state.sessionAllowed,
              AccountInfoDouble(ACCOUNT_MARGIN_FREE));
}

//+------------------------------------------------------------------+
//| OnTimer                                                           |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateDashboard(g_state);
   CalculateBasketProfits(g_state);

   //ENUM_LOT_MODE newMode = CheckMargin(g_state);
   //if(newMode != g_state.lotMode && !g_state.cycleActive)
   //   g_state.lotMode = newMode;
}

//+------------------------------------------------------------------+
//| OnChartEvent                                                      |
//| Extra concern #1 resolved: emergency close is now fully unified.  |
//| It always closes everything and resets state; the next candle-   |
//| open check (GridLifecycle) rebuilds automatically — no branching  |
//| by brick combo needed here at all.                                 |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   if(!InpShowDashboard) return;
   if(!HandleChartEvent(id, lparam, dparam, sparam)) return;

   LogDebug("EMERGENCY CLOSE triggered from dashboard.");
   ExecuteEmergencyClose(g_state);
   ResetSLManager(g_state); // coordinator's job — CleanupReset never reaches into SLManager
}
