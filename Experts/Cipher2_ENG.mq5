//+------------------------------------------------------------------+
//| Grid Hedge EA — Continuous v3 (One-Time Hedge Boost)           |
//| Reversed-volume version: Level 1 has the highest volume,        |
//| later levels have less                                          |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

//--------------------------------------------------------------------
// ⚙️  Trading settings
//--------------------------------------------------------------------
input long   MagicNumber          = 20240624; // Unique ID for this EA
input double BasketProfitUSD       = 100.0;    // Total basket profit limit
input double BasketLossUSD         = 50.0;     // Total basket loss limit
input double TrailingUSD           = 10.0;     // Single-position trailing threshold
input int    GridLevels            = 5;
input int    GridOffsetPoints      = 30;
input int    GridStepPoints        = 30;
input int    TrailingPoints        = 30;
input int    HedgeShiftPoints      = 30;
input double CommissionPerLot      = 0.8;
input int    MaxSpreadPoints       = 30;
input int    SpreadWarnPoints      = 20;
input int    OrderDeviationPts     = 30;       // Max allowed slippage during market execution

// ── Staircase volume (reversed: high to low) ───────────────────
input double StartLot              = 0.01;     // Volume of the last level (lowest)
input double LotStep               = 0.01;     // Decrease step per level
input double MaxLotSize            = 0.8;       // Max volume per order

// ── Tick-independent management ─────────────────────────────────
input int    TimerMs               = 100;      // Check interval (ms) — lower = more precise

// ── Total basket profit trailing ─────────────────────────────────
input bool   UseBasketTrail        = false;     // Lock total basket profit
input double TrailStartUSD          = 50.0;     // Activate from this profit level onward
input double TrailGiveBackUSD       = 15.0;     // Giveback from peak → close basket
input int    TrailStepPoints        = 10;       // Minimum SL movement (anti-spam)

// ── Hedge volume increase ─────────────────────────────────────────
input double FirstHedgeMultiplier  = 2.0;       // Hedge volume = ultimately this × the activated order's volume

// ── Adaptive slippage ─────────────────────────────────────────────
input double InitSlippagePts       = 30.0;
input int    SlipMinSamples        = 5;
input double SlipEmaAlpha          = 0.2;
input double SlipNoisePercent      = 30.0;      // Slippage noise ±% (backtest only)

//--------------------------------------------------------------------
// 🔒  Security settings
//--------------------------------------------------------------------
 long   AllowedAccount        = 62130002;
 string LicenseStart          = "2020.01.01";
 string LicenseEnd            = "2027.01.01";

CTrade trade;

int    prevPositionCount  = 0;
int    prevBuyCount       = 0;
int    prevSellCount      = 0;
bool   trailingTriggered  = false;
bool   g_closing          = false;   // Continuous closing mode until fully flat
bool   g_manageBusy       = false;   // Prevent simultaneous entry from OnTick and OnTimer

// Volume increase only once per full series
bool   g_hedgeBoostApplied = false;
double g_lockedHedgeTarget = 0.0;
ulong  g_seenActivationOrders[];

// ── Adaptive slippage ────────────────────────────────────────────
double g_slipEma     = 0;
int    g_slipSamples = 0;
double g_slipSum     = 0;
double g_slipMin     = 1e9;
double g_slipMax     = 0;

// ── Basket trailing ──────────────────────────────────────────────
double g_peakBasketProfit = 0;
bool   g_basketTrailArmed = false;

//--------------------------------------------------------------------
// Normalize volume based on broker limits
//--------------------------------------------------------------------
double NormalizeVolume(double lots)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) step = 0.01;

   double v = MathRound(lots / step) * step;
   if(v < minLot) v = minLot;
   if(v > maxLot) v = maxLot;

   int digits = (int)MathCeil(-MathLog10(step));
   if(digits < 0) digits = 0;
   return NormalizeDouble(v, digits);
}

//--------------------------------------------------------------------
// Volume per grid level — 🔄 reversed: level 1 highest, last level = StartLot
//--------------------------------------------------------------------
double GridLotForLevel(int level)
{
   // Previously: StartLot + (level - 1) * LotStep  (low to high)
   // Now:        StartLot + (GridLevels - level) * LotStep  (high to low)
   double lot = StartLot + (GridLevels - level) * LotStep;
   if(lot > MaxLotSize) lot = MaxLotSize;
   if(lot < StartLot)   lot = StartLot;
   return NormalizeVolume(lot);
}

