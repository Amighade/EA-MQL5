//+------------------------------------------------------------------+
//| TradeUtils.mqh                                                    |
//| Order placement, modification, deletion and close wrappers       |
//| Source: tested functions from CandleMultiOrder EA Rev 8.6        |
//| Key features:                                                    |
//|   - Automatic fill mode detection (IOC/RETURN/FOK)               |
//|   - Non-blocking async pending placement/deletion/SL modify      |
//|   - Single-attempt pending placement; rejected level is dropped  |
//|   - Retcode classification retained for synchronous close paths  |
//|   - Ticket-based partial-aware position close                    |
//+------------------------------------------------------------------+
#ifndef TRADE_UTILS_MQH
#define TRADE_UTILS_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "MathUtils.mqh"
#include "DebugLogger.mqh"
#include "ProfilerUtils.mqh"

//--- Working fill mode detected at OnInit, used for all orders
ENUM_ORDER_TYPE_FILLING g_fillMode = ORDER_FILLING_IOC;

//+------------------------------------------------------------------+
//| Result struct for all trade operations                           |
//+------------------------------------------------------------------+
struct TradeActionResult
{
   bool   success;
   bool   sent;
   uint   retcode;
   int    lastError;
   ulong  order;
};

//+------------------------------------------------------------------+
//| Classify retcode into retry strategy                             |
//+------------------------------------------------------------------+
enum SendFailAction { SEND_OK, RETRY_SAME, RETRY_WIDEN, FAIL_FATAL, FAIL_OTHER };

SendFailAction ClassifySendFailure(bool sent, const MqlTradeResult &res, int lastErr)
{
   switch(res.retcode)
     {
      case TRADE_RETCODE_DONE:
      case TRADE_RETCODE_PLACED:
      case TRADE_RETCODE_NO_CHANGES:
         return SEND_OK;

      case TRADE_RETCODE_REQUOTE:
      case TRADE_RETCODE_PRICE_CHANGED:
      case TRADE_RETCODE_TOO_MANY_REQUESTS:
      case TRADE_RETCODE_CONNECTION:
      case TRADE_RETCODE_TIMEOUT:
      case TRADE_RETCODE_LOCKED:
         return RETRY_SAME;

      case TRADE_RETCODE_PRICE_OFF:
      case TRADE_RETCODE_INVALID_PRICE:
      case TRADE_RETCODE_INVALID_STOPS:
      case TRADE_RETCODE_FROZEN:
         return RETRY_WIDEN;

      case TRADE_RETCODE_INVALID:
      case TRADE_RETCODE_INVALID_VOLUME:
      case TRADE_RETCODE_NO_MONEY:
      case TRADE_RETCODE_TRADE_DISABLED:
      case TRADE_RETCODE_MARKET_CLOSED:
         return FAIL_FATAL;

      default:
         return FAIL_OTHER;
     }
}

//+------------------------------------------------------------------+
//| Detect working fill mode at EA start                             |
//| Tests IOC → RETURN → FOK, uses first that passes OrderCheck      |
//+------------------------------------------------------------------+
void DetectWorkingFillMode()
{
   ENUM_ORDER_TYPE_FILLING modes[3] = {ORDER_FILLING_IOC, ORDER_FILLING_RETURN, ORDER_FILLING_FOK};
   string names[3] = {"IOC", "RETURN", "FOK"};
   MqlTradeCheckResult check;
   MqlTradeRequest req;

   for(int i = 0; i < 3; i++)
     {
      ZeroMemory(req);
      ZeroMemory(check);
      req.action       = TRADE_ACTION_DEAL;
      req.symbol       = _Symbol;
      req.type         = ORDER_TYPE_BUY;
      req.volume       = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      req.price        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.deviation    = 10;
      req.type_filling = modes[i];

      if(OrderCheck(req, check) && check.retcode == TRADE_RETCODE_DONE)
        {
         g_fillMode = modes[i];
         LogDebug(StringFormat("Fill mode detected: %s", names[i]));
         return;
        }
     }

   g_fillMode = ORDER_FILLING_IOC; // fallback
   LogDebug("No valid fill mode detected — using IOC fallback");
}

//+------------------------------------------------------------------+
//| Initialize trade utils — call once in OnInit                    |
//+------------------------------------------------------------------+
void InitTradeUtils(int magicNumber)
{
   DetectWorkingFillMode();
   LogDebug(StringFormat("TradeUtils initialized. Magic=%d", magicNumber));
}

