//+------------------------------------------------------------------+
//| MathUtils.mqh                                                     |
//| Price alignment, stop distance, SL validation helpers           |
//| Shared logic with HedgeGrid EA                                  |
//+------------------------------------------------------------------+
#ifndef CMO_MATH_UTILS_MQH
#define CMO_MATH_UTILS_MQH

#include "../Inputs.mqh"

//+------------------------------------------------------------------+
//| Snap price to nearest broker tick                                |
//+------------------------------------------------------------------+
double AlignToTick(const string sym, double price)
{
   double tick = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0) tick = _Point;
   price = MathRound(price / tick) * tick;
   return NormalizeDouble(price, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
//| Minimum stop distance in price units                             |
//+------------------------------------------------------------------+
double MinStopDistancePrice(const string sym)
{
   double pts = (double)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   if(pts < 0) pts = 0;
   return pts * SymbolInfoDouble(sym, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Minimum pending order distance (stop + freeze + 1 tick pad)     |
//+------------------------------------------------------------------+
double MinPendingDistancePrice(const string sym)
{
   double pt     = SymbolInfoDouble(sym, SYMBOL_POINT);
   double stops  = (double)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   double freeze = (double)SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL);
   if(stops  < 0) stops  = 0;
   if(freeze < 0) freeze = 0;
   double tick = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0) tick = pt;
   return (stops + freeze) * pt + tick;
}

//+------------------------------------------------------------------+
//| Clamp pending entry to broker minimum distance                   |
//+------------------------------------------------------------------+
double ClampPendingEntry(const string sym, long orderType, double desired)
{
   double ask     = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid     = SymbolInfoDouble(sym, SYMBOL_BID);
   double minDist = MinPendingDistancePrice(sym);
   double p       = desired;

   if(orderType == ORDER_TYPE_BUY_STOP)
      p = MathMax(p, ask + minDist);
   else if(orderType == ORDER_TYPE_SELL_STOP)
      p = MathMin(p, bid - minDist);

   return AlignToTick(sym, p);
}

//+------------------------------------------------------------------+
//| Validate SL against broker rules — never move SL against itself  |
//+------------------------------------------------------------------+
double ValidateStopPrice(const ulong ticket, double candidateSL)
{
   if(!PositionSelectByTicket(ticket)) return candidateSL;

   string sym     = PositionGetString(POSITION_SYMBOL);
   int    posType = (int)PositionGetInteger(POSITION_TYPE);
   double bid     = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask     = SymbolInfoDouble(sym, SYMBOL_ASK);
   double minStop = MinStopDistancePrice(sym);
   double oldSL   = PositionGetDouble(POSITION_SL);
   int    digits  = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

   double newSL = candidateSL;

   if(posType == POSITION_TYPE_BUY)
     {
      double maxAllowed = bid - minStop;
      if(newSL >= maxAllowed) newSL = maxAllowed;
      if(oldSL > 0.0 && newSL <= oldSL) newSL = oldSL;
     }
   else if(posType == POSITION_TYPE_SELL)
     {
      double minAllowed = ask + minStop;
      if(newSL <= minAllowed) newSL = minAllowed;
      if(oldSL > 0.0 && newSL >= oldSL) newSL = oldSL;
     }
   else return candidateSL;

   if(newSL <= 0.0) return 0.0;
   return AlignToTick(sym, NormalizeDouble(newSL, digits));
}

//+------------------------------------------------------------------+
//| Price comparison within tick tolerance                           |
//+------------------------------------------------------------------+
bool NearlyEqualPrice(double a, double b, double spread)
{
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0) tick = _Point;
   return (MathAbs(a - b) <= tick);
}

//+------------------------------------------------------------------+
//| Volume comparison within step tolerance                          |
//+------------------------------------------------------------------+
bool NearlyEqualVol(double a, double b)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   return (MathAbs(a - b) <= 0.5 * step);
}

//+------------------------------------------------------------------+
//| Magic number from symbol + timeframe                             |
//+------------------------------------------------------------------+
int GetSymbolCode(const string sym)
{
   string s = sym;
   StringToUpper(s);
   if(StringLen(s) > 0 && StringGetCharacter(s, StringLen(s)-1) == '+')
      s = StringSubstr(s, 0, StringLen(s)-1);
   int code = 0;
   for(int i = 0; i < StringLen(s); i++)
      code += StringGetCharacter(s, i);
   return 100 + (code % 900);
}

int BuildMagicNumber(const string sym, ENUM_TIMEFRAMES tf)
{
   return GetSymbolCode(sym) * 100000 + (int)tf;
}

//+------------------------------------------------------------------+
//| Commission per lot for known symbols                             |
//+------------------------------------------------------------------+
double GetSymbolCommissionPerLot(const string sym)
{
   if(StringFind(sym, "XAUUSD") >= 0) return 6.0;
   if(StringFind(sym, "AUDUSD") >= 0) return 6.0;
   return 0.0;
}

#endif
