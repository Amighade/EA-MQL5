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
#property version   "14.00"
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
   g_state.sessionAllowed = IsSessionAllowed();
   
   // Check market profit tracking dynamically on every incoming tick
   if(g_state.cycleActive && !g_state.cleanupInProgress)
     {
      ProcessSLManager(g_state);
     }
   // ------------------------------------------------------------
   // Reconciliation: recognize known-stuck shapes and delegate to
   // the one real owner for each — never hand-write the fields here.
   // ------------------------------------------------------------

   // Cleanup never got the transaction that should have kicked it off.
   if(g_state.cleanupInProgress && CountPositions(g_state.magicNumber) == 0)
     {
      bool done = ExecuteNextCloseStep(g_state);
      if(done)
        {
         ResetSLManager(g_state);
         if(g_state.refillNeeded)
           {
            ProcessInsideMaintenance(g_state);
            g_state.refillNeeded = false;
           }
         return;
        }
     }
  
   // Phantom grid: state believes a grid exists, broker has nothing.
   if(g_state.gridPlaced && !g_state.cleanupInProgress &&
      CountPositions(g_state.magicNumber) == 0 &&
      CountOrders(g_state.magicNumber) == 0)
     {
      ResetGridBuilder(g_state);
     }
   
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
  
   CalculateBasketProfits(g_state);

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
   //if(g_state.cycleActive)
   //   ProcessSLManager(g_state);
   
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
   // FIXED GATEWAY: Pass both deal additions AND order deletions through
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD && 
      trans.type != TRADE_TRANSACTION_ORDER_DELETE) return;
      
   if(trans.symbol != _Symbol) return;

   // ------------------------------------------------------------
   // CLEANUP SHIELD BLOCK: Intercepts all confirmations safely
   // ------------------------------------------------------------
   if(g_state.cleanupInProgress)
     {
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
      return; // Absolute exit door for cleanup thread pulses
     }

   // From this point down, only pure DEAL_ADD events matter for normal flow
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

   if(!HistoryDealSelect(trans.deal)) return;
   ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

   ulong positionTicket = trans.position;
   if(positionTicket == 0) return;

   // ------------------------------------------------------------
   // A position CLOSED (deal entry OUT / INOUT / OUT_BY).
   // Fixed: Partial closes and close-by transactions route correctly here now.
   // ------------------------------------------------------------
   if(dealEntry == DEAL_ENTRY_OUT ||
      dealEntry == DEAL_ENTRY_INOUT ||
      dealEntry == DEAL_ENTRY_OUT_BY)
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
      return;
     }

   if(dealEntry != DEAL_ENTRY_IN) return; // if just A position opened
   
   // ------------------------------------------------------------
   // REAL-TIME SAFETY BARRIER
   // ------------------------------------------------------------
   // If positions are 0 but old ghost orders are still clearing out or
   // generating late cancellation pulses, BLOCK the normal flow from running!
   if(CountPositions(g_state.magicNumber) == 0 && CountOrders(g_state.magicNumber) > 0)
     {
      return; // Absolute protection cutoff
     }

   // ------------------------------------------------------------
   // NORMAL FLOW — a new position opened.
   // ------------------------------------------------------------
   ProcessOrderFill(positionTicket, g_state);
   ReSnapshotIfArmed(g_state);

   UpdateOppositeGrid(g_state);
   ShiftGrid(g_state);

   ProcessInsideStrategy(g_state);
      
   g_state.outsideRefillPending = true;
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



/*
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
      // SL disabled, or nothing armed, or an unexpected close (manual, etc.)
      // — Bug fix "Big A/B": there must always be a cleanup trigger.
      StartCleanupSequence(g_state);
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

   if(dealEntry != DEAL_ENTRY_IN) return; // if just A position opened

   // ------------------------------------------------------------
   // NORMAL FLOW — a new position opened.
   // ------------------------------------------------------------

   // Gap fault check (minor bug fix: expected price passed explicitly,
   // not re-read from a possibly-gone order after the fact).
   double currentPrice  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double expectedPrice = 0.0;

   ProcessOrderFill(positionTicket, g_state);

   // Re-snapshot the armed-winner set on every new fill (closes the
   // "new fill mid-epoch" gap — confirmed: re-snapshot every time).
   ReSnapshotIfArmed(g_state);

   // Brick 1 / Brick 2 — each is a no-op internally if its toggle is off.
   UpdateOppositeGrid(g_state);
   ShiftGrid(g_state);

   ProcessInsideStrategy(g_state);
      
   // was: RefillOutside(g_state);
   g_state.outsideRefillPending = true;

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
}*/

//+------------------------------------------------------------------+
//| OnTimer                                                           |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateDashboard(g_state);

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
