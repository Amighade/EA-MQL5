//+------------------------------------------------------------------+
//| DebugLogger.mqh                                                   |
//| Debug display and logging for CandleMultiOrder EA               |
//+------------------------------------------------------------------+
#ifndef CMO_DEBUG_LOGGER_MQH
#define CMO_DEBUG_LOGGER_MQH

#include "../Inputs.mqh"
#include "../Models/EAState.mqh"
#include "MathUtils.mqh"
#include "SessionFilter.mqh"

//+------------------------------------------------------------------+
//| Display all debug info in chart comment                          |
//+------------------------------------------------------------------+
void DisplayDebugging()
{
   datetime utcNow           = GetUTCTime();
   double   minStopDistPoints= (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double   freeze           = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double   tick_size        = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double   tick_value       = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   int      buyCount         = DM_Count(POSITION_TYPE_BUY);
   int      sellCount        = DM_Count(POSITION_TYPE_SELL);
   double   buyProfit        = NormalizeDouble(DM_NetProfit(POSITION_TYPE_BUY),  2);
   double   sellProfit       = NormalizeDouble(DM_NetProfit(POSITION_TYPE_SELL), 2);
   double   netProfit        = DM_NetProfit();
   double   floatingNet      = AccountInfoDouble(ACCOUNT_EQUITY) - AccountInfoDouble(ACCOUNT_BALANCE);

   string txt = TimeToString(utcNow, TIME_DATE|TIME_SECONDS) + " " + _Symbol + ":\n";

   txt += StringFormat("minStop:%.5f freeze:%.5f point:%.5f digits:%d tickSz:%.5f tickVal:%.5f MinLot:%.5f comm:%.2f\n\n",
                       minStopDistPoints, freeze, gPoint, _Digits,
                       tick_size, tick_value, gMinLot, gCommissionPerLot);

   txt += "ABWCL Status:\n";
   txt += StringFormat("  SL_winner:%.5f  SL_loser:%.5f  ArmedSL:%.5f\n",
                       gABWCL_SL_winner, gABWCL_SL_loser, gArmedSL);
   txt += StringFormat("  Epoch:%d  WinnerSide:%s\n",
                       gArmEpoch,
                       gABWCLWinnerSide==POSITION_TYPE_BUY ? "BUY" :
                       gABWCLWinnerSide==POSITION_TYPE_SELL? "SELL": "NONE");
   txt += StringFormat("  WinnerTickets:%d  LoserTickets:%d\n",
                       ArraySize(gEpochWinnerTickets), ArraySize(gEpochLoserTickets));
   txt += StringFormat("  buy#:%d  sell#:%d\n", buyCount, sellCount);
   txt += StringFormat("  buyPnL:%.2f  sellPnL:%.2f  netPnL:%.2f  floatNet:%.2f\n",
                       buyProfit, sellProfit, netProfit, floatingNet);
   txt += StringFormat("  gABWCLArmed:%s\n",          gABWCLArmed         ? "YES":"NO");
   txt += StringFormat("  gCompressionActive:%s\n",   gCompressionActive  ? "YES":"NO");
   txt += StringFormat("  gCompressionKeepTarget:%d\n",gCompressionKeepTarget);
   txt += StringFormat("  gBudgetExhausted:%s\n",     gBudgetExhausted    ? "YES":"NO");
   txt += StringFormat("  gbuyEntry_range:%.2f  gsellEntry_range:%.2f\n",
                       gbuyEntry_range, gsellEntry_range);

   txt += "\n====================\n";
   txt += StringFormat(
      "DEBUGGING:\n"
      "  gdebugB01:%s\n"
      "  gdebugI01:%d  gdebugI02:%d  gdebugI03:%d\n"
      "  gdebugD01:%.5f  gdebugD02:%.5f\n"
      "  gdebugD03:%.5f  gdebugD04:%.5f\n"
      "  gdebugS01:%s\n"
      "  gbuyEntry:%.5f  gsellEntry:%.5f\n",
      gdebugB01?"true":"false",
      gdebugI01, gdebugI02, gdebugI03,
      gdebugD01, gdebugD02,
      gdebugD03, gdebugD04,
      gdebugS01,
      gbuyEntry, gsellEntry);

   txt += StringFormat("\n  resonanceScore:%.2f\n  resonanceRange:%.2f\n  resonanceDir:%s\n",
                       resonanceScore, resonanceRange, resonanceDirection);

   Comment(txt);
}

//+------------------------------------------------------------------+
//| Print broker fill mode support info                              |
//+------------------------------------------------------------------+
void PrintBrokerFillingSupport()
{
   long modes = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   PrintFormat("SYMBOL_FILLING_MODE = %d", modes);

   MqlTradeCheckResult check;
   MqlTradeRequest     req;
   ENUM_ORDER_TYPE_FILLING fills[3] = {ORDER_FILLING_FOK, ORDER_FILLING_IOC, ORDER_FILLING_RETURN};
   string names[3] = {"FOK","IOC","RETURN"};

   for(int i = 0; i < 3; i++)
     {
      ZeroMemory(req); ZeroMemory(check);
      req.action       = TRADE_ACTION_DEAL;
      req.symbol       = _Symbol;
      req.type         = ORDER_TYPE_BUY;
      req.volume       = 0.01;
      req.price        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.deviation    = 10;
      req.type_filling = fills[i];
      bool ok = OrderCheck(req, check);
      PrintFormat("  %s: ok=%d retcode=%d (%s)", names[i], ok, check.retcode, check.comment);
     }
}

#endif
