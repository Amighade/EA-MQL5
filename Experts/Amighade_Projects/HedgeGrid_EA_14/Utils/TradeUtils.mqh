//+------------------------------------------------------------------+
//| TradeUtils.mqh                                                    |
//| Order placement, modification, deletion and close wrappers       |
//| Source: tested functions from CandleMultiOrder EA Rev 8.6        |
//| Key features:                                                    |
//|   - Automatic fill mode detection (IOC/RETURN/FOK)               |
//|   - Retry logic with price widening on rejection                 |
//|   - Retcode classification for smart retry decisions             |
//|   - Ticket-based partial-aware position close                    |
//+------------------------------------------------------------------+
#ifndef TRADE_UTILS_MQH
#define TRADE_UTILS_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"
#include "MathUtils.mqh"
#include "DebugLogger.mqh"

//--- Working fill mode detected at OnInit, used for all orders
ENUM_ORDER_TYPE_FILLING g_fillMode = ORDER_FILLING_IOC;

//--- Max widening steps before giving up on a placement
#define WIDEN_MAX_STEPS 10

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
//| Calculate widened entry price for retry after rejection          |
//| Widens away from market by a small buffer per step               |
//+------------------------------------------------------------------+
double WidenPendingEntry(const string sym, ENUM_ORDER_TYPE type, double entry, int stepCount)
{
   if(stepCount <= 0)
      return AlignToTick(sym, entry);

   double ask    = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(sym, SYMBOL_BID);
   double spread = ask - bid;

   double tick   = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0) tick = _Point;

   double stops  = MinStopDistancePrice(sym);
   double freeze = (double)SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   double base   = stops + freeze + 2.0 * tick;
   double dist   = base + stepCount * spread * 0.2;

   if(type == ORDER_TYPE_BUY_STOP)
      entry += dist;
   else if(type == ORDER_TYPE_SELL_STOP)
      entry -= dist;

   return AlignToTick(sym, entry);
}

//+------------------------------------------------------------------+
//| Core pending order placement — single attempt                    |
//+------------------------------------------------------------------+
TradeActionResult PlacePendingOrder(const string sym, ENUM_ORDER_TYPE orderType,
                                    double lot, double price, double sl, double tp,
                                    int magicNumber)
{
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

   bool sent = OrderSend(req, res);

   TradeActionResult out;
   out.sent      = sent;
   out.success   = sent && (res.retcode == TRADE_RETCODE_DONE ||
                            res.retcode == TRADE_RETCODE_PLACED ||
                            res.retcode == TRADE_RETCODE_NO_CHANGES);
   out.retcode   = res.retcode;
   out.lastError = GetLastError();
   out.order = res.order;

   return out;
}

//+------------------------------------------------------------------+
//| Place pending order with automatic price widening on rejection   |
//| Returns ticket of placed order, 0 on failure                    |
//+------------------------------------------------------------------+
ulong PlacePendingWithWidening(const string sym, ENUM_ORDER_TYPE orderType,
                               double lot, double entry, double sl, double tp,
                               int magicNumber)
{
   for(int step = 0; step <= WIDEN_MAX_STEPS; step++)
     {
      double tryEntry = WidenPendingEntry(sym, orderType, entry, step);

      for(int attempt = 1; attempt <= 3; attempt++)
        {
         TradeActionResult out = PlacePendingOrder(sym, orderType, lot, tryEntry, sl, tp, magicNumber);

         if(out.success)
            return out.order;
           /*{
            // Get the ticket of placed order
            for(int i = OrdersTotal()-1; i >= 0; i--)
              {
               ulong t = OrderGetTicket(i);
               if(!OrderSelect(t)) continue;
               if(OrderGetString(ORDER_SYMBOL) != sym) continue;
               if(OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;
               if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - tryEntry) < _Point * 2)
                  return t;
              }
            return 0; // placed but couldn't get ticket
           }        // Rebuild MqlTradeResult because MQL5 does not support compound literals
            */ 
         MqlTradeResult res = {};

         res.retcode = out.retcode;
         SendFailAction action = ClassifySendFailure(out.sent, res, out.lastError);
         if(action == RETRY_SAME && attempt < 3) { Sleep(50 * attempt); continue; }
         if(action == RETRY_WIDEN) break; // try next step
         if(action == FAIL_FATAL)
           {
            LogDebug(StringFormat("PlacePending FATAL: type=%d price=%.2f rc=%d", orderType, tryEntry, out.retcode));
            return 0;
           }
         break;
        }
     }

   LogDebug(StringFormat("PlacePending failed after widening: type=%d price=%.2f lot=%.2f", orderType, entry, lot));
   return 0;
}