//--------------------------------------------------------------------
// Persistent state for the one-time volume increase
//--------------------------------------------------------------------
string HedgeStateKey()
{
   return StringFormat("GH3_%I64d_%s_%I64d",
                       AccountInfoInteger(ACCOUNT_LOGIN), _Symbol, MagicNumber);
}

void SaveHedgeState()
{
   string key = HedgeStateKey();
   if(g_hedgeBoostApplied)
   {
      double stored = (g_lockedHedgeTarget > 0.0) ? g_lockedHedgeTarget : -1.0;
      GlobalVariableSet(key, stored);
      GlobalVariablesFlush();
   }
   else if(GlobalVariableCheck(key))
   {
      GlobalVariableDel(key);
      GlobalVariablesFlush();
   }
}

void ClearHedgeState()
{
   g_hedgeBoostApplied = false;
   g_lockedHedgeTarget = 0.0;
   string key = HedgeStateKey();
   if(GlobalVariableCheck(key))
   {
      GlobalVariableDel(key);
      GlobalVariablesFlush();
   }
}

void RestoreHedgeState()
{
   g_hedgeBoostApplied = false;
   g_lockedHedgeTarget = 0.0;

   string key = HedgeStateKey();
   if(GlobalVariableCheck(key))
   {
      double stored = GlobalVariableGet(key);
      if(stored != 0.0)
      {
         g_hedgeBoostApplied = true;
         g_lockedHedgeTarget = (stored > 0.0) ? stored : 0.0;
         PrintFormat("🔒 Series volume lock restored | Target: %.2f", g_lockedHedgeTarget);
      }
   }
}

bool ActivationOrderSeen(ulong orderTicket)
{
   if(orderTicket == 0) return false;
   for(int i = 0; i < ArraySize(g_seenActivationOrders); i++)
      if(g_seenActivationOrders[i] == orderTicket) return true;
   return false;
}

void MarkActivationOrderSeen(ulong orderTicket)
{
   if(orderTicket == 0 || ActivationOrderSeen(orderTicket)) return;
   int n = ArraySize(g_seenActivationOrders);
   ArrayResize(g_seenActivationOrders, n + 1);
   g_seenActivationOrders[n] = orderTicket;
}

void ClearActivationOrders()
{
   ArrayResize(g_seenActivationOrders, 0);
}

//--------------------------------------------------------------------
// Valid pending price respecting STOPS/FREEZE LEVEL
//--------------------------------------------------------------------
double PendingProtectionDistance()
{
   long stops  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freeze = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   return (MathMax(stops, freeze) + 1) * _Point;
}

double ValidPendingPrice(ENUM_ORDER_TYPE type, double requested)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double d   = PendingProtectionDistance();

   if(type == ORDER_TYPE_BUY_STOP)
      return NormalizeDouble(MathMax(requested, ask + d), _Digits);

   if(type == ORDER_TYPE_SELL_STOP)
      return NormalizeDouble(MathMin(requested, bid - d), _Digits);

   return NormalizeDouble(requested, _Digits);
}

bool TradeResultAccepted()
{
   uint rc = trade.ResultRetcode();
   return (rc == TRADE_RETCODE_DONE ||
           rc == TRADE_RETCODE_PLACED ||
           rc == TRADE_RETCODE_DONE_PARTIAL ||
           rc == TRADE_RETCODE_NO_CHANGES ||
           rc == TRADE_RETCODE_ORDER_CHANGED);
}

void LogTradeFailure(string action, ulong ticket = 0)
{
   if(ticket > 0)
      PrintFormat("❌ %s | ticket=%I64u | ret=%u | %s | err=%d",
                  action, ticket, trade.ResultRetcode(),
                  trade.ResultRetcodeDescription(), GetLastError());
   else
      PrintFormat("❌ %s | ret=%u | %s | err=%d",
                  action, trade.ResultRetcode(),
                  trade.ResultRetcodeDescription(), GetLastError());
}