//+------------------------------------------------------------------+
//| Async pending-placement tracking.                                |
//| - prevents duplicate submits while a request is still in flight; |
//| - remembers broker-rejected levels for the current grid cycle so |
//|   that exact level is dropped while later ladder levels continue.|
//+------------------------------------------------------------------+
struct AsyncPendingPlacementRequest
{
   uint            requestId;
   ENUM_ORDER_TYPE orderType;
   double          price;
   int             magicNumber;
   bool            brokerAccepted;
   ulong           orderTicket;
};

struct RejectedPendingLevel
{
   ENUM_ORDER_TYPE orderType;
   double          price;
   int             magicNumber;
};

AsyncPendingPlacementRequest g_asyncPendingPlacements[];
RejectedPendingLevel          g_rejectedPendingLevels[];

bool SamePendingLevel(ENUM_ORDER_TYPE orderType, double price, int magicNumber,
                      ENUM_ORDER_TYPE otherType, double otherPrice, int otherMagic)
{
   return (orderType == otherType &&
           magicNumber == otherMagic &&
           NearlyEqualPrice(price, otherPrice));
}

bool IsAsyncPendingPlacementOutstanding(ENUM_ORDER_TYPE orderType,
                                        double price, int magicNumber)
{
   for(int i = 0; i < ArraySize(g_asyncPendingPlacements); i++)
      if(SamePendingLevel(orderType, price, magicNumber,
                          g_asyncPendingPlacements[i].orderType,
                          g_asyncPendingPlacements[i].price,
                          g_asyncPendingPlacements[i].magicNumber))
         return true;
   return false;
}

bool IsRejectedPendingLevel(ENUM_ORDER_TYPE orderType,
                            double price, int magicNumber)
{
   for(int i = 0; i < ArraySize(g_rejectedPendingLevels); i++)
      if(SamePendingLevel(orderType, price, magicNumber,
                          g_rejectedPendingLevels[i].orderType,
                          g_rejectedPendingLevels[i].price,
                          g_rejectedPendingLevels[i].magicNumber))
         return true;
   return false;
}

void RememberRejectedPendingLevel(ENUM_ORDER_TYPE orderType,
                                  double price, int magicNumber)
{
   if(IsRejectedPendingLevel(orderType, price, magicNumber))
      return;

   int n = ArraySize(g_rejectedPendingLevels);
   ArrayResize(g_rejectedPendingLevels, n + 1);
   g_rejectedPendingLevels[n].orderType   = orderType;
   g_rejectedPendingLevels[n].price       = price;
   g_rejectedPendingLevels[n].magicNumber = magicNumber;
}

void RemoveAsyncPendingPlacement(int index)
{
   int last = ArraySize(g_asyncPendingPlacements) - 1;
   if(index < 0 || index > last) return;
   if(index != last)
     {
      g_asyncPendingPlacements[index].requestId      = g_asyncPendingPlacements[last].requestId;
      g_asyncPendingPlacements[index].orderType      = g_asyncPendingPlacements[last].orderType;
      g_asyncPendingPlacements[index].price          = g_asyncPendingPlacements[last].price;
      g_asyncPendingPlacements[index].magicNumber    = g_asyncPendingPlacements[last].magicNumber;
      g_asyncPendingPlacements[index].brokerAccepted = g_asyncPendingPlacements[last].brokerAccepted;
      g_asyncPendingPlacements[index].orderTicket    = g_asyncPendingPlacements[last].orderTicket;
     }
   ArrayResize(g_asyncPendingPlacements, last);
}

void TrackAsyncPendingPlacement(uint requestId, ENUM_ORDER_TYPE orderType,
                                double price, int magicNumber)
{
   int n = ArraySize(g_asyncPendingPlacements);
   ArrayResize(g_asyncPendingPlacements, n + 1);
   g_asyncPendingPlacements[n].requestId      = requestId;
   g_asyncPendingPlacements[n].orderType      = orderType;
   g_asyncPendingPlacements[n].price          = price;
   g_asyncPendingPlacements[n].magicNumber    = magicNumber;
   g_asyncPendingPlacements[n].brokerAccepted = false;
   g_asyncPendingPlacements[n].orderTicket    = 0;
}

