//+------------------------------------------------------------------+
//| DebugLogger.mqh                                                   |
//| Debug logging to Experts tab                                     |
//| All log calls are no-ops if InpEnableDebugLog is false           |
//+------------------------------------------------------------------+
#pragma once

#include "../Inputs.mqh"

//+------------------------------------------------------------------+
//| Log a general message                                             |
//+------------------------------------------------------------------+
void LogDebug(string message)
  {
   if(!InpEnableDebugLog) return;
   PrintFormat("[HedgeGrid][%s] %s", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), message);
  }

//+------------------------------------------------------------------+
//| Log grid built event                                              |
//+------------------------------------------------------------------+
void LogGridBuilt(double anchorBuy, double anchorSell, string lotMode)
  {
   if(!InpEnableDebugLog) return;
   PrintFormat("[HedgeGrid][GRID_BUILT] BuyAnchor=%.2f SellAnchor=%.2f LotMode=%s",
               anchorBuy, anchorSell, lotMode);
  }

//+------------------------------------------------------------------+
//| Log order filled event                                            |
//+------------------------------------------------------------------+
void LogOrderFilled(ulong ticket, string direction, double lot, double price)
  {
   if(!InpEnableDebugLog) return;
   PrintFormat("[HedgeGrid][ORDER_FILLED] Ticket=%I64u Direction=%s Lot=%.2f Price=%.2f",
               ticket, direction, lot, price);
  }

//+------------------------------------------------------------------+
//| Log pass counter update                                           |
//+------------------------------------------------------------------+
void LogCounterUpdate(int oldCounter, int newCounter)
  {
   if(!InpEnableDebugLog) return;
   PrintFormat("[HedgeGrid][COUNTER] %d → %d", oldCounter, newCounter);
  }

//+------------------------------------------------------------------+
//| Log grid shift event                                              |
//+------------------------------------------------------------------+
void LogGridShifted(string direction, double oldAnchor, double newAnchor, double blockLot)
  {
   if(!InpEnableDebugLog) return;
   PrintFormat("[HedgeGrid][GRID_SHIFTED] Direction=%s OldAnchor=%.2f NewAnchor=%.2f BlockLot=%.2f",
               direction, oldAnchor, newAnchor, blockLot);
  }

//+------------------------------------------------------------------+
//| Log lot update event                                              |
//+------------------------------------------------------------------+
void LogLotUpdated(int ordersUpdated, double oldLot, double newLot)
  {
   if(!InpEnableDebugLog) return;
   PrintFormat("[HedgeGrid][LOT_UPDATED] OrdersUpdated=%d OldLot=%.2f NewLot=%.2f",
               ordersUpdated, oldLot, newLot);
  }

//+------------------------------------------------------------------+
//| Log SL trigger event                                              |
//+------------------------------------------------------------------+
void LogSLTriggered(string triggerType, double slLevel)
  {
   if(!InpEnableDebugLog) return;
   PrintFormat("[HedgeGrid][SL_TRIGGERED] TriggerType=%s SLLevel=%.2f",
               triggerType, slLevel);
  }

//+------------------------------------------------------------------+
//| Log cleanup started                                               |
//+------------------------------------------------------------------+
void LogCleanupStarted(string cleanupType)
  {
   if(!InpEnableDebugLog) return;
   PrintFormat("[HedgeGrid][CLEANUP_START] Type=%s", cleanupType);
  }

//+------------------------------------------------------------------+
//| Log cleanup complete                                              |
//+------------------------------------------------------------------+
void LogCleanupComplete()
  {
   if(!InpEnableDebugLog) return;
   PrintFormat("[HedgeGrid][CLEANUP_DONE] Cycle complete. Rebuilding grid.");
  }

//+------------------------------------------------------------------+
//| Log margin warning                                               |
//+------------------------------------------------------------------+
void LogMarginWarning(double freeMargim, double required)
  {
   if(!InpEnableDebugLog) return;
   PrintFormat("[HedgeGrid][MARGIN_WARNING] FreeMargin=%.2f Required=%.2f Switching to half ladder.",
               freeMargim, required);
  }

//+------------------------------------------------------------------+
//| Log gap/fault detection                                           |
//+------------------------------------------------------------------+
void LogGapFault(double expectedPrice, double currentPrice, ulong ticket)
  {
   if(!InpEnableDebugLog) return;
   PrintFormat("[HedgeGrid][GAP_FAULT] Order #%I64u skipped. Expected fill at %.2f, price now %.2f. BROKER FAULT.",
               ticket, expectedPrice, currentPrice);
  }

//+------------------------------------------------------------------+
//| Log session change                                                |
//+------------------------------------------------------------------+
void LogSessionChange(bool isAllowed, string sessionName)
  {
   if(!InpEnableDebugLog) return;
   PrintFormat("[HedgeGrid][SESSION] %s - Trading %s",
               sessionName, isAllowed ? "ALLOWED" : "BLOCKED");
  }

//+------------------------------------------------------------------+
//| Log recentering event                                             |
//+------------------------------------------------------------------+
void LogRecentering(double oldAnchor, double newAnchor)
  {
   if(!InpEnableDebugLog) return;
   PrintFormat("[HedgeGrid][RECENTER] OldAnchor=%.2f NewAnchor=%.2f", oldAnchor, newAnchor);
  }
