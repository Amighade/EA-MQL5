//+------------------------------------------------------------------+
//| CandleUtils.mqh                                                   |
//| Candle data update, color detection, trend helpers               |
//+------------------------------------------------------------------+
#ifndef CMO_CANDLE_UTILS_MQH
#define CMO_CANDLE_UTILS_MQH

#include "../Inputs.mqh"
#include "../Models/EAState.mqh"

//+------------------------------------------------------------------+
//| Update candle data buffers (HA or regular)                       |
//| Call once per tick — returns false if data not ready             |
//+------------------------------------------------------------------+
bool UpdateCandleData()
{
   int barsToCopy = InpEntryModeN + 1;

   if(InpCandleSourceMode == CANDLE_SOURCE_HA)
     {
      int c0 = CopyBuffer(gCandleHandle, 0, 0, barsToCopy, gOpenBuf);
      int c1 = CopyBuffer(gCandleHandle, 1, 0, barsToCopy, gHighBuf);
      int c2 = CopyBuffer(gCandleHandle, 2, 0, barsToCopy, gLowBuf);
      int c3 = CopyBuffer(gCandleHandle, 3, 0, barsToCopy, gCloseBuf);

      if(c0 != barsToCopy || c1 != barsToCopy || c2 != barsToCopy || c3 != barsToCopy)
        {
         if(EnableDebugLogs)
            PrintFormat("[CandleUtils] HA buffer copy failed: need=%d got=%d/%d/%d/%d err=%d",
                        barsToCopy, c0, c1, c2, c3, GetLastError());
         return false;
        }
     }
   else
     {
      int c0 = CopyOpen(_Symbol,  PERIOD_CURRENT, 0, barsToCopy, gOpenBuf);
      int c1 = CopyHigh(_Symbol,  PERIOD_CURRENT, 0, barsToCopy, gHighBuf);
      int c2 = CopyLow(_Symbol,   PERIOD_CURRENT, 0, barsToCopy, gLowBuf);
      int c3 = CopyClose(_Symbol, PERIOD_CURRENT, 0, barsToCopy, gCloseBuf);

      if(c0 != barsToCopy || c1 != barsToCopy || c2 != barsToCopy || c3 != barsToCopy)
        {
         if(EnableDebugLogs)
            PrintFormat("[CandleUtils] RC buffer copy failed: need=%d got=%d/%d/%d/%d err=%d",
                        barsToCopy, c0, c1, c2, c3, GetLastError());
         return false;
        }
     }

   ArraySetAsSeries(gOpenBuf,  true);
   ArraySetAsSeries(gHighBuf,  true);
   ArraySetAsSeries(gLowBuf,   true);
   ArraySetAsSeries(gCloseBuf, true);
   return true;
}

//+------------------------------------------------------------------+
//| Get candle color for a given bar index                           |
//| Returns +1 (bullish), -1 (bearish), 0 (doji)                   |
//+------------------------------------------------------------------+
int GetCandleColor(int index)
{
   if(index < 0 || index >= ArraySize(gOpenBuf) || index >= ArraySize(gCloseBuf))
      return 0;
   if(gCloseBuf[index] > gOpenBuf[index]) return  1;
   if(gCloseBuf[index] < gOpenBuf[index]) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Detect HA reversal direction from last 3 bars                   |
//| Returns +1 bullish reversal, -1 bearish reversal, 0 none        |
//+------------------------------------------------------------------+
int GetHAReversalDirection()
{
   int twoPrevColor = GetCandleColor(2);
   int prevColor    = GetCandleColor(1);
   int currColor    = GetCandleColor(0);

   if((currColor != prevColor    && currColor != 0 && prevColor    != 0) ||
      (currColor != twoPrevColor && currColor != 0 && twoPrevColor != 0))
      return currColor;
   return 0;
}

//+------------------------------------------------------------------+
//| True if price is above last candle high (uptrend)               |
//+------------------------------------------------------------------+
bool IsUpTrend()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (gHighBuf[1] < bid);
}

//+------------------------------------------------------------------+
//| True if price is below last candle low (downtrend)              |
//+------------------------------------------------------------------+
bool IsDownTrend()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (gLowBuf[1] > ask);
}

//+------------------------------------------------------------------+
//| True if current bar has not changed since last call              |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBarTime = 0;
   ENUM_TIMEFRAMES tf = (Timeframe == 0 ? (ENUM_TIMEFRAMES)Period() : Timeframe);
   datetime currentBarTime = iTime(_Symbol, tf, 0);
   if(currentBarTime != lastBarTime)
     {
      lastBarTime = currentBarTime;
      return true;
     }
   return false;
}

#endif