bool ConsumeAsyncPendingPlacementResult(uint requestId, int retcode, ulong orderTicket)
{
   if(requestId == 0) return false;

   for(int i = 0; i < ArraySize(g_asyncPendingPlacements); i++)
     {
      if(g_asyncPendingPlacements[i].requestId != requestId)
         continue;

      bool success = (retcode == TRADE_RETCODE_DONE ||
                      retcode == TRADE_RETCODE_PLACED ||
                      retcode == TRADE_RETCODE_NO_CHANGES);

      if(success)
        {
         g_asyncPendingPlacements[i].brokerAccepted = true;
         if(orderTicket != 0)
            g_asyncPendingPlacements[i].orderTicket = orderTicket;
        }
      else
        {
         RememberRejectedPendingLevel(g_asyncPendingPlacements[i].orderType,
                                      g_asyncPendingPlacements[i].price,
                                      g_asyncPendingPlacements[i].magicNumber);
         RemoveAsyncPendingPlacement(i);
        }
      return true;
     }

   return false;
}

void ResolveAsyncPendingPlacementByOrderTicket(ulong orderTicket)
{
   if(orderTicket == 0) return;
   for(int i = ArraySize(g_asyncPendingPlacements) - 1; i >= 0; i--)
      if(g_asyncPendingPlacements[i].orderTicket == orderTicket)
         RemoveAsyncPendingPlacement(i);
}

void ReconcileAsyncPendingPlacements()
{
   for(int i = ArraySize(g_asyncPendingPlacements) - 1; i >= 0; i--)
     {
      bool live = false;
      for(int j = 0; j < OrdersTotal() && !live; j++)
        {
         ulong ticket = OrderGetTicket(j);
         if(!OrderSelect(ticket)) continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
         if(OrderGetInteger(ORDER_MAGIC) != g_asyncPendingPlacements[i].magicNumber) continue;
         if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != g_asyncPendingPlacements[i].orderType) continue;
         if(!NearlyEqualPrice(OrderGetDouble(ORDER_PRICE_OPEN), g_asyncPendingPlacements[i].price)) continue;
         live = true;
        }

      if(live)
         RemoveAsyncPendingPlacement(i);
     }
}

bool HasAsyncPendingPlacements()
{
   return (ArraySize(g_asyncPendingPlacements) > 0);
}

void ClearAsyncPendingPlacementCycleState()
{
   ArrayResize(g_asyncPendingPlacements, 0);
   ArrayResize(g_rejectedPendingLevels, 0);
}

//+------------------------------------------------------------------+
//| Core pending order placement — single attempt                    |
//+------------------------------------------------------------------+
TradeActionResult PlacePendingOrder(const string sym, ENUM_ORDER_TYPE orderType,
                                    double lot, double price, double sl, double tp,
                                    int magicNumber)
{
   ulong profFunctionStart = GetMicrosecondCount();
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};

   req.action       = TRADE_ACTION_PENDING;
   req.symbol       = sym;
   req.volume       = lot;
   req.type         = orderType;
   req.price        = NormalizeDouble(price, _Digits);
   req.sl           = NormalizeDouble(sl, _Digits);
   req.tp           = NormalizeDouble(tp, _Digits);
   req.magic        = magicNumber;
   req.deviation    = 10;
   req.type_filling = g_fillMode;
   req.type_time    = ORDER_TIME_GTC;

   ResetLastError();
   ZeroMemory(res);

   // REV 22.5: submit the pending order without waiting for the broker reply.
   // A successful return means the request was accepted for transmission; the
   // actual ORDER_ADD / REQUEST result arrives later through OnTradeTransaction.
   ulong profOrderSendStart = GetMicrosecondCount();
   bool sent = OrderSendAsync(req, res);
   int sendLastError = GetLastError();
   ProfilerRecord(PROF_ORDERSEND_PENDING, profOrderSendStart);

   TradeActionResult out;
   out.sent      = sent;
   out.success   = sent; // async submission accepted locally; server result is event-driven
   out.retcode   = res.retcode;
   out.lastError = sendLastError;
   out.order     = res.order; // may be zero for an async request; current EA callers do not depend on it

   if(sent)
      TrackAsyncPendingPlacement(res.request_id, orderType, req.price, magicNumber);

   ProfilerRecord(PROF_PLACE_PENDING_ORDER, profFunctionStart);
   return out;
}

