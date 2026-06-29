//+------------------------------------------------------------------+
//| EntryEngine.mqh                                                   |
//| Entry level computation: Floating, RangeAnchor, Asymmetric      |
//+------------------------------------------------------------------+
#ifndef CMO_ENTRY_ENGINE_MQH
#define CMO_ENTRY_ENGINE_MQH

#include "../Inputs.mqh"
#include "../Models/EAState.mqh"
#include "../Models/RangeState.mqh"
#include "../Utils/MathUtils.mqh"
#include "../Utils/CandleUtils.mqh"

//+------------------------------------------------------------------+
//| Compute candle range based on InpEntryMode                       |
//+------------------------------------------------------------------+
void ComputeEntryCandleRange(double &candleHigh, double &candleLow, long orderType)
{
   switch(InpEntryMode)
     {
      case PREV_N_CANDLE_HIGH_LOW_MAX_MIN:
        {
         int bars=MathMax(1,InpEntryModeN);
         double maxH=gHighBuf[1], minL=gLowBuf[1];
         for(int i=2;i<=bars;i++){ if(gHighBuf[i]>maxH)maxH=gHighBuf[i]; if(gLowBuf[i]<minL)minL=gLowBuf[i]; }
         candleHigh=maxH; candleLow=minL;
         break;
        }
      case PREV_N_CANDLE_BODY_MAX_MIN:
        {
         int bars=MathMax(1,InpEntryModeN);
         double maxB=MathMax(gOpenBuf[1],gCloseBuf[1]), minB=MathMin(gOpenBuf[1],gCloseBuf[1]);
         for(int i=2;i<=bars;i++){ double bT=MathMax(gOpenBuf[i],gCloseBuf[i]),bBt=MathMin(gOpenBuf[i],gCloseBuf[i]); if(bT>maxB)maxB=bT; if(bBt<minB)minB=bBt; }
         candleHigh=maxB; candleLow=minB;
         break;
        }
      case PREV_N_CANDLE_HIGH_LOW_AVRG:
        {
         int bars=MathMax(1,InpEntryModeN);
         double sH=0,sL=0;
         for(int i=1;i<=bars;i++){sH+=gHighBuf[i];sL+=gLowBuf[i];}
         candleHigh=sH/bars; candleLow=sL/bars;
         break;
        }
      case PREV_N_CANDLE_BODY_AVRG:
        {
         int bars=MathMax(1,InpEntryModeN);
         double sT=0,sB=0;
         for(int i=1;i<=bars;i++){sT+=MathMax(gOpenBuf[i],gCloseBuf[i]);sB+=MathMin(gOpenBuf[i],gCloseBuf[i]);}
         candleHigh=sT/bars; candleLow=sB/bars;
         break;
        }
      case PREV_N_CANDLE_HIGH_LOW_BODY_AVRG_MAX_MIN:
        {
         int bars=MathMax(1,InpEntryModeN);
         double maxH=(gHighBuf[1]+MathMax(gOpenBuf[1],gCloseBuf[1]))*0.5;
         double minL=(gLowBuf[1] +MathMin(gOpenBuf[1],gCloseBuf[1]))*0.5;
         for(int i=2;i<=bars;i++)
           {
            double dH=(gHighBuf[i]+MathMax(gOpenBuf[i],gCloseBuf[i]))*0.5;
            double dL=(gLowBuf[i] +MathMin(gOpenBuf[i],gCloseBuf[i]))*0.5;
            if(dH>maxH)maxH=dH; if(dL<minL)minL=dL;
           }
         candleHigh=maxH; candleLow=minL;
         break;
        }
      case PREV_N_CANDLE_HIGH_LOW_MID_P_RANGE:
        {
         int bars=MathMax(1,InpEntryModeN);
         double maxH=gHighBuf[1],minL=gLowBuf[1];
         for(int i=2;i<=bars;i++){if(gHighBuf[i]>maxH)maxH=gHighBuf[i];if(gLowBuf[i]<minL)minL=gLowBuf[i];}
         double mid=(maxH+minL)*0.5;
         candleHigh=mid+AsymmetricRangeDistanceInPrice/2.0;
         candleLow =mid-AsymmetricRangeDistanceInPrice/2.0;
         break;
        }
     }
}

