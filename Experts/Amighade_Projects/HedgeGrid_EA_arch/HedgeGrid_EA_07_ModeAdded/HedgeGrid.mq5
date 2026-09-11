//+------------------------------------------------------------------+
//| HedgeGrid.mq5                                                     |
//| Main EA coordinator — "brick" architecture (v4.00)                |
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
#property version   "4.00"
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
void CheckAndBuildGridOnNewCandle(GridState &state)
{
   if(!IsNewBar(state.lastBarGridCheck)) return;
   if(!state.sessionAllowed)             return;
   if(state.gridPlaced)                  return;
   if(state.cleanupInProgress)           return; // closing always outranks opening

   state.lotMode = CheckMargin(state);
   if(state.marginWarning && AccountInfoDouble(ACCOUNT_MARGIN_FREE) < InpMinAllowedMargin)
     {
      LogDebug("[Coordinator] Margin still insufficient — skipping build this candle.");
      return;
     }

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
   ResetGridState(g_state);
   InitOperationalMode(g_state); // mode = MODE_RUNNING — only ever set here, never by a cycle reset
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
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   bool prevSession = g_state.sessionAllowed;
   g_state.sessionAllowed = IsSessionAllowed();

   if(!prevSession && g_state.sessionAllowed)
      LogSessionChange(true, GetActiveSessionName());
   if(prevSession && !g_state.sessionAllowed)
      LogSessionChange(false, "Session ended");

   g_state.basketProfit = CalculateBasketProfit(g_state.magicNumber);

   // Closing always outranks opening/modifying — nothing else runs while
   // a cleanup sequence is in progress (it progresses via confirmations
   // in OnTradeTransaction, not per-tick).
   if(g_state.cleanupInProgress) return;

   // ------------------------------------------------------------
   // MODE_SHUTDOWN: repeatedly drive the emergency close every tick
   // until the account is fully flat (handles the case where some
   // closes failed even after their own internal retries — a single
   // one-shot TriggerSafetyStop call isn't guaranteed to finish the
   // job). Nothing else in this function runs while shutting down.
   // ------------------------------------------------------------
   if(g_state.mode == MODE_SHUTDOWN)
     {
      static datetime s_nextEscalateAt = 0;

      bool flat = (CountPositions(g_state.magicNumber) == 0 &&
                   CountOrders(g_state.magicNumber)    == 0);

      if(!flat)
        {
         // Silent retry — the alert/Telegram message already fired once,
         // at the moment the mode switched to Shutdown (OnChartEvent).
         // Retrying loudly every tick here would spam both every tick
         // until flat, which defeats the point of an alert.
         int c1,c2,c3,c4;
         SilentCloseAll(g_state.magicNumber, c1, c2, c3, c4);

         // Escalate (one more loud alert) if it's still stuck a minute
         // later — a persistently failing close is worth knowing about,
         // not just silently retried forever.
         if(s_nextEscalateAt == 0)
            s_nextEscalateAt = TimeCurrent() + 60;
         else if(TimeCurrent() >= s_nextEscalateAt)
           {
            TriggerSafetyStop(g_state, "SHUTDOWN_STUCK — still not flat after 60s of retries");
            s_nextEscalateAt = TimeCurrent() + 60; // escalate again every 60s while still stuck
           }
        }
      else
        {
         s_nextEscalateAt = 0; // reset so a future Shutdown starts its own timer fresh
         if(!g_state.shutdownFlat)
           {
            g_state.shutdownFlat = true;
            LogDebug("[Coordinator] Shutdown complete — account is flat.");
           }
        }
      return;
     }

   // ------------------------------------------------------------
   // MODE_RUNNING only: grid can grow (build + recenter). MODE_PAUSED
   // skips both — "maintenance" mode, no new builds/refills/shifts/
   // recenters, but SL management below still runs in both modes.
   // ------------------------------------------------------------
   if(g_state.mode == MODE_RUNNING)
     {
      // Items 9/10: the ONLY place a grid is ever built.
      CheckAndBuildGridOnNewCandle(g_state);

      // Brick 3: recenter (fresh grid only)
      if(ProcessRecentering(g_state))
         BuildGrid(SymbolInfoDouble(_Symbol, SYMBOL_BID), g_state.lotMode, g_state);
     }

   // Brick 6: continuous SL arm/trail check — runs in RUNNING and PAUSED
   // alike (Paused still protects and manages the existing basket).
   if(g_state.cycleActive)
      ProcessSLManager(g_state);
}