bool PlaceStopOrder(ENUM_ORDER_TYPE type, double volume, double requestedPrice,
                    string comment, ulong &newTicket)
{
   newTicket = 0;
   double price = ValidPendingPrice(type, requestedPrice);
   bool called = false;

   ResetLastError();
   if(type == ORDER_TYPE_BUY_STOP)
      called = trade.BuyStop(volume, price, _Symbol, 0, 0,
                             ORDER_TIME_GTC, 0, comment);
   else if(type == ORDER_TYPE_SELL_STOP)
      called = trade.SellStop(volume, price, _Symbol, 0, 0,
                              ORDER_TIME_GTC, 0, comment);

   if(called && TradeResultAccepted())
   {
      newTicket = trade.ResultOrder();
      return true;
   }

   LogTradeFailure("Create Pending");
   return false;
}

bool ModifyPendingPrice(ulong ticket, ENUM_ORDER_TYPE type, double requestedPrice)
{
   if(!OrderSelect(ticket)) return false;

   double price = ValidPendingPrice(type, requestedPrice);
   double oldPrice = OrderGetDouble(ORDER_PRICE_OPEN);
   double sl = OrderGetDouble(ORDER_SL);
   double tp = OrderGetDouble(ORDER_TP);
   ENUM_ORDER_TYPE_TIME timeType = (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
   datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);

   if(MathAbs(price - oldPrice) < _Point / 2.0)
      return true;

   ResetLastError();
   bool called = trade.OrderModify(ticket, price, sl, tp,
                                   timeType, expiration, 0.0);
   if(called && TradeResultAccepted()) return true;

   LogTradeFailure("Move Pending", ticket);
   return false;
}

//--------------------------------------------------------------------
// Effective slippage
//--------------------------------------------------------------------
double EffectiveSlippage()
{
   double base = (g_slipSamples >= SlipMinSamples) ? g_slipEma : InitSlippagePts;
   if(MQLInfoInteger(MQL_TESTER))
   {
      double noise = base * (SlipNoisePercent / 100.0);
      double rnd   = (MathRand() / 32767.0) * 2.0 - 1.0;   // between -1 and +1
      base = MathMax(0, base + rnd * noise);
   }
   return base;
}

//--------------------------------------------------------------------
// Calculate slippage from deal history
//--------------------------------------------------------------------
void UpdateSlippageFromDeal(ulong dealTicket)
{
   if(!HistoryDealSelect(dealTicket)) return;
   if(HistoryDealGetString(dealTicket, DEAL_SYMBOL)  != _Symbol)     return;
   if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC)  != MagicNumber) return;

   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_OUT) return;

   double dealPrice   = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   ulong  orderTicket = (ulong)HistoryDealGetInteger(dealTicket, DEAL_ORDER);
   if(!HistoryOrderSelect(orderTicket)) return;

   double orderPrice = HistoryOrderGetDouble(orderTicket, ORDER_PRICE_OPEN);
   if(orderPrice <= 0) return;

   long   dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   double abSlip   = MathAbs((dealType == DEAL_TYPE_BUY)
                     ? (dealPrice - orderPrice) / _Point
                     : (orderPrice - dealPrice) / _Point);

   g_slipSamples++;
   g_slipSum += abSlip;
   if(abSlip < g_slipMin) g_slipMin = abSlip;
   if(abSlip > g_slipMax) g_slipMax = abSlip;

   if(g_slipSamples < SlipMinSamples)
      g_slipEma = g_slipSum / g_slipSamples;
   else
   {
      if(g_slipEma == 0) g_slipEma = g_slipSum / g_slipSamples;
      g_slipEma = SlipEmaAlpha * abSlip + (1.0 - SlipEmaAlpha) * g_slipEma;
   }

   PrintFormat("📊 Slippage: %.1f pts | EMA: %.2f pts | samples: %d | min:%.1f max:%.1f",
               abSlip, g_slipEma, g_slipSamples, g_slipMin, g_slipMax);
}

void LoadHistoricalSlippage()
{
   datetime from = TimeCurrent() - 30 * 86400;
   if(!HistorySelect(from, TimeCurrent())) return;
   int total = HistoryDealsTotal();
   PrintFormat("📂 Loading history: %d deals", total);
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)     continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber) continue;
      UpdateSlippageFromDeal(ticket);
   }
   if(g_slipSamples > 0)
      PrintFormat("✅ Slippage from history: EMA=%.2f pts | %d samples | min=%.1f max=%.1f",
                  g_slipEma, g_slipSamples, g_slipMin, g_slipMax);
   else
      PrintFormat("ℹ️  Not enough history — initial slippage: %.1f pts", InitSlippagePts);
}