//+------------------------------------------------------------------+
//| Apply entry range filters (filter 1 and/or 2)                   |
//+------------------------------------------------------------------+
void ApplyEntryRangeFilters(double &candleHigh, double &candleLow, long orderType)
{
   double distance = AsymmetricRangeDistanceInPrice;

   if(UseEntryRangeFilter_1)
     {
      double range   = candleHigh - candleLow;
      double minRange= distance * EntryMinRangeFactor;
      double maxRange= distance * EntryMaxRangeFactor;
      double mid     = (candleHigh+candleLow)*0.5;

      if(range < minRange || range > maxRange)
        {
         candleHigh = mid + distance/2.0;
         candleLow  = mid - distance/2.0;
        }
     }

   if(UseEntryRangeFilter_2)
     {
      double range   = candleHigh - candleLow;
      double minRange= distance * EntryMinRangeFactor;
      double maxRange= distance * EntryMaxRangeFactor;

      if(range < minRange)
        {
         if(orderType==ORDER_TYPE_BUY_STOP)        candleLow  = candleLow  - distance;
         else if(orderType==ORDER_TYPE_SELL_STOP)  candleHigh = candleHigh + distance;
         else { double mid=(candleHigh+candleLow)*0.5; candleHigh=mid+distance/2.0; candleLow=mid-distance/2.0; }
        }
      else if(range > maxRange)
        {
         if(orderType==ORDER_TYPE_BUY_STOP)        candleLow  = candleHigh - distance;
         else if(orderType==ORDER_TYPE_SELL_STOP)  candleHigh = candleLow  + distance;
        }
     }
}

//+------------------------------------------------------------------+
//| Validate minimum distance between entries                        |
//+------------------------------------------------------------------+
void ValidateEntryDistance(double &candleHigh, double &candleLow, long orderType)
{
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;
   double dist   = candleHigh - candleLow;
   double minStop= MinStopDistancePrice(_Symbol);
   double freeze = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   double minReq = minStop + freeze + spread;

   if(dist >= minReq) return;

   ENUM_TIMEFRAMES tf = (Timeframe==0 ? (ENUM_TIMEFRAMES)Period() : Timeframe);
   double volBuffer = 0.0;
   int atrHandle = iATR(_Symbol, tf, ATR_Period);
   if(atrHandle != INVALID_HANDLE)
     {
      double atrBuf[];
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf)==1 && atrBuf[0]>0.0)
         volBuffer = atrBuf[0] * 0.5;
      IndicatorRelease(atrHandle);
     }
   double baseMin = spread*1.5 + minStop + freeze;
   double newDist = MathMax(dist, baseMin + volBuffer);
   double mid     = (candleHigh + candleLow) * 0.5;
   candleHigh     = mid + newDist/2.0;
   candleLow      = mid - newDist/2.0;
}

//+------------------------------------------------------------------+
//| MODE_RANGE_ANCHOR entry computation                              |
//+------------------------------------------------------------------+
void ComputeEntryAnchors(double &buyEntry, double &sellEntry,
                         PosLists &poslists, long orderType)
{
   int n = ArraySize(poslists.lstWNSL);
   SortByOpenTimeAscending(poslists.lstWNSL);

   if(gABWCLArmed && gArmedSL!=0.0 && n==0)
     { buyEntry=gArmedSL; sellEntry=gArmedSL; return; }

   double candleHigh = gHighBuf[1], candleLow = gLowBuf[1];
   ComputeEntryCandleRange(candleHigh, candleLow, orderType);
   ApplyEntryRangeFilters(candleHigh, candleLow, orderType);
   ValidateEntryDistance(candleHigh, candleLow, orderType);

   // Use saved range if available
   if(n>0 && gbuyEntry_range!=0 && gsellEntry_range!=0)
     { buyEntry=gbuyEntry_range; sellEntry=gsellEntry_range; return; }

   if(n==0)
     {
      buyEntry=candleHigh; sellEntry=candleLow;
      grange=candleHigh-candleLow;
      return;
     }

   // Anchor to first position
   int    firstSide  = poslists.lstWNSL[0].type;
   double firstPrice = poslists.lstWNSL[0].openPrice;
   if(firstSide==POSITION_TYPE_SELL) { sellEntry=firstPrice; buyEntry=sellEntry+grange; }
   else                              { buyEntry=firstPrice;  sellEntry=buyEntry-grange;  }

   gbuyEntry_range=buyEntry; gsellEntry_range=sellEntry;
   SaveRangeState();
}

