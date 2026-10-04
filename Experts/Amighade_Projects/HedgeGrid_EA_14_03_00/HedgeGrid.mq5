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
#property version   "14.030"
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

   if(reason == REASON_ACCOUNT || reason == REASON_REMOVE)
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

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   QueueTradeTransaction(trans, request, result);
}

void OnTimer()
{
   RunScheduler(g_state);
   TimeGaugeReport();
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
   // Ctrl+Shift+Q works independently of the dashboard; one command per press.
   static bool emergencyKeyHeld = false;
   if(id == CHARTEVENT_KEYUP && lparam == 81)
   {
      emergencyKeyHeld = false;
      return;
   }
   if(id == CHARTEVENT_KEYDOWN && lparam == 81)
   {
      if(emergencyKeyHeld) return;
      emergencyKeyHeld = true;
      bool ctrl = (TerminalInfoInteger(TERMINAL_KEYSTATE_CONTROL) & 0x8000) != 0;
      bool shift = (TerminalInfoInteger(TERMINAL_KEYSTATE_SHIFT) & 0x8000) != 0;
      if(ctrl && shift)
      {
         g_emergencyCloseRequested = true;
         Print("[Emergency] Ctrl+Shift+Q: close queued for the next timer pass.");
      }
      return;
   }

   if(!InpShowDashboard) return;
   if(!HandleChartEvent(id, lparam, dparam, sparam)) return;

   LogDebug("EMERGENCY CLOSE queued for the next timer pass.");
   g_emergencyCloseRequested = true;
}
