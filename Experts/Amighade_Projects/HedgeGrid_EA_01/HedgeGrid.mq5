//+------------------------------------------------------------------+
//| HedgeGrid.mq5                                                     |
//| Main EA coordinator                                              |
//| Responsibilities:                                                |
//|   - Handle all MT5 event callbacks                               |
//|   - Call engines in correct sequence                             |
//|   - Never contain trading logic directly                         |
//|   - Own the single GridState instance                            |
//+------------------------------------------------------------------+
#property copyright "HedgeGrid EA"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| INCLUDE ORDER — respect dependency chain                          |
//| Inputs → Models → Utils → Engines → Dashboard                   |
//+------------------------------------------------------------------+
#include "Inputs.mqh"
#include "Models/GridState.mqh"

#include "Utils/DebugLogger.mqh"
#include "Utils/HistoryLogger.mqh"
#include "Utils/MathUtils.mqh"
#include "Utils/TradeUtils.mqh"
#include "Utils/SessionFilter.mqh"

#include "Engines/MarginCheck.mqh"
#include "Engines/SizingEngine.mqh"
#include "Engines/GridBuilder.mqh"
#include "Engines/OrderMonitor.mqh"
#include "Engines/GridUpdater.mqh"
#include "Engines/ShiftingEngine.mqh"
#include "Engines/SLManager.mqh"
#include "Engines/CleanupReset.mqh"
#include "Engines/StatePersistence.mqh"
#include "Engines/Recentering.mqh"

#include "Dashboard/ChartPanel.mqh"

//+------------------------------------------------------------------+
//| SINGLE GLOBAL STATE INSTANCE                                     |
//| All engines receive this by reference — never copy it            |
//+------------------------------------------------------------------+
GridState g_state;

//+------------------------------------------------------------------+
//| OnInit — called once when EA starts                              |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Resolve magic number
   g_state.magicNumber = (InpMagicNumber == 0) ?
                          GenerateMagicNumber() : InpMagicNumber;

   // Initialize trade utils with magic number
   InitTradeUtils(g_state.magicNumber);

   // Initialize loggers
   if(!InitHistoryLogger())
      LogDebug("Warning: History logger failed to initialize.");

   // Initialize fresh state
   ResetGridState(g_state);

   // Check session
   g_state.sessionAllowed = IsSessionAllowed();

   // Check margin and determine lot mode
   g_state.lotMode = CheckMargin(g_state);
   if(g_state.marginWarning && g_state.lotMode == LOT_HALF)
     {
      // If even half ladder is not affordable, block EA
      double freeMargin   = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double requiredHalf = GetRequiredMargin(LOT_HALF);
      if(freeMargin < InpMinAllowedMargin)
        {
         LogDebug("CRITICAL: Insufficient margin. EA blocked.");
         return INIT_FAILED;
        }
     }

   // Initialize dashboard
   InitDashboard();

   // Start periodic timer (for dashboard + margin refresh)
   EventSetTimer(InpTimerIntervalSec);

   // Place initial grid if session allows
   if(g_state.sessionAllowed)
     {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      BuildGrid(currentPrice, g_state.lotMode, g_state);
     }
   else
      LogDebug("Session not active. Grid will be built when session starts.");

   LogDebug(StringFormat("HedgeGrid started. Magic=%d Style=%s LotMode=%s",
                         g_state.magicNumber,
                         EnumToString(InpStrategyStyle),
                         g_state.lotMode == LOT_FULL ? "FULL" : "HALF"));

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| OnDeinit — called when EA stops                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Save state for potential reconnect recovery
   SaveState(g_state);

   // Clean up dashboard
   DeinitDashboard();

   // Close log files
   DeinitHistoryLogger();

   // Stop timer
   EventKillTimer();

   LogDebug(StringFormat("HedgeGrid stopped. Reason=%d", reason));
  }