//--------------------------------------------------------------------
// 🔒  License check
//--------------------------------------------------------------------
bool IsLicensed()
{
   if(AccountInfoInteger(ACCOUNT_LOGIN) != AllowedAccount)
   { Print("⛔ This EA is only permitted for account ", AllowedAccount, "."); return false; }
   datetime now = TimeCurrent();
   if(now < StringToTime(LicenseStart)) { Print("⛔ License not yet active: ", LicenseStart); return false; }
   if(now > StringToTime(LicenseEnd))   { Print("⛔ License expired: ", LicenseEnd);   return false; }
   return true;
}

bool IsSpreadOK()
{
   int sp = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(sp >= MaxSpreadPoints) { PrintFormat("⛔ Unreasonable spread: %d pts", sp); return false; }
   if(sp >= SpreadWarnPoints)  PrintFormat("⚠️  High spread: %d pts", sp);
   return true;
}

//--------------------------------------------------------------------
// Does exposure belonging to this EA and symbol exist?
//--------------------------------------------------------------------
bool HasOpenEaPosition()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      return true;
   }
   return false;
}

bool HasExposure()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)     continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      return true;
   }
   for(int i = OrdersTotal()-1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)     continue;
      if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
      return true;
   }
   return false;
}

//--------------------------------------------------------------------
// Estimated cost
//--------------------------------------------------------------------
double EstimatedCostByLots(double lots)
{
   double tickVal    = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSz     = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSz <= 0) return CommissionPerLot * lots;
   double pointValue = (tickVal / tickSz) * _Point * lots;
   double spreadCost = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * pointValue;
   double slipCost   = EffectiveSlippage() * pointValue;
   double commCost   = CommissionPerLot * lots;
   return spreadCost + slipCost + commCost;
}

double EstimatedCost(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return 0;
   return EstimatedCostByLots(PositionGetDouble(POSITION_VOLUME));
}

//--------------------------------------------------------------------
// Analyze position status (this EA and symbol only)
//--------------------------------------------------------------------
struct PositionStats
{
   int    buyCount;
   int    sellCount;
   double buyNetPnL;
   double sellNetPnL;
   double totalNetPnL;
};

PositionStats GetStats()
{
   PositionStats s;
   s.buyCount=0; s.sellCount=0;
   s.buyNetPnL=0; s.sellNetPnL=0; s.totalNetPnL=0;

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)     continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      long   type = PositionGetInteger(POSITION_TYPE);
      double net  = PositionGetDouble(POSITION_PROFIT) - EstimatedCost(ticket);

      if(type == POSITION_TYPE_BUY) { s.buyCount++;  s.buyNetPnL  += net; }
      else                          { s.sellCount++; s.sellNetPnL += net; }
      s.totalNetPnL += net;
   }
   return s;
}

double EffectiveLossLimit(const PositionStats &s)
{
   if(s.buyCount >= 1 && s.sellCount >= 1)
   {
      PrintFormat("⚠️  Hedge mode (buy=%d sell=%d) → loss limit: %.2f$",
                  s.buyCount, s.sellCount, BasketLossUSD * 2.0);
      return BasketLossUSD * 2.0;
   }
   return BasketLossUSD;
}

//--------------------------------------------------------------------
// Full, reliable close — pendings first, then positions
//--------------------------------------------------------------------
bool CloseEverything()
{
   bool allOk = true;

   // Snapshot the tickets so delete/close doesn't disrupt the loop
   ulong orderTickets[];
   ArrayResize(orderTickets, 0);
   for(int i = OrdersTotal()-1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
      int n = ArraySize(orderTickets);
      ArrayResize(orderTickets, n + 1);
      orderTickets[n] = t;
   }

   for(int i = 0; i < ArraySize(orderTickets); i++)
   {
      ulong t = orderTickets[i];
      if(!OrderSelect(t)) continue;
      ResetLastError();
      bool called = trade.OrderDelete(t);
      if(!(called && TradeResultAccepted()) && OrderSelect(t))
      {
         allOk = false;
         LogTradeFailure("Delete Pending during Reset", t);
      }
   }

   ulong positionTickets[];
   ArrayResize(positionTickets, 0);
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      int n = ArraySize(positionTickets);
      ArrayResize(positionTickets, n + 1);
      positionTickets[n] = t;
   }

   for(int i = 0; i < ArraySize(positionTickets); i++)
   {
      ulong t = positionTickets[i];
      if(!PositionSelectByTicket(t)) continue;
      ResetLastError();
      bool called = trade.PositionClose(t, (ulong)OrderDeviationPts);
      if(!(called && TradeResultAccepted()) && PositionSelectByTicket(t))
      {
         allOk = false;
         LogTradeFailure("Close Position during Reset", t);
      }
   }

   return allOk && !HasExposure();
}

