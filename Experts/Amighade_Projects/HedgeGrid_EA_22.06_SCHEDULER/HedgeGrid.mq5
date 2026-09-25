//+------------------------------------------------------------------+
//| HedgeGrid.mq5                                                     |
//| Main EA coordinator — "brick" architecture + Rev 22 scheduler                |
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
#property version   "22.06"
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
//#include "Engines/ShiftingEngine.mqh"
#include "Engines/SLManager.mqh"
#include "Engines/CleanupReset.mqh"
//#include "Engines/Recentering.mqh"
#include "Dashboard/ChartPanel.mqh"
#include "Utils/StatePersistence.mqh"
#include "Engines/TimerEngine.mqh"

GridState g_state;
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
   
   // Start exactly ONE native timer. All larger task tiers are software
   // schedules evaluated from this heartbeat.
   if(!EventSetMillisecondTimer(InpSchedulerHeartbeatMs))
     {
      LogDebug(StringFormat("CRITICAL: EventSetMillisecondTimer(%d) failed. err=%d",
                            InpSchedulerHeartbeatMs, GetLastError()));
      return INIT_FAILED;
     }

   InitSchedulerRuntime();

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
   {
      ExecuteDeinitSafetyClose(g_state, "EA_DEINITIALIZATION");
      ResetSLManager(g_state);
   }

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
   ShutdownSchedulerRuntime();
}

//+------------------------------------------------------------------+
//| OnTradeTransaction                                               |
//|                                                                  |
//| Terminal callback = CAPTURE ONLY.                                |
//| 1) filter/copy the useful immutable fields                        |
//| 2) append them to the lossless transaction queue                  |
//| 3) return immediately                                             |
//|                                                                  |
//| Routing/classification is in TimerEngine.mqh.                     |
//| Strategy reactions are in ProcessFillWork(), not in this callback.|
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   MqlTradeTransactionShort item;

   if(!CaptureTradeTransaction(trans, request, result, g_state.magicNumber, item))
      return;

   QueueTransaction(item);
}

//+------------------------------------------------------------------+
//| OnTimer                                                           |
//| ONE native heartbeat. All software tiers share one global frame   |
//| budget. Tasks that are not finished simply remain pending for the  |
//| next heartbeat; broker waits never block this scheduler.           |
//+------------------------------------------------------------------+
void OnTimer()
{
   RunScheduler(g_state);
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


