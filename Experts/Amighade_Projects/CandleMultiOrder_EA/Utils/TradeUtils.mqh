//+------------------------------------------------------------------+
//| TradeUtils.mqh                                                    |
//| Order placement, modification, deletion and close wrappers       |
//| Shared with HedgeGrid EA — same tested logic                    |
//+------------------------------------------------------------------+
#ifndef CMO_TRADE_UTILS_MQH
#define CMO_TRADE_UTILS_MQH

#include "../Inputs.mqh"
#include "../Models/EAState.mqh"
#include "MathUtils.mqh"

//+------------------------------------------------------------------+
//| Classify retcode into retry strategy                             |
//+------------------------------------------------------------------+
SendFailAction ClassifySendFailure(bool sent, const MqlTradeResult &res, int lastErr)
{
   switch(res.retcode)
     {
      case TRADE_RETCODE_DONE:
      case TRADE_RETCODE_PLACED:
      case TRADE_RETCODE_NO_CHANGES:   return SEND_OK;

      case TRADE_RETCODE_REQUOTE:
      case TRADE_RETCODE_PRICE_CHANGED:
      case TRADE_RETCODE_TOO_MANY_REQUESTS:
      case TRADE_RETCODE_CONNECTION:
      case TRADE_RETCODE_TIMEOUT:
      case TRADE_RETCODE_LOCKED:       return RETRY_SAME;

      case TRADE_RETCODE_PRICE_OFF:
      case TRADE_RETCODE_INVALID_PRICE:
      case TRADE_RETCODE_INVALID_STOPS:
      case TRADE_RETCODE_FROZEN:       return RETRY_WIDEN;

      case TRADE_RETCODE_INVALID:
      case TRADE_RETCODE_INVALID_VOLUME:
      case TRADE_RETCODE_NO_MONEY:
      case TRADE_RETCODE_TRADE_DISABLED:
      case TRADE_RETCODE_MARKET_CLOSED: return FAIL_FATAL;

      default:                          return FAIL_OTHER;
     }
}

//+------------------------------------------------------------------+
//| Detect working fill mode at EA start                             |
//+------------------------------------------------------------------+
void DetectWorkingFillMode()
{
   ENUM_ORDER_TYPE_FILLING modes[3] = {ORDER_FILLING_IOC, ORDER_FILLING_RETURN, ORDER_FILLING_FOK};
   string names[3] = {"IOC","RETURN","FOK"};
   MqlTradeCheckResult check;
   MqlTradeRequest req;

   for(int i = 0; i < 3; i++)
     {
      ZeroMemory(req); ZeroMemory(check);
      req.action       = TRADE_ACTION_DEAL;
      req.symbol       = _Symbol;
      req.type         = ORDER_TYPE_BUY;
      req.volume       = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      req.price        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.deviation    = 10;
      req.type_filling = modes[i];

      if(OrderCheck(req, check) && check.retcode == TRADE_RETCODE_DONE)
        {
         gFillMode = modes[i];
         if(EnableDebugLogs)
            PrintFormat("[TradeUtils] Fill mode: %s", names[i]);
         return;
        }
     }
   gFillMode = ORDER_FILLING_IOC;
   if(EnableDebugLogs) Print("[TradeUtils] Fallback fill mode: IOC");
}

//+------------------------------------------------------------------+
//| Widen pending entry price on rejection                           |
//+------------------------------------------------------------------+
double WidenPendingEntry(const string sym, ENUM_ORDER_TYPE type, double entry, int stepCount)
{
   if(stepCount <= 0) return AlignToTick(sym, entry);

   double ask    = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(sym, SYMBOL_BID);
   double spread = ask - bid;
   double tick   = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0) tick = _Point;

   double stops  = MinStopDistancePrice(sym);
   double freeze = (double)SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   double dist   = stops + freeze + 2.0 * tick + stepCount * spread * 0.2;

   if(type == ORDER_TYPE_BUY_STOP)  entry += dist;
   else                             entry -= dist;

   return AlignToTick(sym, entry);
}

