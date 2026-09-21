//+------------------------------------------------------------------+
//| TradeUtils.mqh                                                    |
//| Order placement, deletion, and modification wrappers             |
//| All trade operations go through here — never call OrderSend      |
//| directly from engines                                            |
//+------------------------------------------------------------------+
#pragma once

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "DebugLogger.mqh"
#include <Trade\Trade.mqh>

// Single CTrade instance used by all engines
// Engines must NOT create their own CTrade instances
CTrade g_trade;

//+------------------------------------------------------------------+
//| Initialize trade object — call once in OnInit                    |
//+------------------------------------------------------------------+
void InitTradeUtils(int magicNumber)
  {
   g_trade.SetExpertMagicNumber(magicNumber);
   g_trade.SetDeviationInPoints(10);       // 1 pip slippage tolerance
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);     // Only log errors, not every trade
  }

//+------------------------------------------------------------------+
//| Place a BUY STOP pending order                                    |
//| Returns ticket on success, 0 on failure                          |
//+------------------------------------------------------------------+
ulong PlaceBuyStop(double price, double lot, double sl = 0, double tp = 0)
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // BUY STOP must be above current ask
   if(price <= ask)
     {
      LogDebug(StringFormat("PlaceBuyStop skipped: price %.2f <= ask %.2f", price, ask));
      return 0;
     }

   bool result = g_trade.BuyStop(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0,
                                 StringFormat("HG_BS_%.2f", price));
   if(!result)
     {
      LogDebug(StringFormat("PlaceBuyStop FAILED: price=%.2f lot=%.2f error=%d",
                            price, lot, GetLastError()));
      return 0;
     }
   return g_trade.ResultOrder();
  }

//+------------------------------------------------------------------+
//| Place a SELL STOP pending order                                   |
//| Returns ticket on success, 0 on failure                          |
//+------------------------------------------------------------------+
ulong PlaceSellStop(double price, double lot, double sl = 0, double tp = 0)
  {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // SELL STOP must be below current bid
   if(price >= bid)
     {
      LogDebug(StringFormat("PlaceSellStop skipped: price %.2f >= bid %.2f", price, bid));
      return 0;
     }

   bool result = g_trade.SellStop(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0,
                                  StringFormat("HG_SS_%.2f", price));
   if(!result)
     {
      LogDebug(StringFormat("PlaceSellStop FAILED: price=%.2f lot=%.2f error=%d",
                            price, lot, GetLastError()));
      return 0;
     }
   return g_trade.ResultOrder();
  }

//+------------------------------------------------------------------+
//| Delete a pending order by ticket                                  |
//| Returns true on success                                          |
//+------------------------------------------------------------------+
bool DeleteOrder(ulong ticket)
  {
   bool result = g_trade.OrderDelete(ticket);
   if(!result)
      LogDebug(StringFormat("DeleteOrder FAILED: ticket=%I64u error=%d", ticket, GetLastError()));
   return result;
  }

//+------------------------------------------------------------------+
//| Delete ALL pending orders for this EA on this symbol             |
//+------------------------------------------------------------------+
void DeleteAllOrders(int magicNumber)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;
      DeleteOrder(ticket);
     }
  }

//+------------------------------------------------------------------+
//| Modify SL of an open position                                     |
//| Returns true on success                                          |
//+------------------------------------------------------------------+
bool ModifyPositionSL(ulong ticket, double newSL)
  {
   bool result = g_trade.PositionModify(ticket, newSL,
                                        PositionGetDouble(POSITION_TP));
   if(!result)
      LogDebug(StringFormat("ModifyPositionSL FAILED: ticket=%I64u sl=%.2f error=%d",
                            ticket, newSL, GetLastError()));
   return result;
  }

//+------------------------------------------------------------------+
//| Close an open position by ticket                                  |
//| Returns true on success                                          |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
     {
      LogDebug(StringFormat("ClosePosition: ticket %I64u not found", ticket));
      return false;
     }
   bool result = g_trade.PositionClose(ticket, 10); // 10 point slippage
   if(!result)
      LogDebug(StringFormat("ClosePosition FAILED: ticket=%I64u error=%d", ticket, GetLastError()));
   return result;
  }

//+------------------------------------------------------------------+
//| Count open positions for this EA on this symbol                  |
//+------------------------------------------------------------------+
int CountPositions(int magicNumber)
  {
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//| Count pending orders for this EA on this symbol                  |
//+------------------------------------------------------------------+
int CountOrders(int magicNumber)
  {
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;
      count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//| Count pending orders by type for this EA                         |
//+------------------------------------------------------------------+
int CountOrdersByType(int magicNumber, ENUM_ORDER_TYPE orderType)
  {
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != orderType) continue;
      count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//| Check if grid is in fresh state                                   |
//| Fresh = no positions open AND exactly InpGridLevels*2 orders     |
//+------------------------------------------------------------------+
bool IsGridFresh(int magicNumber)
  {
   int positions = CountPositions(magicNumber);
   int orders    = CountOrders(magicNumber);
   return (positions == 0 && orders == InpGridLevels * 2);
  }
