//+------------------------------------------------------------------+
//| HedgeGrid.mq5                                                     |
//| Main EA coordinator — "brick" architecture (v20.00)                |
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
#property version   "20.00"
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
#include "Engines/SLManager.mqh"
#include "Engines/CleanupReset.mqh"
#include "Engines/TimerEngine.mqh"
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

   if(state.marginWarning && AccountInfoDouble(ACCOUNT_MARGIN_FREE) < InpMinAllowedMargin)
     {
      LogDebug("[Coordinator] Margin still insufficient — skipping build this candle.");
      return;
     }
   //Print(__FILE__,__LINE__," state.gridPlaced: ",state.gridPlaced);
   BuildGrid(SymbolInfoDouble(_Symbol, SYMBOL_BID), state);
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
   SetTelegramRoute();

   if(g_state.marginWarning)
     {
      if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < InpMinAllowedMargin)
        { LogDebug("CRITICAL: Insufficient margin. EA blocked."); return INIT_FAILED; }
     }

   InitDashboard();
   
   //EventSetTimer(InpTimerIntervalSec);
   
   // Start our 10ms Game Loop Engine
   EventSetMillisecondTimer(BASE_HEARTBEAT_MS);
    
   // Seed non-blocking delays with current system uptime
   uint currentTick = GetTickCount();
   g_state.g_lastTime_50ms    = currentTick;
   g_state.g_lastTime_500ms   = currentTick;
   g_state.g_lastTime_2000ms  = currentTick;
   g_state.g_lastTime_60000ms = currentTick;

   LogDebug(StringFormat("HedgeGrid started. Magic=%d LotMode=%s. Grid builds on next candle-open.",
                         g_state.magicNumber));
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
   ArrayFree(g_state.g_txQueue); 
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
    // Minimal work. Let the timer update your SL or logic on its next tick.
    // If you need tracking parameters like latest bid/ask, copy them to a global struct here.
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
    // Capture data immediately into array. Do NOT analyze here.
    MqlTradeTransactionShort element;
    element.type     = trans.type;
    element.order    = trans.order;
    element.position = trans.position;
    element.volume   = trans.volume;
    element.price    = trans.price;
    
    int size = ArraySize(g_state.g_txQueue);
    if(ArrayResize(g_state.g_txQueue, size + 1) > 0)
    {
        g_state.g_txQueue[size] = element;
        g_state.g_txDirty = true; // Signal the Game Loop
    }
}

//+------------------------------------------------------------------+
//| OnTimer                                                           |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Start High-Resolution Stopwatch
    ulong startTimeMicro = GetMicrosecondCount();
    uint currentTick = GetTickCount();
    
    // --- TASK LEVEL 1: URGENT / HIGH FREQUENCY (Runs every 50ms) ---
    if((currentTick - g_state.g_lastTime_50ms) >= INTERVAL_FAST_50MS)
    {
        g_state.g_lastTime_50ms = currentTick; // Reset time anchor
        ExecuteFastTasks(startTimeMicro, MAX_CPU_BUDGET_MICRO, g_state); 
    }
    
    // --- TASK LEVEL 2: MEDIUM FREQUENCY / HEAVY RECONCILIATION (Runs every 500ms) ---
    ulong elapsed = GetMicrosecondCount() - startTimeMicro;
    if(elapsed < MAX_CPU_BUDGET_MICRO && ((currentTick - g_state.g_lastTime_500ms) >= INTERVAL_MEDIUM_500MS || g_state.g_cleanupInProgress))
    {
        // Notice we also enter this block if g_cleanupInProgress is true, ensuring rapid continuation
        if(!g_state.g_cleanupInProgress) g_state.g_lastTime_500ms = currentTick; 
        
        ulong remainingBudget = MAX_CPU_BUDGET_MICRO - elapsed;
        ExecuteMediumTasks(startTimeMicro, remainingBudget, g_state); 
    }
    
    // --- TASK LEVEL 3: SLOW FREQUENCY / DASHBOARDS (Runs every 2 Sec) ---
    elapsed = GetMicrosecondCount() - startTimeMicro;
    if(elapsed < MAX_CPU_BUDGET_MICRO && (currentTick - g_state.g_lastTime_2000ms) >= INTERVAL_SLOW_2000MS)
    {
        g_state.g_lastTime_2000ms = currentTick;
        ExecuteSlowTasks(); 
    }
    
    // --- TASK LEVEL 4: BACKGROUND / DATA RETENTION (Runs every 1 Min) ---
    elapsed = GetMicrosecondCount() - startTimeMicro;
    if(elapsed < MAX_CPU_BUDGET_MICRO && (currentTick - g_state.g_lastTime_60000ms) >= INTERVAL_BACKGROUND_1M)
    {
        g_state.g_lastTime_60000ms = currentTick;
        ExecuteBackgroundTasks(); 
    }
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


