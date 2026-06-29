//+------------------------------------------------------------------+
//| MathUtils.mqh                                                     |
//| Mathematical helpers: breakeven, lot rounding, gap calculations  |
//+------------------------------------------------------------------+
#ifndef MATH_UTILS_MQH
#define MATH_UTILS_MQH

#include "../Inputs.mqh"

//+------------------------------------------------------------------+
//| Round lot size to broker's minimum lot step                      |
//+------------------------------------------------------------------+
double RoundLot(double lot)
  {
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0) lotStep = 0.01;
   return NormalizeDouble(MathFloor(lot / lotStep) * lotStep, 2);
  }

//+------------------------------------------------------------------+
//| Round price to symbol digits                                     |
//+------------------------------------------------------------------+
double RoundPrice(double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

//+------------------------------------------------------------------+
//| Calculate breakeven price for positions in one direction         |
//| direction: POSITION_TYPE_BUY or POSITION_TYPE_SELL              |
//+------------------------------------------------------------------+
double CalculateBreakeven(ENUM_POSITION_TYPE direction)
  {
   double totalCost  = 0.0;
   double totalLots  = 0.0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != direction) continue;

      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double lot        = PositionGetDouble(POSITION_VOLUME);

      totalCost += entryPrice * lot;
      totalLots += lot;
     }

   if(totalLots <= 0) return 0.0;
   return RoundPrice(totalCost / totalLots);
  }

//+------------------------------------------------------------------+
//| Calculate total basket profit for all EA positions               |
//+------------------------------------------------------------------+
double CalculateBasketProfit()
  {
   double total = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;
      total += PositionGetDouble(POSITION_PROFIT);
     }
   return total;
  }

//+------------------------------------------------------------------+
//| Calculate basket profit for one direction only                   |
//+------------------------------------------------------------------+
double CalculateDirectionProfit(ENUM_POSITION_TYPE direction)
  {
   double total = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != direction) continue;
      total += PositionGetDouble(POSITION_PROFIT);
     }
   return total;
  }

//+------------------------------------------------------------------+
//| Get last opened position entry price for a given direction       |
//+------------------------------------------------------------------+
double GetLastEntryPrice(ENUM_POSITION_TYPE direction)
  {
   double   lastPrice = 0.0;
   datetime lastTime  = 0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;
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
//| Calculate SL level for winning direction                         |
//| SL = MAX(breakeven, last entry price)                            |
//| Constraint: SL must be beyond position relative to price         |
//+------------------------------------------------------------------+
double CalculateSLLevel(ENUM_POSITION_TYPE winningDirection)
  {
   double breakeven      = CalculateBreakeven(winningDirection);
   double lastEntryPrice = GetLastEntryPrice(winningDirection);
   double currentPrice   = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double slLevel = 0.0;

   if(winningDirection == POSITION_TYPE_BUY)
     {
      // For BUY positions: SL is below price
      // Take the higher of breakeven and last entry (closer to current price = more protection)
      slLevel = MathMax(breakeven, lastEntryPrice);
      // Constraint: SL must be below current price
      if(slLevel >= currentPrice)
         slLevel = currentPrice - InpGridSpacing;
     }
   else
     {
      // For SELL positions: SL is above price
      // Take the lower of breakeven and last entry
      slLevel = MathMin(breakeven, lastEntryPrice);
      // Constraint: SL must be above current price
      if(slLevel <= currentPrice)
         slLevel = currentPrice + InpGridSpacing;
     }

   return RoundPrice(slLevel);
  }

//+------------------------------------------------------------------+
//| Auto-generate magic number from symbol and timeframe             |
//+------------------------------------------------------------------+
int GenerateMagicNumber()
  {
   string combined = _Symbol + IntegerToString(_Period);
   int    hash     = 0;
   for(int i = 0; i < StringLen(combined); i++)
      hash = (hash * 31 + StringGetCharacter(combined, i)) & 0x7FFFFFFF;
   // Keep in valid range (avoid 0)
   return (hash == 0) ? 1 : hash;
  }

//+------------------------------------------------------------------+
//| Check if current candle is bullish                                |
//+------------------------------------------------------------------+
bool IsBullishCandle()
  {
   double open  = iOpen(_Symbol, PERIOD_CURRENT, 0);
   double close = iClose(_Symbol, PERIOD_CURRENT, 0);
   return (close >= open);
  }


#endif