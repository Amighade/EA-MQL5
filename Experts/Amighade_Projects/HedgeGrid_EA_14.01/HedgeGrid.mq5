//+------------------------------------------------------------------+
//| HedgeGrid.mq5                                                     |
//| Main EA coordinator — "brick" architecture (v10.00)                |
//| Rules:                                                           |
//|   - Every behavior is an independent, toggleable brick            |
//|     (see Inputs.mqh). No more hardcoded Style A/B/C engines.      |
//|   - Engines own their logic; GridState is the only shared data.   |
//|   - No engine calls another engine directly — only Utils/ helpers.|
//|     The coordinator (this file) is the only place allowed to      |
//|     orchestrate multiple engines together (e.g. the grid-build    |
//|     grid-build check below, which needs both MarginCheck and      |
//|     GridBuilder).                                                  |
//|   - Closing always outranks opening/modifying (cleanupInProgress  |
//|     gates every other brick off until a cleanup sequence ends).   |
//|   - Grid building is checked by the medium timer task, not OnInit. |
//+------------------------------------------------------------------+
#property copyright "HedgeGrid EA"
#property version   "14.01"
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

struct SchedulerTransaction
  {
   ENUM_TRADE_TRANSACTION_TYPE type;
   ulong deal;
   ulong order;
   ulong position;
   uint requestId;
   uint retcode;
   int historyRetries;
  };

SchedulerTransaction g_transactionQueue[];
int  g_transactionHead = 0;
bool g_reconcilePending = true;
bool g_transactionQueueFailed = false;
bool g_emergencyCloseRequested = false;

//+------------------------------------------------------------------+
//| Items 9/10: at the start of each new candle, check whether a     |
//| grid needs to be built, and build one if not.                    |
//| This lives in the coordinator (not a separate "engine") because  |
//| it orchestrates two engines (MarginCheck + GridBuilder) — engines |
//| never call each other directly, only the coordinator may.         |
//|                                                                    |
//| This is the ONLY place a grid gets built after EA start:          |
//|   - OnInit no longer builds a grid (item 11).                     |
//|   - The medium timer task checks when a session starts.            |
//| On first run, gridPlaced starts false, so the timer builds once    |
//| session and price rules allow it.                                  |
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
   LogDebug("[Coordinator] No grid present — grid built on medium timer check.");
}