//+------------------------------------------------------------------+
//| Place pending order once at the requested/clamped grid level.    |
//| REV 22.5: widening/retry loops are intentionally removed.        |
//| If this specific request is rejected, that level is simply       |
//| absent; later ladder levels keep their original price/lot pace.  |
//+------------------------------------------------------------------+
ulong PlacePendingSingleAttempt(const string sym, ENUM_ORDER_TYPE orderType,
                                double lot, double entry, double sl, double tp,
                                int magicNumber)
{
   ulong profFunctionStart = GetMicrosecondCount();
   double exactEntry = AlignToTick(sym, entry);

   // Do not duplicate an in-flight request, and do not retry a level that the
   // broker already rejected during this grid cycle. Later ladder levels are
   // still submitted normally by their existing loops.
   if(IsAsyncPendingPlacementOutstanding(orderType, exactEntry, magicNumber) ||
      IsRejectedPendingLevel(orderType, exactEntry, magicNumber))
     {
      ProfilerRecord(PROF_PLACE_PENDING_SINGLE, profFunctionStart);
      return 0;
     }

   TradeActionResult out = PlacePendingOrder(sym, orderType, lot, exactEntry,
                                             sl, tp, magicNumber);

   if(!out.success)
     {
      RememberRejectedPendingLevel(orderType, exactEntry, magicNumber);
      LogDebug(StringFormat("PlacePending async submit FAILED: type=%d price=%.2f lot=%.2f err=%d",
                            orderType, exactEntry, lot, out.lastError));
     }

   ProfilerRecord(PROF_PLACE_PENDING_SINGLE, profFunctionStart);

   // OrderSendAsync may not provide the final order ticket at submission time.
   // No current strategy caller uses this return value for control flow.
   return out.order;
}

//+------------------------------------------------------------------+
//| Convenience wrappers for BUY STOP and SELL STOP                  |
//+------------------------------------------------------------------+
ulong PlaceBuyStop(double price, double lot, int magicNumber, double sl=0, double tp=0)
{
   price = ClampPendingEntry(_Symbol, ORDER_TYPE_BUY_STOP, price);
   return PlacePendingSingleAttempt(_Symbol, ORDER_TYPE_BUY_STOP, lot, price, sl, tp, magicNumber);
}

ulong PlaceSellStop(double price, double lot, int magicNumber, double sl=0, double tp=0)
{
   price = ClampPendingEntry(_Symbol, ORDER_TYPE_SELL_STOP, price);
   return PlacePendingSingleAttempt(_Symbol, ORDER_TYPE_SELL_STOP, lot, price, sl, tp, magicNumber);
}

//+------------------------------------------------------------------+
//| Delete a pending order synchronously — DEINIT ONLY.              |
//| The EA is unloading in that path, so there is no future timer    |
//| heartbeat available to observe an asynchronous completion.       |
//+------------------------------------------------------------------+
bool DeleteOrderSync(ulong ticket)
{
   if(!OrderSelect(ticket))
      return true;

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action = TRADE_ACTION_REMOVE;
   req.order  = ticket;
   req.symbol = OrderGetString(ORDER_SYMBOL);
   req.magic  = (ulong)OrderGetInteger(ORDER_MAGIC);

   ResetLastError();
   bool sent = OrderSend(req, res);
   int sendLastError = GetLastError();

   if(!sent || (res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_PLACED))
     {
      LogDebug(StringFormat("DeleteOrderSync FAILED: ticket=%I64u rc=%d err=%d",
                            ticket, res.retcode, sendLastError));
      return false;
     }

   return true;
}

//+------------------------------------------------------------------+
//| Delete a pending order without waiting for broker response.      |
//| REV 22.5 normal runtime path.                                    |
//+------------------------------------------------------------------+
bool DeleteOrder(ulong ticket)
{
   ulong profFunctionStart = GetMicrosecondCount();

   if(!OrderSelect(ticket))
     {
      ProfilerRecord(PROF_DELETE_ORDER, profFunctionStart);
      return true; // already gone
     }

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action = TRADE_ACTION_REMOVE;
   req.order  = ticket;
   req.symbol = OrderGetString(ORDER_SYMBOL);
   req.magic  = (ulong)OrderGetInteger(ORDER_MAGIC);

   ResetLastError();
   ulong profOrderSendStart = GetMicrosecondCount();
   bool sent = OrderSendAsync(req, res);
   int sendLastError = GetLastError();
   ProfilerRecord(PROF_ORDERSEND_DELETE, profOrderSendStart);

   if(!sent)
     {
      LogDebug(StringFormat("DeleteOrder async submit FAILED: ticket=%I64u err=%d",
                            ticket, sendLastError));
      ProfilerRecord(PROF_DELETE_ORDER, profFunctionStart);
      return false;
     }

   ProfilerRecord(PROF_DELETE_ORDER, profFunctionStart);
   return true;
}
//+------------------------------------------------------------------+
//| Delete ALL pending orders for this EA on this symbol             |
//+------------------------------------------------------------------+
void DeleteAllOrders(int magicNumber)
{
   ulong sequence[];
   BuildProximityOrderOrder(magicNumber, sequence);   // inside-to-outside, same as before

   for(int i = 0; i < ArraySize(sequence); i++)
      DeleteOrder(sequence[i]);
}