//+------------------------------------------------------------------+
//| Place pending order — single attempt                             |
//+------------------------------------------------------------------+
TradeActionResult PlacePendingOrder(const string sym, ENUM_ORDER_TYPE orderType,
                                    double lot, double price, double sl, double tp)
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
   req.magic        = MagicNumber;
   req.deviation    = Slippage;
   req.type_filling = gFillMode;
   req.type_time    = ORDER_TIME_GTC;

   ResetLastError();
   bool sent = OrderSend(req, res);

   TradeActionResult out;
   out.sent      = sent;
   out.success   = sent && (res.retcode == TRADE_RETCODE_DONE ||
                            res.retcode == TRADE_RETCODE_PLACED ||
                            res.retcode == TRADE_RETCODE_NO_CHANGES);
   out.retcode   = res.retcode;
   out.lastError = GetLastError();
   return out;
}

//+------------------------------------------------------------------+
//| Place pending with automatic widening on rejection               |
//+------------------------------------------------------------------+
TradeActionResult PlacePendingOrderWithWidening(const string sym, ENUM_ORDER_TYPE orderType,
                                                double lot, double entry, double sl, double tp)
{
   TradeActionResult out = {};

   for(int step = 0; step <= widenMaxSteps; step++)
     {
      double tryEntry = WidenPendingEntry(sym, orderType, entry, step);

      for(int attempt = 1; attempt <= 3; attempt++)
        {
         out = PlacePendingOrder(sym, orderType, lot, tryEntry, sl, tp);
         if(out.success) return out;

         SendFailAction action = ClassifySendFailure(out.sent, (MqlTradeResult){out.retcode}, out.lastError);
         if(action == RETRY_SAME && attempt < 3) { Sleep(50 * attempt); continue; }
         if(action == RETRY_WIDEN) break;
         if(action == FAIL_FATAL)  return out;
         break;
        }
     }
   return out;
}

//+------------------------------------------------------------------+
//| Modify pending order price with widening                         |
//+------------------------------------------------------------------+
TradeActionResult ModifyPendingOrderPrice(ulong ticket, const string sym,
                                          double price, double sl, double tp)
{
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action = TRADE_ACTION_MODIFY;
   req.order  = ticket;
   req.symbol = sym;
   req.price  = NormalizeDouble(price, _Digits);
   req.sl     = NormalizeDouble(sl, _Digits);
   req.tp     = NormalizeDouble(tp, _Digits);

   ResetLastError();
   bool sent = OrderSend(req, res);

   TradeActionResult out;
   out.sent      = sent;
   out.success   = sent && (res.retcode == TRADE_RETCODE_DONE ||
                            res.retcode == TRADE_RETCODE_NO_CHANGES);
   out.retcode   = res.retcode;
   out.lastError = GetLastError();
   return out;
}

//+------------------------------------------------------------------+
//| Modify pending order with widening                               |
//+------------------------------------------------------------------+
TradeActionResult ModifyPendingOrderWithWidening(ulong ticket, const string sym,
                                                 ENUM_ORDER_TYPE orderType,
                                                 double entry, double sl, double tp,
                                                 int maxRetries = 3)
{
   TradeActionResult out = {};
   if(!OrderSelect(ticket)) { out.success = false; return out; }

   double currentEntry = OrderGetDouble(ORDER_PRICE_OPEN);

   for(int step = 0; step <= widenMaxSteps; step++)
     {
      double tryEntry = WidenPendingEntry(sym, orderType, entry, step);

      // Only modify if new price is closer to market (not widening wrong way)
      if(orderType == ORDER_TYPE_BUY_STOP  && tryEntry >= currentEntry) return out;
      if(orderType == ORDER_TYPE_SELL_STOP && tryEntry <= currentEntry) return out;

      for(int attempt = 1; attempt <= maxRetries; attempt++)
        {
         out = ModifyPendingOrderPrice(ticket, sym, tryEntry, sl, tp);
         if(out.success) return out;

         SendFailAction action = ClassifySendFailure(out.sent, (MqlTradeResult){out.retcode}, out.lastError);
         if(action == RETRY_SAME && attempt < maxRetries) { Sleep(50 * attempt); continue; }
         if(action == RETRY_WIDEN) break;
         return out;
        }
     }
   return out;
}

