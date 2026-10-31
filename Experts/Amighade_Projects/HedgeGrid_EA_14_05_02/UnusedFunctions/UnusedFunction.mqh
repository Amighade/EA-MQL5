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
void CalculateBasketProfits(GridState &state)
{
   double totalProfit    = 0.0;
   double buyProfit      = 0.0;
   double sellProfit     = 0.0;
   double totalNetProfit = 0.0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != state.magicNumber) continue;

      double profit = PositionGetDouble(POSITION_PROFIT);
      double lot    = PositionGetDouble(POSITION_VOLUME);
      totalProfit  += profit;

      // Unified with SL_CalcNetBasket's formula — same InpCommissionPerLot,
      // same single per-lot deduction, no separate entry/exit tracking.
      totalNetProfit += profit - (InpCommissionPerLot * lot);

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         buyProfit += profit;
      else if(type == POSITION_TYPE_SELL)
         sellProfit += profit;
     }

   state.basketProfit     = totalProfit;
   state.basketNetProfit  = totalNetProfit;
   state.basketBuyProfit  = buyProfit;
   state.basketSellProfit = sellProfit;
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
   return sent && (res.retcode == TRADE_RETCODE_DONE ||
                   res.retcode == TRADE_RETCODE_DONE_PARTIAL);
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
//| 2nd pass: replace opposite orders with newLot — but only the     |
//| ones that actually differ. Orders already at newLot are left     |
//| untouched, so repeated same-side hits with no real lot change    |
//| don't churn the whole side for nothing.                          |
//+------------------------------------------------------------------+
void UpdateOppositeGrid_SecondPass(ENUM_ORDER_TYPE hitDirection,
                                   double newLot,
                                   GridState &state)
{
   ENUM_ORDER_TYPE oppositeType = GetOppositeOrderType(hitDirection);
   ulong  tickets[];
   double lots[];
   double prices[];
   int    count = CollectOppositeOrders(oppositeType, state.magicNumber,
                                        tickets, lots, prices);

   int    updatedCount = 0;
   double oldLot       = 0.0;
   double newLotNorm    = NormalizeDouble(newLot, 2);

   for(int i = 0; i < count; i++)
     {
      if(NormalizeDouble(lots[i], 2) == newLotNorm)
         continue; // already correct — leave it alone

      oldLot = lots[i];
      DeleteOrder(tickets[i]);
      if(oppositeType == ORDER_TYPE_SELL_STOP)
         PlaceSellStop(prices[i], newLot, state.magicNumber);
      else
         PlaceBuyStop(prices[i],  newLot, state.magicNumber);
      updatedCount++;
     }

   state.currentBlockLot = newLot;
   if(updatedCount > 0)
      LogLotUpdated(updatedCount, oldLot, newLot);
}

void UpdateOppositeGrid_ModeA_old(GridState &state)
{
   double newLot = AlignVolume(_Symbol, state.lastHitLot * 2.0);
   UpdateOppositeGrid_FirstPass(state.lastHitDirection, newLot, state);
}

double GetHighestBuyStop(int magicNumber, double &outLot)
{
   double highest = 0.0;
   outLot = 0.0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_STOP) continue;
      double p   = OrderGetDouble(ORDER_PRICE_OPEN);
      double lot = OrderGetDouble(ORDER_VOLUME_CURRENT);
      if(p > highest)
        {
         highest = p;
         outLot = lot;
        }
     }
   return highest;
}

double GetLowestSellStop(int magicNumber, double &outLot)
{
   double lowest = DBL_MAX;
   outLot = 0.0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL)  != _Symbol)    continue;
      if(OrderGetInteger(ORDER_MAGIC)  != magicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_SELL_STOP) continue;
      double p   = OrderGetDouble(ORDER_PRICE_OPEN);
      double lot = OrderGetDouble(ORDER_VOLUME_CURRENT);
      if(p < lowest)
        {
         lowest = p;
         outLot = lot;
        }
     }
   return (lowest == DBL_MAX) ? 0.0 : lowest;
}

int CountPositionType(ENUM_POSITION_TYPE posType, int magicNumber)
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)     continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE)  != posType)     continue;
      count++;
     }
   return count;
}

double GetLowestSellPosition(int magicNumber, double &outLot)
{
   double lowest = DBL_MAX;
   outLot = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)          continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber)      continue;
      if(PositionGetInteger(POSITION_TYPE)  != POSITION_TYPE_SELL) continue;
      double p   = PositionGetDouble(POSITION_PRICE_OPEN);
      double lot = PositionGetDouble(POSITION_VOLUME);
      if(p < lowest)
        {
         lowest = p;
         outLot = lot;
        }
     }
   return (lowest == DBL_MAX) ? 0.0 : lowest;
}

double GetHighestBuyPosition(int magicNumber, double &outLot)
{
   double highest = 0.0;
   outLot = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNumber)     continue;
      if(PositionGetInteger(POSITION_TYPE)  != POSITION_TYPE_BUY) continue;
      double p   = PositionGetDouble(POSITION_PRICE_OPEN);
      double lot = PositionGetDouble(POSITION_VOLUME);
      if(p > highest)
        {
         highest = p;
         outLot = lot;
        }
     }
   return highest;
}

//+------------------------------------------------------------------+
//| Check for gap fault — order should have been hit but was skipped |
//| Returns ticket of skipped order (0 if clean) and writes the      |
//| expected fill price into expectedPrice BEFORE the caller does     |
//| anything else that might deselect/delete the order.               |
//+------------------------------------------------------------------+
ulong CheckGapFault(double currentPrice, int magicNumber, double &expectedPrice)
  {
   expectedPrice = 0.0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != magicNumber) continue;

      double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(orderType == ORDER_TYPE_BUY_STOP && currentPrice > orderPrice + InpGridSpacing)
        { expectedPrice = orderPrice; return ticket; }

      if(orderType == ORDER_TYPE_SELL_STOP && currentPrice < orderPrice - InpGridSpacing)
        { expectedPrice = orderPrice; return ticket; }
     }
   return 0;
  }

//====================================================
// BROKER VALIDATION
//====================================================
bool SL_BrokerOK(int winnerSide, double candidate)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double minStop = MinStopDistancePrice(_Symbol);

   if(winnerSide == POSITION_TYPE_BUY)
      return (candidate <= bid - minStop);

   return (candidate >= ask + minStop);
}
//====================================================
// Shared progress guard -- never accept a candidate that moves the SL
// backward relative to what's already applied. Consistent across every
// mode now (previously only 2 of 4 modes had this).
//====================================================
bool SL_IsProgress(ENUM_POSITION_TYPE winnerSide, double candidate, double currentSL)
{
   if(currentSL <= 0) return true; // nothing applied yet -- anything is progress
   return (winnerSide == POSITION_TYPE_BUY) ? (candidate > currentSL) : (candidate < currentSL);
}