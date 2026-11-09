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
#property version   "14.053"
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
   
      // Record this EA's positions already open at startup.
   ArrayFree(g_state.ownedPositionIds);
   ArrayFree(g_state.positionItems);

   g_state.sellpositionCount       = 0;
   g_state.buypositionCount        = 0;
   g_state.positionCount           = 0;
   g_state.lowestSellPositionPrice = DBL_MAX;
   g_state.lowestSellPositionLot   = 0.0;
   g_state.highestBuyPositionPrice = 0.0;
   g_state.highestBuyPositionLot   = 0.0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_state.magicNumber)
         continue;

      long positionId = 0;
      int size = ArraySize(g_state.ownedPositionIds);

      if(!PositionGetInteger(POSITION_IDENTIFIER, positionId) ||
         positionId <= 0 ||
         ArrayResize(g_state.ownedPositionIds, size + 1, 16) != size + 1)
        {
         g_transactionQueueFailed = true;
         break;
        }

      g_state.ownedPositionIds[size] = (ulong)positionId;
      
      int index = ArraySize(g_state.positionItems);
      if(ArrayResize(g_state.positionItems, index + 1, 16) != index + 1)
        {
         g_transactionQueueFailed = true;
         break;
        }
      
      g_state.positionItems[index].identifier = (ulong)positionId;
      g_state.positionItems[index].ticket     = ticket;
      g_state.positionItems[index].side       =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      g_state.positionItems[index].entryPrice =
         PositionGetDouble(POSITION_PRICE_OPEN);
      g_state.positionItems[index].volume     =
         PositionGetDouble(POSITION_VOLUME);
         
      g_state.positionCount++;

      ENUM_POSITION_TYPE type = g_state.positionItems[index].side;
      double p   = g_state.positionItems[index].entryPrice;
      double lot = g_state.positionItems[index].volume;
      
      if(type == POSITION_TYPE_SELL)
        {
         g_state.sellpositionCount++;
      
         if(p < g_state.lowestSellPositionPrice)
           {
            g_state.lowestSellPositionPrice = p;
            g_state.lowestSellPositionLot   = lot;
           }
        }
      else if(type == POSITION_TYPE_BUY)
        {
         g_state.buypositionCount++;
      
         if(p > g_state.highestBuyPositionPrice)
           {
            g_state.highestBuyPositionPrice = p;
            g_state.highestBuyPositionLot   = lot;
           }
        }
     }
   
   if(!g_state.cleanupInProgress)
   ReSnapshotIfArmed(g_state);
   
   g_state.sessionAllowed = IsSessionAllowed();
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
                         g_state.magicNumber));
                         
   PrintFormat(
      "[SYMBOL DATA] symbol=%s tickValue=%.10f tickSize=%.10f accountCurrency=%s",
      _Symbol,
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE),
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE),
      AccountInfoString(ACCOUNT_CURRENCY));
   
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
