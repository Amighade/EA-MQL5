//+------------------------------------------------------------------+
//| MathUtils.mqh                                                     |
//| Mathematical helpers: price alignment, lot validation,           |
//| stop distance, breakeven, SL level calculation                   |
//| Source: tested functions from CandleMultiOrder EA Rev 8.6        |
//+------------------------------------------------------------------+
#ifndef MATH_UTILS_MQH
#define MATH_UTILS_MQH

#include "../Inputs.mqh"

//+------------------------------------------------------------------+
//| Snap price to nearest broker tick size                           |
//+------------------------------------------------------------------+
double AlignToTick(const string sym, double price)
{
   double tick = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0) tick = _Point;
   price = MathRound(price / tick) * tick;
   return NormalizeDouble(price, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
//| Round lot to broker volume step, clamp to min/max               |
//+------------------------------------------------------------------+
double AlignVolume(const string sym, double vol)
{
   double minv  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double maxv  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double step  = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

   if(step > 0.0)
      vol = MathCeil(vol / step) * step;

   if(vol < minv) vol = minv;
   if(vol > maxv) vol = maxv;

   return vol;
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
//| Minimum pending order distance in price units                    |
//| Accounts for stop level + freeze level + 1 tick safety pad       |
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
//| Clamp pending entry to broker minimum distance from market       |
//+------------------------------------------------------------------+
double ClampPendingEntry(const string sym, long orderType, double desired)
{
   const double ask     = SymbolInfoDouble(sym, SYMBOL_ASK);
   const double bid     = SymbolInfoDouble(sym, SYMBOL_BID);
   const double minDist = MinPendingDistancePrice(sym);

   double p = desired;

   if(orderType == ORDER_TYPE_BUY_STOP)
      p = MathMax(p, ask + minDist);
   else if(orderType == ORDER_TYPE_SELL_STOP)
      p = MathMin(p, bid - minDist);

   return AlignToTick(sym, p);
}

//+------------------------------------------------------------------+
//| Validate and adjust SL price to respect broker rules             |
//| - BUY SL must be below bid - minStop                             |
//| - SELL SL must be above ask + minStop                            |
//| - SL never moves against existing protection                     |
//+------------------------------------------------------------------+
double ValidateStopPrice(const ulong ticket, double candidateSL)
{
   if(!PositionSelectByTicket(ticket))
      return candidateSL;

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
      // Never move SL worse than existing
      if(oldSL > 0.0 && newSL <= oldSL) newSL = oldSL;
     }
   else if(posType == POSITION_TYPE_SELL)
     {
      double minAllowed = ask + minStop;
      if(newSL <= minAllowed) newSL = minAllowed;
      if(oldSL > 0.0 && newSL >= oldSL) newSL = oldSL;
     }
   else
      return candidateSL;

   if(newSL <= 0.0) return 0.0;

   return AlignToTick(sym, NormalizeDouble(newSL, digits));
}

//+------------------------------------------------------------------+
//| Get entry price of the most recently opened position             |
//+------------------------------------------------------------------+
double GetLastEntryPrice(ENUM_POSITION_TYPE direction, int magicNumber)
{
   double   lastPrice = 0.0;
   datetime lastTime  = 0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != direction) continue;

      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      if(openTime > lastTime)
        {
         lastTime  = openTime;
         lastPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        }
     }
   return lastPrice;
}

//+------------------------------------------------------------------+
//| Calculate total basket profit for all EA positions               |
//+------------------------------------------------------------------+
double CalculateBasketProfit(int magicNumber)
{
   double total = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      total += PositionGetDouble(POSITION_PROFIT);
     }
   return total;
}

//+------------------------------------------------------------------+
//| Calculate basket profit for one direction only                   |
//+------------------------------------------------------------------+
double CalculateDirectionProfit(ENUM_POSITION_TYPE direction, int magicNumber)
{
   double total = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != direction) continue;
      total += PositionGetDouble(POSITION_PROFIT);
     }
   return total;
}

//+------------------------------------------------------------------+
//| Auto-generate magic number from symbol + timeframe               |
//| Matches logic from CandleMultiOrder BuildMagicNumber()           |
//+------------------------------------------------------------------+
int GetSymbolCode(const string sym)
{
   string s = sym;
   StringToUpper(s);
   // Strip trailing + if present
   if(StringLen(s) > 0 && StringGetCharacter(s, StringLen(s)-1) == '+')
      s = StringSubstr(s, 0, StringLen(s)-1);

   int code = 0;
   for(int i = 0; i < StringLen(s); i++)
      code += StringGetCharacter(s, i);

   return 100 + (code % 900);
}

int GenerateMagicNumber()
{
   return GetSymbolCode(_Symbol) * 100000 + (int)_Period;
}

//+------------------------------------------------------------------+
//| Check if current candle is bullish                               |
//+------------------------------------------------------------------+
bool IsBullishCandle()
{
   double open  = iOpen(_Symbol, PERIOD_CURRENT, 0);
   double close = iClose(_Symbol, PERIOD_CURRENT, 0);
   return (close >= open);
}

//+------------------------------------------------------------------+
//| Price comparison with tick tolerance                             |
//+------------------------------------------------------------------+
bool NearlyEqualPrice(double a, double b)
{
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0) tick = _Point;
   return (MathAbs(a - b) <= tick);
}

//+------------------------------------------------------------------+
//| Volume comparison with step tolerance                            |
//+------------------------------------------------------------------+
bool NearlyEqualVol(double a, double b)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   return (MathAbs(a - b) <= 0.5 * step);
}

#endif