void ResetCycleStateAfterFlat()
{
   prevPositionCount  = 0;
   prevBuyCount       = 0;
   prevSellCount      = 0;
   trailingTriggered  = false;
   g_basketTrailArmed = false;
   g_peakBasketProfit = 0;
   ClearActivationOrders();
   ClearHedgeState();
}

void FullReset()
{
   g_closing = true;
   bool flat = CloseEverything();

   if(flat)
   {
      ResetCycleStateAfterFlat();
      g_closing = false;
      Print("✅ Full series closed; volume-increase lock released for the next series");
   }
   else
   {
      Print("⏳ Part of the series remains; the next cycle will try to close it again");
   }
}

//--------------------------------------------------------------------
// Grid layout — reversed staircase volume (high to low)
//--------------------------------------------------------------------
void CreateGrid()
{
   if(!IsSpreadOK()) return;
   if(HasExposure()) return;

   // Start a completely new series
   ClearActivationOrders();
   ClearHedgeState();

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int created = 0;
   bool failed = false;

   for(int i = 1; i <= GridLevels; i++)
   {
      double dist     = (GridOffsetPoints + (i-1) * GridStepPoints) * _Point;
      double buyPrice = ValidPendingPrice(ORDER_TYPE_BUY_STOP,  ask + dist);
      double selPrice = ValidPendingPrice(ORDER_TYPE_SELL_STOP, bid - dist);
      double lot      = GridLotForLevel(i);
      ulong ticket = 0;

      if(PlaceStopOrder(ORDER_TYPE_BUY_STOP, lot, buyPrice, "GRID_BUY", ticket))
         created++;
      else
         failed = true;

      if(PlaceStopOrder(ORDER_TYPE_SELL_STOP, lot, selPrice, "GRID_SELL", ticket))
         created++;
      else
         failed = true;

      PrintFormat("📌 Level %d | Buy: %.5f | Sell: %.5f | distance: %d pts | volume: %.2f",
                  i, buyPrice, selPrice,
                  GridOffsetPoints + (i-1)*GridStepPoints, lot);
   }

   if(failed)
      PrintFormat("⚠️ Grid created with %d of %d orders; the EA will not stop and existing trades continue",
                  created, GridLevels * 2);
   else
      PrintFormat("✅ Grid fully created: %d orders", created);
}