//+------------------------------------------------------------------+
//| Send one position close WITHOUT blocking for broker response.    |
//| This is used by the scheduler cleanup engine. The request is not |
//| considered complete until OnTradeTransaction + reconciliation     |
//| confirm the position is actually gone.                            |
//+------------------------------------------------------------------+
bool SendClosePositionAsync(ulong ticket, uint &requestId)
{
   ulong profFunctionStart = GetMicrosecondCount();
   requestId = 0;

   if(!PositionSelectByTicket(ticket))
     {
      ProfilerRecord(PROF_SEND_CLOSE_ASYNC, profFunctionStart);
      return true; // Already gone — caller can treat the target as complete.
     }

   string sym = PositionGetString(POSITION_SYMBOL);
   double vol = PositionGetDouble(POSITION_VOLUME);
   int    typ = (int)PositionGetInteger(POSITION_TYPE);
   ulong  mg  = (ulong)PositionGetInteger(POSITION_MAGIC);

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = sym;
   req.position     = ticket;
   req.volume       = vol;
   req.type         = (typ == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
   req.price        = (typ == POSITION_TYPE_BUY ? SymbolInfoDouble(sym, SYMBOL_BID)
                                                : SymbolInfoDouble(sym, SYMBOL_ASK));
   req.magic        = mg;
   req.deviation    = 20; // Existing execution policy; not a CPU setting.
   req.type_filling = g_fillMode;
   req.type_time    = ORDER_TIME_GTC;

   ResetLastError();
   ulong profOrderSendStart = GetMicrosecondCount();
   bool sent = OrderSendAsync(req, res);
   int sendLastError = GetLastError();
   ProfilerRecord(PROF_ORDERSEND_ASYNC_CLOSE, profOrderSendStart);

   if(!sent)
     {
      LogDebug(StringFormat("SendClosePositionAsync FAILED: ticket=%I64u err=%d",
                            ticket, sendLastError));
      ResetLastError();
      ProfilerRecord(PROF_SEND_CLOSE_ASYNC, profFunctionStart);
      return false;
     }

   requestId = res.request_id;
   ProfilerRecord(PROF_SEND_CLOSE_ASYNC, profFunctionStart);
   return true;
}

//+------------------------------------------------------------------+
//| Send one pending-order deletion without waiting for completion.  |
//| Actual deletion is confirmed later by transaction/state checks.  |
//+------------------------------------------------------------------+
bool SendDeleteOrderAsync(ulong ticket, uint &requestId)
{
   ulong profFunctionStart = GetMicrosecondCount();
   requestId = 0;

   if(!OrderSelect(ticket))
     {
      ProfilerRecord(PROF_SEND_DELETE_ASYNC, profFunctionStart);
      return true; // Already gone.
     }

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action = TRADE_ACTION_REMOVE;
   req.order  = ticket;

   ResetLastError();
   ulong profOrderSendStart = GetMicrosecondCount();
   bool sent = OrderSendAsync(req, res);
   int sendLastError = GetLastError();
   ProfilerRecord(PROF_ORDERSEND_ASYNC_DELETE, profOrderSendStart);

   if(!sent)
     {
      LogDebug(StringFormat("SendDeleteOrderAsync FAILED: ticket=%I64u err=%d",
                            ticket, sendLastError));
      ResetLastError();
      ProfilerRecord(PROF_SEND_DELETE_ASYNC, profFunctionStart);
      return false;
     }

   requestId = res.request_id;
   ProfilerRecord(PROF_SEND_DELETE_ASYNC, profFunctionStart);
   return true;
}

//+------------------------------------------------------------------+
//| Core position close — ticket-based, partial-aware, with retries  |
//| Source: InternalClose() from CandleMultiOrder Rev 8.6            |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
   ulong profFunctionStart = GetMicrosecondCount();

   for(int attempt = 0; attempt < InpSafetyRetryAttempts; attempt++)
     {
      if(!PositionSelectByTicket(ticket))
        {
         ProfilerRecord(PROF_CLOSE_POSITION, profFunctionStart);
         return true; // already closed
        }

      string sym = PositionGetString(POSITION_SYMBOL);
      double vol = PositionGetDouble(POSITION_VOLUME);
      int    typ = (int)PositionGetInteger(POSITION_TYPE);
      ulong  mg  = (ulong)PositionGetInteger(POSITION_MAGIC);

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action       = TRADE_ACTION_DEAL;
      req.symbol       = sym;
      req.position     = ticket;
      req.volume       = vol;
      req.type         = (typ == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
      req.price        = (typ == POSITION_TYPE_BUY ? SymbolInfoDouble(sym, SYMBOL_BID)
                                                   : SymbolInfoDouble(sym, SYMBOL_ASK));
      req.magic        = mg;
      req.deviation    = 20;
      req.type_filling = g_fillMode;
      req.type_time    = ORDER_TIME_GTC;

      ulong profOrderSendStart = GetMicrosecondCount();
      bool sent = OrderSend(req, res);
      int sendLastError = GetLastError();
      ProfilerRecord(PROF_ORDERSEND_CLOSE_SYNC, profOrderSendStart);

      if(sent)
        {
         if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_DONE_PARTIAL)
           {
            ulong profSleepStart = GetMicrosecondCount();
            Sleep(20);
            ProfilerRecord(PROF_CLOSE_SLEEP, profSleepStart);
            if(!PositionSelectByTicket(ticket))
              {
               ProfilerRecord(PROF_CLOSE_POSITION, profFunctionStart);
               return true;
              }
            if(PositionGetDouble(POSITION_VOLUME) <= 0.0)
              {
               ProfilerRecord(PROF_CLOSE_POSITION, profFunctionStart);
               return true;
              }
            if(res.retcode == TRADE_RETCODE_DONE_PARTIAL)
              {
               profSleepStart = GetMicrosecondCount();
               Sleep(60);
               ProfilerRecord(PROF_CLOSE_SLEEP, profSleepStart);
               continue;
              }
            profSleepStart = GetMicrosecondCount();
            Sleep(80);
            ProfilerRecord(PROF_CLOSE_SLEEP, profSleepStart);
            continue;
           }
         else if(res.retcode == TRADE_RETCODE_REQUOTE ||
                 res.retcode == TRADE_RETCODE_PRICE_CHANGED ||
                 res.retcode == TRADE_RETCODE_TOO_MANY_REQUESTS)
           {
            ulong profSleepStart = GetMicrosecondCount();
            Sleep(60);
            ProfilerRecord(PROF_CLOSE_SLEEP, profSleepStart);
            continue;
           }
         else
           {
            LogDebug(StringFormat("ClosePosition FAILED: ticket=%I64u rc=%d", ticket, res.retcode));
            ProfilerRecord(PROF_CLOSE_POSITION, profFunctionStart);
            return false;
           }
        }
      else
        {
         LogDebug(StringFormat("ClosePosition OrderSend FAILED: ticket=%I64u err=%d attempt=%d",
                               ticket, sendLastError, attempt+1));
         ResetLastError();
         ulong profSleepStart = GetMicrosecondCount();
         Sleep(120);
         ProfilerRecord(PROF_CLOSE_SLEEP, profSleepStart);
        }
     }

   if(!PositionSelectByTicket(ticket))
     {
      ProfilerRecord(PROF_CLOSE_POSITION, profFunctionStart);
      return true;
     }
   LogDebug(StringFormat("ClosePosition: exhausted retries ticket=%I64u", ticket));
   ProfilerRecord(PROF_CLOSE_POSITION, profFunctionStart);
   return false;
}

