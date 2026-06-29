//+------------------------------------------------------------------+
//| LotEngine.mqh                                                     |
//| Lot size calculation: breakeven-based incremental sizing         |
//+------------------------------------------------------------------+
#ifndef CMO_LOT_ENGINE_MQH
#define CMO_LOT_ENGINE_MQH

#include "../Inputs.mqh"
#include "../Models/EAState.mqh"
#include "../Utils/TradeUtils.mqh"
#include "../Utils/MathUtils.mqh"

//+------------------------------------------------------------------+
//| Parse buffer map from input string "v1,v2,v3..."                 |
//+------------------------------------------------------------------+
int ParseBufferMap(string bufferString)
{
   string parts[];
   int count = StringSplit(bufferString, ',', parts);
   if(count <= 0) return 0;

   ArrayResize(bufferMap, count);
   double minVal = DBL_MAX;
   gLastSmallestBufferIndex = -1;

   for(int i = 0; i < count; i++)
     {
      string s = parts[i];
      StringTrimLeft(s); StringTrimRight(s);
      if(s == "") { Print("[LotEngine] Empty buffer value at index ", i); return 0; }

      double val = StringToDouble(s);
      if(val < 0) { Print("[LotEngine] Negative buffer at index ", i); return 0; }

      bufferMap[i] = val;
      if(val < minVal) { minVal = val; gLastSmallestBufferIndex = i; }
      else if(val == minVal) gLastSmallestBufferIndex = i;
     }
   return count;
}

//+------------------------------------------------------------------+
//| Get buffer B by position count and lot progression              |
//+------------------------------------------------------------------+
double GetBuffer_REV_7_2(int n, PosLists &poslists)
{
   int size = ArraySize(bufferMap);
   if(size == 0) return 0.0;

   bool useProgressiveMap = false;

   if(BufferLotDivisor > 0.0)
     {
      double triggerLot = gMaxLot / BufferLotDivisor;
      gdebugD01 = triggerLot;
      if(ArraySize(poslists.lstAllDeals) > 0)
        {
         gdebugD02 = poslists.lstAllDeals[0].lots;
         gdebugD03 = poslists.lstAllDeals[n>0?n-1:0].lots;
        }
      if(ArraySize(poslists.lstAll) > 0 && poslists.lstAll[n-1].lots >= triggerLot)
         useProgressiveMap = true;
     }

   if(BufferLotQty > 0 && n > BufferLotQty)
      useProgressiveMap = true;

   gdebugB01 = useProgressiveMap;
   int idx = useProgressiveMap ? n : 0;
   return (idx < size) ? bufferMap[idx] : bufferMap[size-1];
}

//+------------------------------------------------------------------+
//| Compute buffer B with optional ATR addition                      |
//+------------------------------------------------------------------+
double ComputeBufferB(int n, PosLists &poslists)
{
   double B = GetBuffer_REV_7_2(n, poslists);
   gdebugD04 = B;

   if(UseATRinBuffer)
     {
      ENUM_TIMEFRAMES tf = (Timeframe==0 ? (ENUM_TIMEFRAMES)Period() : Timeframe);
      int atrHandle = iATR(_Symbol, tf, ATR_Period);
      if(atrHandle != INVALID_HANDLE)
        {
         double atrBuf[];
         if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) == 1 && atrBuf[0] > 0.0)
            B += ATR_BufferFactor * atrBuf[0];
         IndicatorRelease(atrHandle);
        }
     }
   return B;
}