//+------------------------------------------------------------------+
//| Convenience wrappers for BUY STOP and SELL STOP                  |
//+------------------------------------------------------------------+
ulong PlaceBuyStop(double price, double lot, int magicNumber, double sl=0, double tp=0)
{
   price = ClampPendingEntry(_Symbol, ORDER_TYPE_BUY_STOP, price);
   return PlacePendingWithWidening(_Symbol, ORDER_TYPE_BUY_STOP, lot, price, sl, tp, magicNumber);
}

ulong PlaceSellStop(double price, double lot, int magicNumber, double sl=0, double tp=0)
{
   price = ClampPendingEntry(_Symbol, ORDER_TYPE_SELL_STOP, price);
   return PlacePendingWithWidening(_Symbol, ORDER_TYPE_SELL_STOP, lot, price, sl, tp, magicNumber);
}

//+------------------------------------------------------------------+
//| Delete a pending order by ticket                                 |
//+------------------------------------------------------------------+
bool DeleteOrder(ulong ticket)
{
   if(!OrderSelect(ticket))
      return true;   // already gone (filled or already deleted) — nothing to do, not a failure

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action = TRADE_ACTION_REMOVE;
   req.order  = ticket;

   ResetLastError();
   bool sent = OrderSend(req, res);

   if(!sent || (res.retcode != TRADE_RETCODE_DONE && res.retcode != TRADE_RETCODE_PLACED))
     {
      LogDebug(StringFormat("DeleteOrder FAILED: ticket=%I64u rc=%d err=%d", ticket, res.retcode, GetLastError()));
      return false;
     }
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
//| Core position close — ticket-based, partial-aware, with retries  |
//| Source: InternalClose() from CandleMultiOrder Rev 8.6            |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
   for(int attempt = 0; attempt < InpSafetyRetryAttempts; attempt++)
     {
      if(!PositionSelectByTicket(ticket))
         return true; // already closed

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

      if(OrderSend(req, res))
        {
         if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_DONE_PARTIAL)
           {
            Sleep(20);
            if(!PositionSelectByTicket(ticket)) return true;
            if(PositionGetDouble(POSITION_VOLUME) <= 0.0) return true;
            if(res.retcode == TRADE_RETCODE_DONE_PARTIAL) { Sleep(60); continue; }
            Sleep(80); continue;
           }
         else if(res.retcode == TRADE_RETCODE_REQUOTE ||
                 res.retcode == TRADE_RETCODE_PRICE_CHANGED ||
                 res.retcode == TRADE_RETCODE_TOO_MANY_REQUESTS)
           { Sleep(60); continue; }
         else
           {
            LogDebug(StringFormat("ClosePosition FAILED: ticket=%I64u rc=%d", ticket, res.retcode));
            return false;
           }
        }
      else
        {
         LogDebug(StringFormat("ClosePosition OrderSend FAILED: ticket=%I64u err=%d attempt=%d",
                               ticket, GetLastError(), attempt+1));
         ResetLastError();
         Sleep(120);
        }
     }

   if(!PositionSelectByTicket(ticket)) return true;
   LogDebug(StringFormat("ClosePosition: exhausted retries ticket=%I64u", ticket));
   return false;
}

//+------------------------------------------------------------------+
//| Fast close — send command and return immediately                 |
//| No verification. Use for non-critical batch closes.              |
//+------------------------------------------------------------------+
bool FastClosePosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return true;

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

   bool sent = OrderSend(req, res);
   if(!sent) ResetLastError();
   return sent;
}

//+------------------------------------------------------------------+
//| Modify SL of open position with widening on rejection            |
//+------------------------------------------------------------------+
bool ModifyPositionSL(ulong ticket, double newSL)
{
   if(!PositionSelectByTicket(ticket)) return false;

   // Validate SL against broker rules
   double safeSL = ValidateStopPrice(ticket, newSL);
   if(safeSL <= 0.0) return false;

   string symbol = PositionGetString(POSITION_SYMBOL);
   double curTP  = PositionGetDouble(POSITION_TP);
   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   // Retry per InpSafetyRetryAttempts / InpSafetyRetryDelayMs (Bug 4/6 safety-net policy)
   for(int attempt = 1; attempt <= InpSafetyRetryAttempts; attempt++)
     {
      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action   = TRADE_ACTION_SLTP;
      req.position = ticket;
      req.symbol   = symbol;
      req.sl       = NormalizeDouble(safeSL, digits);
      req.tp       = curTP;

      ResetLastError();
      bool sent = OrderSend(req, res);

      if(sent && (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_NO_CHANGES))
         return true;

      SendFailAction action = ClassifySendFailure(sent, res, GetLastError());
      if(action == RETRY_SAME && attempt < InpSafetyRetryAttempts) { Sleep(InpSafetyRetryDelayMs); continue; }
      break;
     }

   LogDebug(StringFormat("ModifyPositionSL FAILED: ticket=%I64u sl=%.2f", ticket, safeSL));
   return false;
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