//+------------------------------------------------------------------+
//| Fast close — send command and return immediately                 |
//| No verification. Use for non-critical batch closes.              |
//+------------------------------------------------------------------+
bool FastClosePosition(ulong ticket)
{
   ulong profFunctionStart = GetMicrosecondCount();
   if(!PositionSelectByTicket(ticket))
     {
      ProfilerRecord(PROF_FAST_CLOSE_POSITION, profFunctionStart);
      return true;
     }

   string sym = PositionGetString(POSITION_SYMBOL);
   double vol = PositionGetDouble(POSITION_VOLUME);
   int    typ = (int)PositionGetInteger(POSITION_TYPE);
   ulong  mg  = (ulong)PositionGetInteger(POSITION_MAGIC);

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = sym;
   req.position     = ticket;
   req.volume       = vol;
   req.type         = (typ == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
   req.price        = (typ == POSITION_TYPE_BUY ? SymbolInfoDouble(sym, SYMBOL_BID)
                                                : SymbolInfoDouble(sym, SYMBOL_ASK));
   req.magic        = mg;
   req.deviation    = 20;
   req.type_filling = g_fillMode;
   req.type_time    = ORDER_TIME_GTC;

   ulong profOrderSendStart = GetMicrosecondCount();
   bool sent = OrderSend(req, res);
   ProfilerRecord(PROF_ORDERSEND_FAST_CLOSE, profOrderSendStart);
   if(!sent) ResetLastError();
   ProfilerRecord(PROF_FAST_CLOSE_POSITION, profFunctionStart);
   return sent;
}

//+------------------------------------------------------------------+
//| Track async SL requests. One ticket may have only one request    |
//| outstanding at a time; this prevents 50 ms trailing cycles from  |
//| resubmitting the same SL while the broker reply is still pending.|
//+------------------------------------------------------------------+
struct AsyncSLModifyRequest
{
   uint   requestId;
   ulong  ticket;
   double targetSL;
   bool   brokerAccepted;
};

AsyncSLModifyRequest g_asyncSLModifyRequests[];

bool HasPendingSLModify(ulong ticket)
{
   for(int i = 0; i < ArraySize(g_asyncSLModifyRequests); i++)
      if(g_asyncSLModifyRequests[i].ticket == ticket)
         return true;
   return false;
}

void TrackAsyncSLModifyRequest(uint requestId, ulong ticket, double targetSL)
{
   if(requestId == 0) return;
   int n = ArraySize(g_asyncSLModifyRequests);
   ArrayResize(g_asyncSLModifyRequests, n + 1);
   g_asyncSLModifyRequests[n].requestId      = requestId;
   g_asyncSLModifyRequests[n].ticket         = ticket;
   g_asyncSLModifyRequests[n].targetSL       = targetSL;
   g_asyncSLModifyRequests[n].brokerAccepted = false;
}

void RemoveAsyncSLModifyRequest(int index)
{
   int last = ArraySize(g_asyncSLModifyRequests) - 1;
   if(index < 0 || index > last) return;
   if(index != last)
     {
      g_asyncSLModifyRequests[index].requestId      = g_asyncSLModifyRequests[last].requestId;
      g_asyncSLModifyRequests[index].ticket         = g_asyncSLModifyRequests[last].ticket;
      g_asyncSLModifyRequests[index].targetSL       = g_asyncSLModifyRequests[last].targetSL;
      g_asyncSLModifyRequests[index].brokerAccepted = g_asyncSLModifyRequests[last].brokerAccepted;
     }
   ArrayResize(g_asyncSLModifyRequests, last);
}

bool ConsumeAsyncSLModifyResult(uint requestId, int retcode,
                                ulong &ticket, bool &success)
{
   ticket = 0;
   success = false;
   if(requestId == 0) return false;

   for(int i = 0; i < ArraySize(g_asyncSLModifyRequests); i++)
     {
      if(g_asyncSLModifyRequests[i].requestId != requestId)
         continue;

      ticket = g_asyncSLModifyRequests[i].ticket;
      success = (retcode == TRADE_RETCODE_DONE ||
                 retcode == TRADE_RETCODE_NO_CHANGES ||
                 retcode == TRADE_RETCODE_PLACED);

      if(success)
         g_asyncSLModifyRequests[i].brokerAccepted = true;
      else
         RemoveAsyncSLModifyRequest(i);

      return true;
     }

   return false;
}

void ReconcileAsyncSLModifyRequests()
{
   for(int i = ArraySize(g_asyncSLModifyRequests) - 1; i >= 0; i--)
     {
      ulong ticket = g_asyncSLModifyRequests[i].ticket;
      if(!PositionSelectByTicket(ticket))
        {
         RemoveAsyncSLModifyRequest(i);
         continue;
        }

      if(!g_asyncSLModifyRequests[i].brokerAccepted)
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double actualSL = NormalizeDouble(PositionGetDouble(POSITION_SL), digits);
      double targetSL = NormalizeDouble(g_asyncSLModifyRequests[i].targetSL, digits);

      if(actualSL == targetSL && targetSL > 0.0)
         RemoveAsyncSLModifyRequest(i);
     }
}

//+------------------------------------------------------------------+
//| Modify SL without waiting for broker response.                   |
//| REV 22.5: one async request; broker-side rejection is correlated |
//| later by request_id and routed to the existing safety stop.      |
//+------------------------------------------------------------------+
bool ModifyPositionSL(ulong ticket, double newSL)
{
   ulong profFunctionStart = GetMicrosecondCount();

   if(!PositionSelectByTicket(ticket))
     {
      ProfilerRecord(PROF_MODIFY_POSITION_SL, profFunctionStart);
      return false;
     }

   // Do not submit another SL request for this ticket until the previous
   // asynchronous modification has been confirmed/reconciled.
   if(HasPendingSLModify(ticket))
     {
      ProfilerRecord(PROF_MODIFY_POSITION_SL, profFunctionStart);
      return true;
     }

   double safeSL = ValidateStopPrice(ticket, newSL);
   if(safeSL <= 0.0)
     {
      ProfilerRecord(PROF_MODIFY_POSITION_SL, profFunctionStart);
      return false;
     }

   string symbol = PositionGetString(POSITION_SYMBOL);
   double curTP  = PositionGetDouble(POSITION_TP);
   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action   = TRADE_ACTION_SLTP;
   req.position = ticket;
   req.symbol   = symbol;
   req.sl       = NormalizeDouble(safeSL, digits);
   req.tp       = curTP;

   ResetLastError();
   ulong profOrderSendStart = GetMicrosecondCount();
   bool sent = OrderSendAsync(req, res);
   int sendLastError = GetLastError();
   ProfilerRecord(PROF_ORDERSEND_MODIFY_SL, profOrderSendStart);

   if(!sent)
     {
      LogDebug(StringFormat("ModifyPositionSL async submit FAILED: ticket=%I64u sl=%.2f err=%d",
                            ticket, safeSL, sendLastError));
      ProfilerRecord(PROF_MODIFY_POSITION_SL, profFunctionStart);
      return false;
     }

   TrackAsyncSLModifyRequest(res.request_id, ticket, req.sl);
   ProfilerRecord(PROF_MODIFY_POSITION_SL, profFunctionStart);
   return true;
}

//+------------------------------------------------------------------+
//| Count open positions for this EA on this symbol                  |
//+------------------------------------------------------------------+
int CountPositions(int magicNumber)
{
   ulong profFunctionStart = GetMicrosecondCount();
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      count++;
     }
   ProfilerRecord(PROF_COUNT_POSITIONS, profFunctionStart);
   return count;
}