//+------------------------------------------------------------------+
//| Cancel a pending order                                           |
//+------------------------------------------------------------------+
TradeActionResult CancelPendingOrder(ulong ticket)
{
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action = TRADE_ACTION_REMOVE;
   req.order  = ticket;

   ResetLastError();
   bool sent = OrderSend(req, res);

   TradeActionResult out;
   out.sent      = sent;
   out.success   = sent && (res.retcode == TRADE_RETCODE_DONE ||
                            res.retcode == TRADE_RETCODE_PLACED);
   out.retcode   = res.retcode;
   out.lastError = GetLastError();
   return out;
}

//+------------------------------------------------------------------+
//| Cancel all pending orders for this EA                            |
//+------------------------------------------------------------------+
int CancelAllPending()
{
   int canceled = 0;
   for(int i = OrdersTotal()-1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;

      long type = OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_STOP  && type != ORDER_TYPE_SELL_STOP &&
         type != ORDER_TYPE_BUY_LIMIT && type != ORDER_TYPE_SELL_LIMIT) continue;

      CancelPendingOrder(ticket);
      canceled++;
     }
   return canceled;
}

//+------------------------------------------------------------------+
//| Check if pending order exists for this EA                        |
//+------------------------------------------------------------------+
bool HasPendingOrder(string symbol, ulong magic)
{
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC) != magic) continue;
      long type = OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP ||
         type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT)
         return true;
     }
   return false;
}

//+------------------------------------------------------------------+
//| Select pending order by ticket (validates it is a pending type)  |
//+------------------------------------------------------------------+
bool SelectPendingOrderByTicket(ulong ticket)
{
   if(!OrderSelect(ticket)) return false;
   long t = OrderGetInteger(ORDER_TYPE);
   return (t == ORDER_TYPE_BUY_STOP || t == ORDER_TYPE_SELL_STOP ||
           t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT);
}

//+------------------------------------------------------------------+
//| Close position — ticket-based, partial-aware, with retries       |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
   for(int attempt = 0; attempt < 3; attempt++)
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
      req.type_filling = gFillMode;
      req.type_time    = ORDER_TIME_GTC;

      if(OrderSend(req, res))
        {
         if(res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_DONE_PARTIAL)
           {
            Sleep(20);
            if(!PositionSelectByTicket(ticket)) return true;
            if(res.retcode == TRADE_RETCODE_DONE_PARTIAL) { Sleep(60); continue; }
            Sleep(80); continue;
           }
         else if(res.retcode == TRADE_RETCODE_REQUOTE ||
                 res.retcode == TRADE_RETCODE_PRICE_CHANGED ||
                 res.retcode == TRADE_RETCODE_TOO_MANY_REQUESTS)
           { Sleep(60); continue; }
         return false;
        }
      ResetLastError();
      Sleep(120);
     }
   if(!PositionSelectByTicket(ticket)) return true;
   return false;
}

//+------------------------------------------------------------------+
//| Fast close — send and return immediately                         |
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
   req.type_filling = gFillMode;
   req.type_time    = ORDER_TIME_GTC;

   bool sent = OrderSend(req, res);
   if(!sent) ResetLastError();
   return sent;
}

//+------------------------------------------------------------------+
//| Close all positions by ticket array                              |
//+------------------------------------------------------------------+
int CloseAll(const ulong &tickets[])
{
   int closed = 0;
   for(int i = ArraySize(tickets)-1; i >= 0; --i)
     {
      if(!PositionSelectByTicket(tickets[i])) { closed++; continue; }
      if(ClosePosition(tickets[i])) closed++;
      Sleep(5);
     }
   return closed;
}