//--------------------------------------------------------------------
// Move opposite orders
// Hedge volume: ultimately FirstHedgeMultiplier × the activated order's volume — never more
//--------------------------------------------------------------------
void AdjustOppositeOrders(ENUM_POSITION_TYPE activatedType, double activatedVolume)
{
   ENUM_ORDER_TYPE targetOrderType = (activatedType == POSITION_TYPE_BUY)
                                     ? ORDER_TYPE_SELL_STOP
                                     : ORDER_TYPE_BUY_STOP;

   bool firstBoost = !g_hedgeBoostApplied;
   if(firstBoost)
   {
      g_lockedHedgeTarget = NormalizeVolume(
                              MathMin(activatedVolume * FirstHedgeMultiplier,
                                      MaxLotSize));
      g_hedgeBoostApplied = true;
      SaveHedgeState(); // Saved before orders are changed so it is never multiplied again

      PrintFormat("🔒 One-time volume increase activated | Base volume: %.2f | Fixed series target: %.2f",
                  activatedVolume, g_lockedHedgeTarget);
   }
   else
   {
      PrintFormat("↔️ Volume lock is active; only opposite orders' prices are moved | Series target: %.2f",
                  g_lockedHedgeTarget);
   }

   // Fixed snapshot; delete-and-recreate does not cause later orders to be skipped
   ulong tickets[];
   ArrayResize(tickets, 0);
   for(int i = OrdersTotal()-1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != targetOrderType) continue;

      int n = ArraySize(tickets);
      ArrayResize(tickets, n + 1);
      tickets[n] = ticket;
   }

   double shift = HedgeShiftPoints * _Point;
   int moved = 0;
   int boosted = 0;
   int failed = 0;

   for(int i = 0; i < ArraySize(tickets); i++)
   {
      ulong ticket = tickets[i];
      if(!OrderSelect(ticket)) continue;

      double oldPrice  = OrderGetDouble(ORDER_PRICE_OPEN);
      double oldVolume = OrderGetDouble(ORDER_VOLUME_CURRENT);
      string comment   = OrderGetString(ORDER_COMMENT);

      double requestedPrice = (targetOrderType == ORDER_TYPE_SELL_STOP)
                              ? oldPrice + shift
                              : oldPrice - shift;
      double newPrice = ValidPendingPrice(targetOrderType, requestedPrice);

      // Volume increase is only allowed on the series' first activation
      bool needsVolumeBoost = firstBoost &&
                              g_lockedHedgeTarget > 0.0 &&
                              oldVolume + 1e-12 < g_lockedHedgeTarget;

      if(!needsVolumeBoost)
      {
         if(ModifyPendingPrice(ticket, targetOrderType, newPrice)) moved++;
         else failed++;
         continue;
      }

      // Pending volume cannot be modified; it is deleted and rebuilt, but one order's
      // failure does not close the whole series
      ResetLastError();
      bool deleted = trade.OrderDelete(ticket);
      if(!(deleted && TradeResultAccepted()))
      {
         failed++;
         LogTradeFailure("Delete Pending for volume increase", ticket);
         continue;
      }

      ulong newTicket = 0;
      if(PlaceStopOrder(targetOrderType, g_lockedHedgeTarget, newPrice,
                        comment, newTicket))
      {
         boosted++;
         moved++;
         PrintFormat("🔀 Initial volume increase: %.2f → %.2f | price: %.5f → %.5f",
                     oldVolume, g_lockedHedgeTarget, oldPrice, newPrice);
         continue;
      }

      // Rollback: if the increase fails, the previous volume is restored
      ulong rollbackTicket = 0;
      if(PlaceStopOrder(targetOrderType, oldVolume, oldPrice,
                        comment, rollbackTicket))
      {
         failed++;
         PrintFormat("⚠️ Volume increase failed; previous order restored with volume %.2f", oldVolume);
      }
      else
      {
         failed++;
         PrintFormat("🚨 Order %I64u could not be restored after deletion; other trades in the series continue",
                     ticket);
      }
   }

   PrintFormat("✅ Opposite-order adjustment finished | moved=%d boosted=%d failed=%d | boost=%s",
               moved, boosted, failed, firstBoost ? "FIRST-ONLY" : "OFF");
}

//--------------------------------------------------------------------
// Total basket profit trailing — tracks the peak
//--------------------------------------------------------------------
bool BasketProfitTrailing(const PositionStats &s)
{
   if(!UseBasketTrail) return false;
   if(!HasExposure()) { g_basketTrailArmed = false; g_peakBasketProfit = 0; return false; }

   if(!g_basketTrailArmed)
   {
      if(s.totalNetPnL >= TrailStartUSD)
      {
         g_basketTrailArmed = true;
         g_peakBasketProfit = s.totalNetPnL;
         PrintFormat("🚀 Basket trailing activated | Profit: %.2f$ | Allowed giveback: %.2f$",
                     s.totalNetPnL, TrailGiveBackUSD);
      }
      return false;
   }

   if(s.totalNetPnL > g_peakBasketProfit)
      g_peakBasketProfit = s.totalNetPnL;

   double lockLevel = g_peakBasketProfit - TrailGiveBackUSD;
   if(s.totalNetPnL <= lockLevel)
   {
      PrintFormat("💵 Basket profit locked | Peak: %.2f$ → Current: %.2f$ | Locked at: %.2f$",
                  g_peakBasketProfit, s.totalNetPnL, lockLevel);
      return true;
   }
   return false;
}