//+------------------------------------------------------------------+
//| MODE_ASYMMETRIC_ANCHOR entry computation                         |
//+------------------------------------------------------------------+
void ComputeEntryAsymmetric(double &buyEntry, double &sellEntry,
                            PosLists &poslists, long orderType)
{
   int n = ArraySize(poslists.lstWNSL);
   SortByOpenTimeAscending(poslists.lstWNSL);

   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;
   double dist   = AsymmetricRangeDistanceInPrice;
   double minStop= MinStopDistancePrice(_Symbol);
   double freeze = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL)*_Point;
   double minReq = minStop+freeze+spread;

   if(dist < minReq)
     {
      ENUM_TIMEFRAMES tf = (Timeframe==0?(ENUM_TIMEFRAMES)Period():Timeframe);
      double vb=0.0; int ah=iATR(_Symbol,tf,ATR_Period);
      if(ah!=INVALID_HANDLE){ double ab[]; if(CopyBuffer(ah,0,0,1,ab)==1&&ab[0]>0.0)vb=ab[0]*0.5; IndicatorRelease(ah); }
      dist=MathMax(dist,spread*1.5+minStop+freeze+vb);
     }

   if(gbuyEntry_range!=0 && gsellEntry_range!=0)
     {
      double currentDist = gbuyEntry_range - gsellEntry_range;
      if(currentDist > dist)
        {
         buyEntry=gbuyEntry_range; sellEntry=buyEntry-dist;
         gbuyEntry_range=buyEntry; gsellEntry_range=sellEntry;
        }
      else { buyEntry=gbuyEntry_range; sellEntry=gsellEntry_range; }
      return;
     }

   double candleHigh=gHighBuf[1], candleLow=gLowBuf[1];
   if(n==0) { buyEntry=candleHigh; sellEntry=candleLow; return; }

   int    lastSide  = poslists.lstWNSL[n-1].type;
   double lastPrice = poslists.lstWNSL[n-1].openPrice;
   if(lastSide==POSITION_TYPE_BUY) { buyEntry=lastPrice; sellEntry=buyEntry-dist; }
   else                            { sellEntry=lastPrice; buyEntry=sellEntry+dist; }

   gbuyEntry_range=buyEntry; gsellEntry_range=sellEntry;
   SaveRangeState();
}

//+------------------------------------------------------------------+
//| MODE_FLOATING_BREAKOUT entry computation                         |
//+------------------------------------------------------------------+
void ComputeEntryFloating(double &buyEntry, double &sellEntry,
                          PosLists &poslists, long orderType)
{
   int n = ArraySize(poslists.lstWNSL);
   if(gABWCLArmed && gArmedSL!=0.0 && n==0)
     { buyEntry=gArmedSL; sellEntry=gArmedSL; return; }

   double candleHigh=gHighBuf[1], candleLow=gLowBuf[1];
   ComputeEntryCandleRange(candleHigh, candleLow, orderType);
   ApplyEntryRangeFilters(candleHigh, candleLow, orderType);

   buyEntry=candleHigh; gbuyEntry_range=candleHigh;
   sellEntry=candleLow; gsellEntry_range=candleLow;
}

//+------------------------------------------------------------------+
//| Master entry dispatcher — clamps and aligns after calculation    |
//+------------------------------------------------------------------+
void ComputeEntry(double &buyEntry, double &sellEntry,
                  PosLists &poslists, long orderType)
{
   if(BreakoutMode==MODE_FLOATING_BREAKOUT)
      ComputeEntryFloating(buyEntry, sellEntry, poslists, orderType);
   else if(BreakoutMode==MODE_RANGE_ANCHOR)
      ComputeEntryAnchors(buyEntry, sellEntry, poslists, orderType);
   else if(BreakoutMode==MODE_ASYMMETRIC_ANCHOR)
      ComputeEntryAsymmetric(buyEntry, sellEntry, poslists, orderType);

   buyEntry  = AlignToTick(_Symbol, ClampPendingEntry(_Symbol, ORDER_TYPE_BUY_STOP,  buyEntry));
   sellEntry = AlignToTick(_Symbol, ClampPendingEntry(_Symbol, ORDER_TYPE_SELL_STOP, sellEntry));
}

#endif