//+------------------------------------------------------------------+
//| Fast close all tickets in array                                  |
//+------------------------------------------------------------------+
void FastCloseTickets(const ulong &tickets[], bool verbose = true)
{
   for(int i = 0; i < ArraySize(tickets); i++)
      FastClosePosition(tickets[i]);
}

//+------------------------------------------------------------------+
//| Update SL on position — single attempt                           |
//+------------------------------------------------------------------+
bool UpdateSL(ulong ticket, double newSL)
{
   if(!PositionSelectByTicket(ticket)) return false;

   string symbol  = PositionGetString(POSITION_SYMBOL);
   double curTP   = PositionGetDouble(POSITION_TP);
   double oldSL   = PositionGetDouble(POSITION_SL);
   int    digits  = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   double safeSL  = ValidateStopPrice(ticket, newSL);
   double safeNorm= NormalizeDouble(safeSL, digits);
   double oldNorm = NormalizeDouble(oldSL, digits);

   if(safeSL <= 0.0)   return false;
   if(safeNorm == oldNorm && oldNorm > 0.0) return true;

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action   = TRADE_ACTION_SLTP;
   req.position = ticket;
   req.symbol   = symbol;
   req.sl       = safeNorm;
   req.tp       = curTP;

   ResetLastError();
   bool sent = OrderSend(req, res);

   if(!sent) return false;
   if(res.retcode == TRADE_RETCODE_NO_CHANGES) return true;
   return (res.retcode == TRADE_RETCODE_DONE);
}

//+------------------------------------------------------------------+
//| Update SL with widening fallback                                 |
//+------------------------------------------------------------------+
bool UpdateSLWithWidening(ulong ticket, double requestedSL)
{
   if(!PositionSelectByTicket(ticket)) return false;

   string symbol = PositionGetString(POSITION_SYMBOL);
   int    posType= (int)PositionGetInteger(POSITION_TYPE);
   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   // Try with validated SL first
   if(UpdateSL(ticket, requestedSL)) return true;

   // Widen and retry
   for(int step = 1; step <= widenMaxSteps; step++)
     {
      double tick   = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tick <= 0) tick = _Point;
      double ask    = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid    = SymbolInfoDouble(symbol, SYMBOL_BID);
      double spread = ask - bid;
      double stops  = MinStopDistancePrice(symbol);
      double freeze = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
      double dist   = stops + freeze + 2.0 * tick + step * spread * 0.2;

      double widenedSL = requestedSL;
      if(posType == POSITION_TYPE_BUY)  widenedSL -= dist;
      else                              widenedSL += dist;
      widenedSL = NormalizeDouble(widenedSL, digits);

      if(UpdateSL(ticket, widenedSL)) return true;
      if(step >= 3) Sleep(25);
     }
   return false;
}

//+------------------------------------------------------------------+
//| Align volume to broker step and min/max                          |
//+------------------------------------------------------------------+
double AlignVolume(const string sym, double vol)
{
   double minv = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double maxv = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

   if(LotMin > 0) minv = MathMax(minv, LotMin);
   if(LotMax > 0) maxv = MathMin(maxv, LotMax);

   if(step > 0.0) vol = MathCeil(vol / step) * step;
   if(vol < minv) vol = minv;
   if(vol > maxv) vol = maxv;
   return vol;
}

//+------------------------------------------------------------------+
//| Human-readable retcode                                           |
//+------------------------------------------------------------------+
string RetcodeToString(int code)
{
   switch(code)
     {
      case TRADE_RETCODE_REQUOTE:           return "Requote";
      case TRADE_RETCODE_REJECT:            return "Rejected";
      case TRADE_RETCODE_PLACED:            return "Placed";
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
      default: return StringFormat("Unknown(%d)", code);
     }
}

#endif