//--------------------------------------------------------------------
// Position trailing — with a minimum step, respecting STOPS_LEVEL
//--------------------------------------------------------------------
void ApplyTrailing(const PositionStats &s)
{
   long   stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist    = (stopsLevel + 1) * _Point;
   double trailDist  = TrailingPoints * _Point;
   if(trailDist < minDist) trailDist = minDist;
   double stepDist   = TrailStepPoints * _Point;

   double thirdProfit = BasketProfitUSD / 3.0;
   bool   buyTrailOK  = (s.buyCount  >= 2 && s.buyNetPnL  > thirdProfit);
   bool   sellTrailOK = (s.sellCount >= 2 && s.sellNetPnL > thirdProfit);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)     continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      long   type      = PositionGetInteger(POSITION_TYPE);
      double netProfit = PositionGetDouble(POSITION_PROFIT) - EstimatedCost(ticket);
      double sl        = PositionGetDouble(POSITION_SL);
      double tp        = PositionGetDouble(POSITION_TP);

      bool canTrail;
      if(type == POSITION_TYPE_BUY)
         canTrail = (s.buyCount  >= 2) ? buyTrailOK  : (netProfit > TrailingUSD);
      else
         canTrail = (s.sellCount >= 2) ? sellTrailOK : (netProfit > TrailingUSD);

      if(!canTrail) continue;

      if(type == POSITION_TYPE_BUY)
      {
         double newSL = NormalizeDouble(bid - trailDist, _Digits);
         if(newSL <= bid - minDist && (sl == 0 || newSL - sl >= stepDist))
            trade.PositionModify(ticket, newSL, tp);
      }
      else
      {
         double newSL = NormalizeDouble(ask + trailDist, _Digits);
         if(newSL >= ask + minDist && (sl == 0 || sl - newSL >= stepDist))
            trade.PositionModify(ticket, newSL, tp);
      }
   }
}

//--------------------------------------------------------------------
// 🧠 Basket management — tick-independent
//--------------------------------------------------------------------
void ManageBasketCore()
{
   if(!IsLicensed()) { FullReset(); ExpertRemove(); return; }

   // If currently closing: do nothing else until fully flat, and retry
   if(g_closing)
   {
      if(CloseEverything())
      {
         ResetCycleStateAfterFlat();
         g_closing = false;
         Print("✅ All positions and orders closed; new series ready");
      }
      else                    Print("⏳ Retrying to close the remainder...");
      return;
   }

   PositionStats s          = GetStats();
   double        lossLimit  = EffectiveLossLimit(s);
   int currentPositionCount = s.buyCount + s.sellCount;

   // 1️⃣  Basket TP/SL based on total net profit/loss
   bool tpHit = (s.totalNetPnL >=  BasketProfitUSD);
   bool slHit = (s.totalNetPnL <= -lossLimit);
   if(tpHit || slHit)
   {
      PrintFormat("%s Basket closed | Net: %.2f$ | Loss limit: %.2f$ | slip EMA: %.2f pts",
                  tpHit ? "💰" : "🛑", s.totalNetPnL, lossLimit, g_slipEma);
      FullReset();
      return;
   }

   // 2️⃣  Trailing closed a position → FullReset
   if(trailingTriggered)
   { Print("🔄 trailing trigger → FullReset"); FullReset(); return; }

   // 2.5️⃣  Total basket profit lock
   if(BasketProfitTrailing(s))
   { FullReset(); return; }

   // 3️⃣  Fallback: position decrease without a flag
   if(prevPositionCount > 0 && currentPositionCount < prevPositionCount)
   { Print("⚠️  Position decreased without a flag → FullReset"); FullReset(); return; }

   // 4️⃣  Smart position trailing
   ApplyTrailing(s);

   // 5️⃣  New grid
   if(!HasExposure())
   {
      CreateGrid();
      prevPositionCount = 0; prevBuyCount = 0; prevSellCount = 0;
   }
   else
   {
      prevPositionCount = currentPositionCount;
      prevBuyCount      = s.buyCount;
      prevSellCount     = s.sellCount;
   }
}


void ManageBasket()
{
   if(g_manageBusy) return;
   g_manageBusy = true;
   ManageBasketCore();
   g_manageBusy = false;
}