//+------------------------------------------------------------------+
//| Compute next lot size for continuation order (entry-aware)       |
//+------------------------------------------------------------------+
double ComputeNextLotSizeINC_EntryAware(ENUM_ORDER_TYPE nextType,
                                        double nextEntry,
                                        PosLists &poslists)
{
   int n = ArraySize(poslists.lstWNSL);
   SortByOpenTimeAscending(poslists.lstWNSL);

   if(n == 0) return AlignVolume(_Symbol, LotSizeInput);

   double B = ComputeBufferB(n, poslists);
   if(B <= 0.0) return AlignVolume(_Symbol, LotSizeInput);

   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = MathMax(ask-bid, 0.0);
   double tickSz = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickVl = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSz<=0.0||tickVl<=0.0) return AlignVolume(_Symbol, LotSizeInput);

   double moneyPerPricePerLot = tickVl / tickSz;
   double Pstar = (nextType==ORDER_TYPE_BUY_STOP ? nextEntry+B : nextEntry-B);

   double pnlMoney = 0.0;
   for(int i = 0; i < n; i++)
     {
      double e   = poslists.lstWNSL[i].openPrice;
      double lot = poslists.lstWNSL[i].lots;
      double pricePnL = (poslists.lstWNSL[i].type==POSITION_TYPE_BUY) ?
                        Pstar - e : e - (Pstar+spread);
      pnlMoney += pricePnL * moneyPerPricePerLot * lot;
      pnlMoney -= gCommissionPerLot * lot;
     }

   double contribPerLot = (nextType==ORDER_TYPE_BUY_STOP ?
                           ((Pstar-nextEntry)-spread)*moneyPerPricePerLot :
                           ((nextEntry-Pstar)-spread)*moneyPerPricePerLot);
   contribPerLot -= gCommissionPerLot;

   if(contribPerLot <= 0.0) return AlignVolume(_Symbol, LotSizeInput);

   double neededLots = -pnlMoney / contribPerLot;
   if(neededLots <= 0.0) return 0.0;
   return AlignVolume(_Symbol, neededLots);
}

//+------------------------------------------------------------------+
//| Compute next lot size for new order placement                    |
//| Also sets ptype (BUY_STOP or SELL_STOP) based on last position  |
//+------------------------------------------------------------------+
double ComputeNextLotSizeINC(ENUM_ORDER_TYPE &ptype,
                             double buyEntry,
                             double sellEntry,
                             PosLists &poslists)
{
   int n = ArraySize(poslists.lstWNSL);
   SortByOpenTimeAscending(poslists.lstWNSL);

   if(n <= 0) return AlignVolume(_Symbol, LotSizeInput);

   int lastSide = poslists.lstWNSL[n-1].type;
   ptype = (lastSide==POSITION_TYPE_BUY ? ORDER_TYPE_SELL_STOP : ORDER_TYPE_BUY_STOP);

   double B = ComputeBufferB(n, poslists);
   if(B <= 0.0) return AlignVolume(_Symbol, LotSizeInput);

   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = MathMax(ask-bid, 0.0);
   double tickSz = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickVl = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   double moneyPerPricePerLot = (tickSz>0&&tickVl>0) ? tickVl/tickSz : 0.0;
   double Pstar = (ptype==ORDER_TYPE_BUY_STOP ? buyEntry+B : sellEntry-B);

   double pnlMoney = 0.0;
   for(int i = 0; i < n; i++)
     {
      double e   = poslists.lstWNSL[i].openPrice;
      double lot = poslists.lstWNSL[i].lots;
      double pricePnL = (poslists.lstWNSL[i].type==POSITION_TYPE_BUY) ?
                        Pstar-e : e-(Pstar+spread);
      pnlMoney += pricePnL * moneyPerPricePerLot * lot;
      pnlMoney -= gCommissionPerLot * lot;
     }

   double contribPerLot = (ptype==ORDER_TYPE_BUY_STOP ?
                           ((Pstar-buyEntry)-spread)*moneyPerPricePerLot :
                           ((sellEntry-Pstar)-spread)*moneyPerPricePerLot);
   contribPerLot -= gCommissionPerLot;

   if(contribPerLot <= 0.0) return 0.0;
   double neededLots = -pnlMoney / contribPerLot;
   if(neededLots <= 0.0) return 0.0;
   return AlignVolume(_Symbol, neededLots);
}

#endif