//+------------------------------------------------------------------+
//| OnInit                                                            |
//| Item 11: does NOT build a grid. Editing an input on a running     |
//| chart (which forces OnDeinit -> OnInit) no longer nukes an        |
//| existing grid. The medium timer builds the first grid when allowed|
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
   uint initTick = GetTickCount();
   g_state.g_lastTime_50ms = initTick;
   g_state.g_lastTime_500ms = initTick;
   g_state.g_lastTime_2000ms = initTick;
   g_state.g_lastTime_60000ms = initTick;
   SetTelegramRoute();

   if(g_state.marginWarning)
     {
      if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < InpMinAllowedMargin)
        { LogDebug("CRITICAL: Insufficient margin. EA blocked."); return INIT_FAILED; }
     }

   InitDashboard();
   ArrayFree(g_transactionQueue);
   g_transactionHead = 0;
   g_reconcilePending = true;
   if(!EventSetMillisecondTimer(SCHEDULER_HEARTBEAT_MS))
     {
      LogDebug(StringFormat("Timer initialization failed. err=%d", GetLastError()));
      return INIT_FAILED;
     }

   LogDebug(StringFormat("HedgeGrid started. Magic=%d LotMode=%s. Grid builds when timer checks allow it.",
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

// Queue broker facts here; strategy and trade work runs from OnTimer().
void QueueTradeTransaction(const MqlTradeTransaction &trans,
                           const MqlTradeRequest &request,
                           const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_REQUEST)
     {
      if(request.symbol != _Symbol || request.magic != g_state.magicNumber)
         return;
     }
   else if(trans.symbol != _Symbol)
      return;

   int size = ArraySize(g_transactionQueue);
   if(ArrayResize(g_transactionQueue, size + 1, 64) != size + 1)
     {
      g_transactionQueueFailed = true;
      return;
     }

   g_transactionQueue[size].type = trans.type;
   g_transactionQueue[size].deal = trans.deal;
   g_transactionQueue[size].order = (trans.type == TRADE_TRANSACTION_REQUEST && result.order > 0)
                                    ? result.order : trans.order;
   g_transactionQueue[size].position = trans.position;
   g_transactionQueue[size].requestId = result.request_id;
   g_transactionQueue[size].retcode = result.retcode;
   g_transactionQueue[size].historyRetries = 0;
}

void RemoveQueuedTransaction()
{
   g_transactionHead++;
   int total = ArraySize(g_transactionQueue);

   if(g_transactionHead >= total)
     {
      ArrayFree(g_transactionQueue);
      g_transactionHead = 0;
      return;
     }

   if(g_transactionHead >= 32 && g_transactionHead >= total / 2)
     {
      int remaining = total - g_transactionHead;
      for(int i = 0; i < remaining; i++)
         g_transactionQueue[i] = g_transactionQueue[g_transactionHead + i];
      ArrayResize(g_transactionQueue, remaining);
      g_transactionHead = 0;
     }
}

bool ProcessOneQueuedTransaction(GridState &state)
{
   if(g_transactionHead >= ArraySize(g_transactionQueue))
      return false;

   SchedulerTransaction tx = g_transactionQueue[g_transactionHead];

   if(tx.type == TRADE_TRANSACTION_REQUEST)
     {
      // A rejected synchronous request needs another bounded cleanup attempt.
      if(state.cleanupInProgress &&
         tx.retcode != TRADE_RETCODE_DONE &&
         tx.retcode != TRADE_RETCODE_DONE_PARTIAL &&
         tx.retcode != TRADE_RETCODE_PLACED)
         g_cleanupAdvancePending = true;
      g_reconcilePending = true;
      RemoveQueuedTransaction();
      return true;
     }

   if(tx.type == TRADE_TRANSACTION_ORDER_ADD ||
      tx.type == TRADE_TRANSACTION_ORDER_UPDATE ||
      tx.type == TRADE_TRANSACTION_ORDER_DELETE ||
      tx.type == TRADE_TRANSACTION_POSITION)
     {
      if(state.cleanupInProgress)
         g_cleanupAdvancePending = true;
      g_reconcilePending = true;
      RemoveQueuedTransaction();
      return true;
     }

   if(tx.type != TRADE_TRANSACTION_DEAL_ADD)
     {
      RemoveQueuedTransaction();
      return true;
     }

   if(!HistoryDealSelect(tx.deal))
     {
      g_transactionQueue[g_transactionHead].historyRetries++;
      if(g_transactionQueue[g_transactionHead].historyRetries < 4)
         return false;

      LogDebug(StringFormat("[Scheduler] Deal history unavailable after retries. deal=%I64u",
                            tx.deal));
      g_reconcilePending = true;
      RemoveQueuedTransaction();
      return true;
     }

   if((int)HistoryDealGetInteger(tx.deal, DEAL_MAGIC) != state.magicNumber)
     {
      RemoveQueuedTransaction();
      return true;
     }

   ENUM_DEAL_ENTRY dealEntry =
      (ENUM_DEAL_ENTRY)HistoryDealGetInteger(tx.deal, DEAL_ENTRY);

   if(state.cleanupInProgress)
     {
      g_cleanupAdvancePending = true;
      RemoveQueuedTransaction();
      return true;
     }

   if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT ||
      dealEntry == DEAL_ENTRY_OUT_BY)
     {
      StartCleanupSequence(state);
      g_cleanupAdvancePending = true;
      RemoveQueuedTransaction();
      return true;
     }

   if(dealEntry != DEAL_ENTRY_IN || tx.position == 0)
     {
      RemoveQueuedTransaction();
      return true;
     }

   ProcessOrderFill(tx.position, state);
   ReSnapshotIfArmed(state);
   UpdateOppositeGrid(state);
   ShiftGrid(state);
   ProcessInsideStrategy(state);
   state.outsideRefillPending = true;

   LogHistory("ORDER_FILL",
              state.lastHitPrice,
              state.lastHitDirection == ORDER_TYPE_BUY ? "BUY" : "SELL",
              state.lastHitLot,
              state.passCounter,
              state.currentBlockLot,
              state.basketProfit,
              state.sessionAllowed,
              AccountInfoDouble(ACCOUNT_MARGIN_FREE));

   RemoveQueuedTransaction();
   return true;
}

void ExecuteFastTasks(ulong frameStartMicro, ulong budgetMicro, GridState &state)
{
   CalculateBasketProfits(state);

   if(state.cleanupInProgress)
     {
      if(g_cleanupAdvancePending)
        {
         g_cleanupAdvancePending = false;
         bool done = ExecuteNextCloseStep(state);
         if(done)
           {
            ResetSLManager(state);
            if(state.refillNeeded)
              {
               ProcessInsideMaintenance(state);
               state.refillNeeded = false;
              }
           }
        }
      return;
     }

   if(GetMicrosecondCount() - frameStartMicro >= budgetMicro)
      return;

   if(state.cycleActive)
      ProcessSLManager(state);
}