//--------------------------------------------------------------------
// OnTradeTransaction
//--------------------------------------------------------------------
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != MagicNumber) return;

   long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   UpdateSlippageFromDeal(trans.deal);

   if(entry == DEAL_ENTRY_IN)
   {
      long dealType = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
      if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL) return;

      ulong orderTicket = (ulong)HistoryDealGetInteger(trans.deal, DEAL_ORDER);
      if(ActivationOrderSeen(orderTicket))
      {
         PrintFormat("ℹ️ Duplicate partial fill for order %I64u ignored", orderTicket);
         return;
      }
      MarkActivationOrderSeen(orderTicket);

      double dealVol = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
      double baseVol = dealVol;
      if(orderTicket > 0 && HistoryOrderSelect(orderTicket))
      {
         double initialVol = HistoryOrderGetDouble(orderTicket, ORDER_VOLUME_INITIAL);
         if(initialVol > 0.0) baseVol = initialVol;
      }

      ENUM_POSITION_TYPE posType = (dealType == DEAL_TYPE_BUY)
                                   ? POSITION_TYPE_BUY
                                   : POSITION_TYPE_SELL;

      PrintFormat("🟢 %s order activated | deal=%.2f base=%.2f → adjusting opposites",
                  posType == POSITION_TYPE_BUY ? "BUY" : "SELL",
                  dealVol, baseVol);
      AdjustOppositeOrders(posType, baseVol);
   }

   if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
   {
      if(!g_closing)
      {
         Print("🔔 Position closed → Reset flag activated");
         trailingTriggered = true;
      }
   }
}

//--------------------------------------------------------------------
// OnInit
//--------------------------------------------------------------------
int OnInit()
{
   if(!IsLicensed()) { ExpertRemove(); return(INIT_FAILED); }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(OrderDeviationPts);
   trade.SetTypeFillingBySymbol(_Symbol);
   MathSrand((int)TimeCurrent());

   g_slipEma     = InitSlippagePts;
   g_slipSamples = 0;
   g_slipSum     = 0;
   g_slipMin     = 1e9;
   g_slipMax     = 0;

   LoadHistoricalSlippage();

   prevPositionCount  = 0;
   prevBuyCount       = 0;
   prevSellCount      = 0;
   trailingTriggered  = false;
   g_closing          = false;
   g_manageBusy       = false;
   g_basketTrailArmed = false;
   g_peakBasketProfit = 0;
   ClearActivationOrders();

   RestoreHedgeState();
   if(!HasExposure() && g_hedgeBoostApplied)
      ClearHedgeState();
   else if(HasOpenEaPosition() && !g_hedgeBoostApplied)
   {
      // Only an open position means the series has truly started; initial pendings
      // do not activate the lock
      g_hedgeBoostApplied = true;
      g_lockedHedgeTarget = 0.0;
      SaveHedgeState();
      Print("⚠️ Open position found with no lock history; volume re-increase blocked for this series");
   }

   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      Print("⚠️ Account is Netting; chain execution may differ from real Hedge behavior");

   EventSetMillisecondTimer(TimerMs);

   PrintFormat("✅ EA Continuous v3 (Reversed Lots) started | Account: %d | Valid until: %s", AllowedAccount, LicenseEnd);
   PrintFormat("   Volume layout: reversed (high→low) | Level 1: %.2f ... Level %d: %.2f | MaxLot: %.2f | Timer: %dms",
               GridLotForLevel(1), GridLevels, GridLotForLevel(GridLevels), MaxLotSize, TimerMs);
   PrintFormat("   BasketTrail: %s | Start: %.0f$ | GiveBack: %.0f$ | HedgeMult: %.2f×",
               UseBasketTrail ? "Enabled" : "Disabled", TrailStartUSD, TrailGiveBackUSD, FirstHedgeMultiplier);
   return(INIT_SUCCEEDED);
}

//--------------------------------------------------------------------
// OnDeinit
//--------------------------------------------------------------------
void OnDeinit(const int reason)
{
   EventKillTimer();
   SaveHedgeState();
}

//--------------------------------------------------------------------
// OnTimer  → main reference (tick-independent)
//--------------------------------------------------------------------
void OnTimer()
{
   ManageBasket();
}

//--------------------------------------------------------------------
// OnTick   → double assurance
//--------------------------------------------------------------------
void OnTick()
{
   ManageBasket();
}