//+------------------------------------------------------------------+
//| OnTradeTransaction                                                |
//| Bug fixes applied:                                                 |
//|  #1 SL-hit detection delay -> handled synchronously here, not     |
//|     deferred to OnTick (RecalcOnWinnerClose runs inline below).   |
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
         ResetSLManager(); // coordinator's job — CleanupReset never reaches into SLManager
         // Refill is opening logic — suppressed in Paused/Shutdown, same as build/shift/recenter.
         if(g_state.refillNeeded && g_state.mode == MODE_RUNNING)
            CheckAndRefill(g_state); // inside refill takes priority over outside (handled inside FillOneSide)
        }
      return;
     }

   ulong positionTicket = trans.position;
   if(positionTicket == 0) return;

   // ------------------------------------------------------------
   // A position CLOSED (deal entry OUT / INOUT / OUT_BY).
   // Big A/B fix: any close is treated as a cleanup trigger, unless
   // an armed SL wall is still mid-sequence and expects more closes.
   // ------------------------------------------------------------
   if(dealEntry == DEAL_ENTRY_OUT ||
      dealEntry == DEAL_ENTRY_INOUT ||
      dealEntry == DEAL_ENTRY_OUT_BY)
     {
      if(InpEnableSL)
        {
         RecalcOnWinnerClose(g_state); // no-op unless the wall is armed
         if(g_state.slAllWinnersClosed)
           {
            g_state.slAllWinnersClosed = false;
            StartCleanupSequence(g_state);
            return;
           }
         if(g_state.slWallArmed) return; // still waiting on the rest of the armed wall
        }
      // SL disabled, or nothing armed, or an unexpected close (manual, etc.)
      // — Bug fix "Big A/B": there must always be a cleanup trigger.
      StartCleanupSequence(g_state);
      return;
     }

   if(dealEntry != DEAL_ENTRY_IN) return; // ignore anything unexpected

   // ------------------------------------------------------------
   // NORMAL FLOW — a new position opened.
   // ------------------------------------------------------------

   // Gap fault check (minor bug fix: expected price passed explicitly,
   // not re-read from a possibly-gone order after the fact).
   double currentPrice  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double expectedPrice = 0.0;
   ulong  faultTicket    = CheckGapFault(currentPrice, g_state.magicNumber, expectedPrice);
   if(faultTicket != 0)
     {
      g_state.gapFaultDetected = true;
      LogGapFault(expectedPrice, currentPrice, faultTicket);
      TriggerSafetyStop(g_state, StringFormat("GAP_FAULT ticket=%I64u expected=%.5f", faultTicket, expectedPrice));
      return;
     }

   ProcessOrderFill(positionTicket, g_state);

   // Re-snapshot the armed-winner set on every new fill (closes the
   // "new fill mid-epoch" gap — confirmed: re-snapshot every time).
   ReSnapshotIfArmed(g_state);

   // Brick 1 / Brick 2 — opening logic, suppressed outside MODE_RUNNING
   // (Paused/Shutdown: a pending order already on the book can still be
   // hit and managed, but the grid must not grow further from that hit).
   if(g_state.mode == MODE_RUNNING)
     {
      UpdateOppositeGrid(g_state);
      ShiftGrid(g_state);
     }

   // Brick 6 — check immediately after a fill too (not just OnTick),
   // so a newly-profitable basket doesn't wait for the next tick to arm.
   ProcessSLManager(g_state);

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

   ENUM_LOT_MODE newMode = CheckMargin(g_state);
   if(newMode != g_state.lotMode && !g_state.cycleActive)
      g_state.lotMode = newMode;
}

//+------------------------------------------------------------------+
//| OnChartEvent                                                      |
//| Emergency close (manual button) is fully unified — it always      |
//| closes everything and resets state; the next candle-open check    |
//| rebuilds automatically — no branching by brick combo needed here. |
//|                                                                    |
//| The dashboard's MODE label (click to cycle Running -> Paused ->   |
//| Shutdown -> Running) only mutates state.mode itself — it never    |
//| calls an engine directly (Dashboard/ isn't allowed to any more    |
//| than one engine is allowed to call another). This coordinator     |
//| reacts to the mode change immediately below.                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   if(!InpShowDashboard) return;

   ENUM_EA_MODE prevMode = g_state.mode;
   if(!HandleChartEvent(id, lparam, dparam, sparam, g_state)) return;

   if(g_emergencyPressed)
     {
      g_emergencyPressed = false;
      LogDebug("EMERGENCY CLOSE triggered from dashboard.");
      ExecuteEmergencyClose(g_state);
      ResetSLManager(); // coordinator's job — CleanupReset never reaches into SLManager
      return;
     }

   // Mode just switched to Shutdown — kick off the close immediately
   // rather than waiting for the next OnTick's retry loop to notice.
   if(prevMode != MODE_SHUTDOWN && g_state.mode == MODE_SHUTDOWN)
     {
      LogDebug("MODE -> SHUTDOWN: closing everything now.");
      ExecuteEmergencyClose(g_state);
      ResetSLManager();
     }
}