//+------------------------------------------------------------------+
//| Count pending orders for this EA on this symbol                  |
//+------------------------------------------------------------------+
int CountOrders(int magicNumber)
{
   ulong profFunctionStart = GetMicrosecondCount();
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;
      count++;
     }
   ProfilerRecord(PROF_COUNT_ORDERS, profFunctionStart);
   return count;
}

//+------------------------------------------------------------------+
//| Count pending orders by type                                     |
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
//| Check if grid is in fresh state                                  |
//| Fresh = no open positions AND full count of pending orders       |
//+------------------------------------------------------------------+
bool IsGridFresh(int magicNumber)
{
   return (CountPositions(magicNumber) == 0 &&
           CountOrders(magicNumber) == InpInitialGridLevels * 2);
}

//+------------------------------------------------------------------+
//| Human-readable retcode string for logging                        |
//+------------------------------------------------------------------+
string RetcodeToString(int code)
{
   switch(code)
     {
      case TRADE_RETCODE_REQUOTE:           return "Requote";
      case TRADE_RETCODE_REJECT:            return "Rejected";
      case TRADE_RETCODE_PLACED:            return "Order placed";
      case TRADE_RETCODE_DONE:              return "Done";
      case TRADE_RETCODE_DONE_PARTIAL:      return "Done partial";
      case TRADE_RETCODE_ERROR:             return "Error";
      case TRADE_RETCODE_TIMEOUT:           return "Timeout";
      case TRADE_RETCODE_INVALID:           return "Invalid";
      case TRADE_RETCODE_INVALID_VOLUME:    return "Invalid volume";
      case TRADE_RETCODE_INVALID_PRICE:     return "Invalid price";
      case TRADE_RETCODE_INVALID_STOPS:     return "Invalid stops";
      case TRADE_RETCODE_TRADE_DISABLED:    return "Trading disabled";
      case TRADE_RETCODE_MARKET_CLOSED:     return "Market closed";
      case TRADE_RETCODE_NO_MONEY:          return "No money";
      case TRADE_RETCODE_PRICE_CHANGED:     return "Price changed";
      case TRADE_RETCODE_PRICE_OFF:         return "No quotes";
      case TRADE_RETCODE_NO_CHANGES:        return "No changes";
      case TRADE_RETCODE_LOCKED:            return "Locked";
      case TRADE_RETCODE_FROZEN:            return "Frozen";
      case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Too many requests";
      case TRADE_RETCODE_CONNECTION:        return "No connection";
      default:                              return StringFormat("Unknown(%d)", code);
     }
}

#endif