void ExecuteMediumTasks(ulong frameStartMicro, ulong budgetMicro, GridState &state)
{
   bool prevSession = state.sessionAllowed;
   state.sessionAllowed = IsSessionAllowed();

   if(!prevSession && state.sessionAllowed)
      LogSessionChange(true, GetActiveSessionName());
   if(prevSession && !state.sessionAllowed)
      LogSessionChange(false, "Session ended");

   if(g_reconcilePending)
     {
      if(state.cleanupInProgress && CountPositions(state.magicNumber) == 0)
         g_cleanupAdvancePending = true;

      if(state.gridPlaced && !state.cycleActive &&
         CountPositions(state.magicNumber) == 0 &&
         CountOrders(state.magicNumber) == 0)
         ResetGridBuilder(state);

      if(state.slWallArmed && !state.cycleActive)
         ResetSLManager(state);

      g_reconcilePending = false;
     }

   if(GetMicrosecondCount() - frameStartMicro >= budgetMicro ||
      state.cleanupInProgress)
      return;

   if(InpGridAnchorMode == ANCHOR_PREV_BAR_RANGE &&
      IsNewBar(state.lastBarGridFirstSL) &&
      state.gridPlaced && !state.cycleActive)
     {
      DeleteAllOrders(state.magicNumber);
      ResetGridBuilder(state);
     }

   CheckAndBuildGrid(state);

   if(GetMicrosecondCount() - frameStartMicro >= budgetMicro)
      return;

   if(state.needsGridVerification)
     {
      state.needsGridVerification = false;
      if(!VerifyFreshGrid(state, state.lotMode))
        {
         LogDebug("[Coordinator] Fresh grid failed verification — resetting.");
         TriggerSafetyStop(state, "GRID_VERIFICATION_FAILED");
        }
     }

   if(!state.cleanupInProgress && ProcessRecentering(state))
      BuildGrid(SymbolInfoDouble(_Symbol, SYMBOL_BID), state.lotMode, state);

   if(GetMicrosecondCount() - frameStartMicro >= budgetMicro)
      return;

   if(!state.cleanupInProgress && state.outsideRefillPending)
     {
      RefillOutside(state);
      state.outsideRefillPending = false;
     }

   if(!state.cleanupInProgress && state.refillNeeded)
     {
      ProcessInsideMaintenance(state);
      state.refillNeeded = false;
     }
}

void ExecuteSlowTasks()
{
   UpdateDashboard(g_state);
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   QueueTradeTransaction(trans, request, result);
}

void OnTimer()
{
   ulong frameStartMicro = GetMicrosecondCount();
   uint currentTick = GetTickCount();

   if(g_transactionQueueFailed)
     {
      g_transactionQueueFailed = false;
      g_reconcilePending = true;
      LogDebug("[Scheduler] Transaction queue allocation failed; broker reconciliation requested.");
     }

   if(g_emergencyCloseRequested)
     {
      g_emergencyCloseRequested = false;
      ExecuteEmergencyClose(g_state);
      ResetSLManager(g_state);
     }

   int processed = 0;
   while(g_transactionHead < ArraySize(g_transactionQueue) &&
         processed < 8 &&
         GetMicrosecondCount() - frameStartMicro < SCHEDULER_BUDGET_US)
     {
      if(!ProcessOneQueuedTransaction(g_state))
         break;
      processed++;
     }

   if((uint)(currentTick - g_state.g_lastTime_50ms) >= SCHEDULER_FAST_INTERVAL_MS)
     {
      g_state.g_lastTime_50ms = currentTick;
      ExecuteFastTasks(frameStartMicro, SCHEDULER_BUDGET_US, g_state);
     }

   ulong elapsed = GetMicrosecondCount() - frameStartMicro;
   if(elapsed < SCHEDULER_BUDGET_US &&
      ((uint)(currentTick - g_state.g_lastTime_500ms) >= SCHEDULER_MEDIUM_INTERVAL_MS ||
       g_state.cleanupInProgress))
     {
      if(!g_state.cleanupInProgress)
         g_state.g_lastTime_500ms = currentTick;
      ExecuteMediumTasks(frameStartMicro, SCHEDULER_BUDGET_US, g_state);
     }

   elapsed = GetMicrosecondCount() - frameStartMicro;
   if(elapsed < SCHEDULER_BUDGET_US &&
      (uint)(currentTick - g_state.g_lastTime_2000ms) >=
      (uint)MathMax(1000, InpTimerIntervalSec * 1000))
     {
      g_state.g_lastTime_2000ms = currentTick;
      ExecuteSlowTasks();
     }

   // Reserved for low-frequency maintenance; no such task exists in Rev13.01.
   if((uint)(currentTick - g_state.g_lastTime_60000ms) >= SCHEDULER_BACKGROUND_MS)
      g_state.g_lastTime_60000ms = currentTick;
}

//+------------------------------------------------------------------+
//| OnChartEvent                                                      |
//| Emergency-close requests are deferred to the timer.               |
//+------------------------------------------------------------------+
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

   LogDebug("EMERGENCY CLOSE queued for the next timer pass.");
   g_emergencyCloseRequested = true;
}
