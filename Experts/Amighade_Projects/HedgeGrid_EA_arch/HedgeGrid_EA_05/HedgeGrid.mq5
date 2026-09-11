//+------------------------------------------------------------------+
//| HedgeGrid.mq5                                                     |
//| Main EA coordinator                                              |
//| Rules:                                                           |
//|   - Orchestrates all engine calls                                |
//|   - Engines own their logic                                      |
//|   - State is the only shared data between engines               |
//|   - No engine calls another engine directly                      |
//+------------------------------------------------------------------+
#property copyright "HedgeGrid EA"
#property version   "3.00"
#property strict

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

GridState g_state;

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   g_state.magicNumber = (InpMagicNumber == 0) ? GenerateMagicNumber() : InpMagicNumber;
   InitTradeUtils(g_state.magicNumber);
   if(!InitHistoryLogger()) LogDebug("Warning: History logger failed.");
   ResetGridState(g_state);
   g_state.sessionAllowed = IsSessionAllowed();
   g_state.lotMode        = CheckMargin(g_state);

   if(g_state.marginWarning)
     {
      if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < InpMinAllowedMargin)
        { LogDebug("CRITICAL: Insufficient margin. EA blocked."); return INIT_FAILED; }
     }

   InitDashboard();
   EventSetTimer(InpTimerIntervalSec);

   if(g_state.sessionAllowed)
     {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      BuildGrid(price, g_state.lotMode, g_state);
     }
   else LogDebug("Session not active. Grid built when session starts.");

   LogDebug(StringFormat("HedgeGrid started. Magic=%d Style=%s LotMode=%s",
                         g_state.magicNumber,
                         EnumToString(InpStrategyStyle),
                         g_state.lotMode==LOT_FULL?"FULL":"HALF"));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   SaveState(g_state);
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

   // Session started → build grid
   if(!prevSession && g_state.sessionAllowed && !g_state.gridPlaced)
     {
      g_state.lotMode = CheckMargin(g_state);
      BuildGrid(SymbolInfoDouble(_Symbol, SYMBOL_BID), g_state.lotMode, g_state);
      LogSessionChange(true, GetActiveSessionName());
     }

   // Session ended → log only (mid-cycle always completes by rules)
   if(prevSession && !g_state.sessionAllowed)
      LogSessionChange(false, "Session ended");

   // Update basket profit in state
   g_state.basketProfit = CalculateBasketProfit(g_state.magicNumber);

   // Recentering: fresh grid only, Style C returns false internally
   if(!g_state.cycleActive && g_state.gridPlaced)
     {
      if(ProcessRecentering(g_state))
         BuildGrid(SymbolInfoDouble(_Symbol, SYMBOL_BID), g_state.lotMode, g_state);
     }

   // SL check every tick
   if(g_state.cycleActive && !g_state.cleanupInProgress)
      ProcessSLManager(g_state);

   // Style C: coordinator reacts to SL hit flag set by SLManager
   // Winners already closed by SL — now close loser positions
   if(InpStrategyStyle == STYLE_C && g_state.c_SLHitDetected &&
      !g_state.cleanupInProgress)
     {
      g_state.c_SLHitDetected   = false;
      g_state.cleanupInProgress = true;
      g_state.cleanupStep       = 0;
      LogDebug("[Coordinator] Style C SL hit detected — starting loser close sequence.");
     }
}

//+------------------------------------------------------------------+
//| OnTradeTransaction                                                |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   // Only process relevant deal events
   bool isDeal = (trans.type == TRADE_TRANSACTION_DEAL_ADD    ||
                  trans.type == TRADE_TRANSACTION_DEAL_UPDATE  ||
                  trans.type == TRADE_TRANSACTION_DEAL_DELETE  ||
                  trans.type == TRADE_TRANSACTION_POSITION);

   if(!isDeal) return;
   if(trans.symbol != _Symbol) return;

   // ----------------------------------------------------------------
   // CLEANUP IN PROGRESS — close one position per confirmation
   // ----------------------------------------------------------------
   if(g_state.cleanupInProgress)
     {
      if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

      bool done = ExecuteNextCloseStep(g_state);

      if(done)
        {
         if(InpStrategyStyle == STYLE_C)
           {
            // Style C: coordinator calls refill and SL reset
            // (CleanupReset set the flags, coordinator acts on them)
            if(g_state.c_RefillNeeded)
               CheckAndRefill(g_state);       // GridBuilder
            if(g_state.c_ResetSLNeeded)
               ResetSLManager_C();            // SLManager
            // State flags already cleared inside ExecuteNextLoserClose_C
           }
         else
           {
            // Style A/B: full reset and rebuild
            ResetCycle(g_state);
            ClearState();
            if(g_state.sessionAllowed)
              {
               g_state.lotMode = CheckMargin(g_state);
               BuildGrid(SymbolInfoDouble(_Symbol,SYMBOL_BID), g_state.lotMode, g_state);
              }
           }
        }
      return;
     }

   // ----------------------------------------------------------------
   // NORMAL FLOW — order fill processing
   // ----------------------------------------------------------------
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(trans.deal_type != DEAL_TYPE_BUY && trans.deal_type != DEAL_TYPE_SELL) return;

   ulong positionTicket = trans.position;
   if(positionTicket == 0) return;

   // Gap fault check
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   ulong  faultTicket  = CheckGapFault(currentPrice, g_state.magicNumber);
   if(faultTicket != 0)
     {
      LogGapFault(0, currentPrice, faultTicket);
      g_state.gapFaultDetected = true;
      ExecuteEmergencyClose(g_state);
      if(InpStrategyStyle != STYLE_C) ResetCycle(g_state);
      return;
     }

   // Process fill → update state
   ProcessOrderFill(positionTicket, g_state);

   // Style A/B only: update lots and shift grid
   UpdateOppositeGrid(g_state);  // skips internally for Style C
   ShiftGrid(g_state);           // skips internally for Style C

   // SL check after fill
   ProcessSLManager(g_state);

   // Log and save
   LogHistory("ORDER_FILL",
              g_state.lastHitPrice,
              g_state.lastHitDirection==ORDER_TYPE_BUY?"BUY":"SELL",
              g_state.lastHitLot,
              g_state.passCounter,
              g_state.currentBlockLot,
              g_state.basketProfit,
              g_state.sessionAllowed,
              AccountInfoDouble(ACCOUNT_MARGIN_FREE));

   SaveState(g_state);
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
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   if(!InpShowDashboard) return;
   if(!HandleChartEvent(id, lparam, dparam, sparam)) return;

   LogDebug("EMERGENCY CLOSE triggered from dashboard.");
   ExecuteEmergencyClose(g_state);

   if(InpStrategyStyle == STYLE_C)
     {
      // Style C emergency already cleared orders + positions inside engine
      // Just reset SL state
      ResetSLManager_C();
     }
   else
     {
      ResetCycle(g_state);
      ClearState();
      if(g_state.sessionAllowed)
        {
         g_state.lotMode = CheckMargin(g_state);
         BuildGrid(SymbolInfoDouble(_Symbol,SYMBOL_BID), g_state.lotMode, g_state);
        }
     }
}