//+------------------------------------------------------------------+
//| OnTick — called on every price tick                              |
//| Responsibilities:                                                |
//|   - Check session changes                                        |
//|   - Check recentering (fresh grid only)                          |
//|   - Update basket profit in state                                |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Update session status
   bool prevSession = g_state.sessionAllowed;
   g_state.sessionAllowed = IsSessionAllowed();

   // Session just started → build grid if none exists
   if(!prevSession && g_state.sessionAllowed && !g_state.gridPlaced)
     {
      g_state.lotMode = CheckMargin(g_state);
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      BuildGrid(currentPrice, g_state.lotMode, g_state);
      LogSessionChange(true, GetActiveSessionName());
     }

   // Session just ended → log it
   if(prevSession && !g_state.sessionAllowed)
     {
      LogSessionChange(false, "Session ended");
      // If CLOSE_ALL mode: trigger cleanup
      if(InpOutsideSessionAction == SESSION_CLOSE_ALL && !g_state.cleanupInProgress)
        {
         StartCleanupSequence(CLEANUP_EMERGENCY, g_state);
         ExecuteEmergencyClose(g_state);
        }
     }

   // Update basket profit
   g_state.basketProfit = CalculateBasketProfit();

   // Check recentering (only runs once per candle if fresh grid)
   if(!g_state.cycleActive && g_state.gridPlaced)
     {
      bool needsRebuild = ProcessRecentering(g_state);
      if(needsRebuild)
        {
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         BuildGrid(currentPrice, g_state.lotMode, g_state);
        }
     }

   // Check SL trigger on every tick (profit can turn positive any time)
   if(g_state.cycleActive && !g_state.slApplied && !g_state.cleanupInProgress)
      ProcessSLManager(g_state);
  }

//+------------------------------------------------------------------+
//| OnTradeTransaction — called on every trade event                 |
//| This is the CORE engine trigger                                  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   //--- Handle confirmation-based cleanup sequence
   if(g_state.cleanupInProgress)
     {
      // A position was just closed — execute next step
      if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
        {
         bool done = ExecuteNextCloseStep(g_state);
         if(done)
           {
            // Cycle complete — reset and rebuild
            ResetCycle(g_state);
            ClearState();

            // Rebuild grid if session allows
            if(g_state.sessionAllowed)
              {
               g_state.lotMode = CheckMargin(g_state);
               double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               BuildGrid(currentPrice, g_state.lotMode, g_state);
              }
           }
        }
      return; // Do not process other events during cleanup
     }

   //--- Only process order fills (new positions opening)
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(trans.deal_type != DEAL_TYPE_BUY && trans.deal_type != DEAL_TYPE_SELL) return;

   // Get the position ticket from this deal
   ulong positionTicket = trans.position;
   if(positionTicket == 0) return;

   //--- Check for gap fault first
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   ulong  faultTicket  = CheckGapFault(currentPrice, g_state.magicNumber);
   if(faultTicket != 0)
     {
      LogGapFault(OrderGetDouble(ORDER_PRICE_OPEN), currentPrice, faultTicket);
      g_state.gapFaultDetected = true;
      // Trigger emergency close on gap fault
      ExecuteEmergencyClose(g_state);
      ResetCycle(g_state);
      return;
     }

   //--- Process the order fill (updates state, counter, last hit info)
   bool directionSwitched = ProcessOrderFill(positionTicket, g_state);

   //--- Update opposite grid lot sizes
   UpdateOppositeGrid(g_state);

   //--- Shift opposite grid to new anchor
   ShiftGrid(g_state);

   //--- Check SL trigger after fill
   ProcessSLManager(g_state);

   //--- Log to history
   LogHistory("ORDER_FILL",
              g_state.lastHitPrice,
              g_state.lastHitDirection == ORDER_TYPE_BUY ? "BUY" : "SELL",
              g_state.lastHitLot,
              g_state.passCounter,
              g_state.currentBlockLot,
              g_state.basketProfit,
              g_state.sessionAllowed,
              AccountInfoDouble(ACCOUNT_MARGIN_FREE));

   //--- Save state after every fill
   SaveState(g_state);
  }

//+------------------------------------------------------------------+
//| OnTimer — called at fixed intervals                              |
//| Responsibilities:                                                |
//|   - Refresh dashboard                                            |
//|   - Periodic margin check                                        |
//+------------------------------------------------------------------+
void OnTimer()
  {
   // Refresh dashboard
   UpdateDashboard(g_state);

   // Periodic margin check (not every tick for performance)
   ENUM_LOT_MODE newLotMode = CheckMargin(g_state);
   if(newLotMode != g_state.lotMode && !g_state.cycleActive)
      g_state.lotMode = newLotMode; // Only update lot mode between cycles
  }

//+------------------------------------------------------------------+
//| OnChartEvent — handle dashboard button clicks                    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
  {
   if(!InpShowDashboard) return;

   bool emergencyPressed = HandleChartEvent(id, lparam, dparam, sparam);

   if(emergencyPressed)
     {
      LogDebug("EMERGENCY CLOSE triggered from dashboard.");
      ExecuteEmergencyClose(g_state);
      ResetCycle(g_state);
      ClearState();

      // Rebuild grid if session allows
      if(g_state.sessionAllowed)
        {
         g_state.lotMode = CheckMargin(g_state);
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         BuildGrid(currentPrice, g_state.lotMode, g_state);
        }
     }
  }
//+------------------------------------------------------------------+
