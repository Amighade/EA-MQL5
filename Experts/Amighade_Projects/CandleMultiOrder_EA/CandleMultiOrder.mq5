//+------------------------------------------------------------------+
//| CandleMultiOrder.mq5                                              |
//| Expert Advisor: Candle Multi-Order RR (MT5) - Rev 8.6            |
//| Converted to multi-file project structure                        |
//|                                                                  |
//| STRATEGY: Laddering with three protective systems                |
//|   1. ABWCL  - Epoch-based wall protection                        |
//|   2. COMPRESSION - Non-epoch adaptive protection                 |
//|   3. BUDGET - Margin-based sequential SL chain                   |
//|                                                                  |
//| Coordinator only — no trading logic here                         |
//| All logic lives in Engines/ and Utils/                           |
//+------------------------------------------------------------------+
#property copyright "CandleMultiOrder EA Rev 8.6"
#property version   "8.60"
#property strict

//+------------------------------------------------------------------+
//| INCLUDE ORDER — respect dependency chain                          |
//| Inputs → Models → Utils → Engines                                |
//+------------------------------------------------------------------+
#include "Inputs.mqh"
#include "Models/EAState.mqh"
#include "Models/RangeState.mqh"

#include "Utils/MathUtils.mqh"
#include "Utils/TradeUtils.mqh"
#include "Utils/SessionFilter.mqh"
#include "Utils/CandleUtils.mqh"
#include "Utils/ResonanceUtils.mqh"
#include "Utils/TelegramUtils.mqh"
#include "Utils/DebugLogger.mqh"

#include "Engines/ResetEngine.mqh"
#include "Engines/ABWCLEngine.mqh"
#include "Engines/ArmingEngine.mqh"
#include "Engines/LotEngine.mqh"
#include "Engines/EntryEngine.mqh"
#include "Engines/BudgetEngine.mqh"
#include "Engines/CompressionEngine.mqh"
#include "Engines/PlacementEngine.mqh"

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== CandleMultiOrder OnInit() started ===");

   // Detect fill mode
   DetectWorkingFillMode();

   // Resolve timeframe
   ENUM_TIMEFRAMES tf = (Timeframe==0 ? (ENUM_TIMEFRAMES)Period() : Timeframe);

   // Load persisted range state
   LoadRangeState();

   // Initialize candle handle
   if(InpCandleSourceMode == CANDLE_SOURCE_HA)
     {
      gCandleHandle = iCustom(_Symbol, tf, "Examples\\Heiken_Ashi");
      if(gCandleHandle == INVALID_HANDLE)
        {
         PrintFormat("Failed to create Heiken Ashi handle for %s, error=%d", _Symbol, GetLastError());
         return INIT_FAILED;
        }
     }
   else
      gCandleHandle = INVALID_HANDLE;

   // Symbol info
   gMinLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   gMaxLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   gLotStep   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   gTickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   gTickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   gPoint     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(gTickSize <= 0) gTickSize = gPoint;

   if(gTickSize<=0.0 || gTickValue<=0.0)
     { Print("OnInit: invalid tickSize/tickValue"); return INIT_FAILED; }

   // Commission
   gCommissionPerLot = GetSymbolCommissionPerLot(_Symbol);

   // Margin buffer
   gMarginUsedBufferLevel = MarginUsedBufferLevel;
   if(gMarginUsedBufferLevel == 0.0)
      gMarginUsedBufferLevel = (AccountInfoDouble(ACCOUNT_BALANCE) -
                                AccountInfoDouble(ACCOUNT_MARGIN)) / (LotSizeInput / gMinLot);

   // Magic number
   MagicNumber = (InMagicNumber==0 ? BuildMagicNumber(_Symbol,tf) : InMagicNumber);

   // Resonance window
   ArrayResize(priceWindow, WindowSize);
   ArrayInitialize(priceWindow, 0);
   windowCount = 0;
   resonanceDirection = "NONE";

   // Parse buffer map
   if(ParseBufferMap(BaseBufferPrice) == 0)
     { Print("Buffer map parsing failed"); return INIT_FAILED; }

   // Telegram
   SetTelegramRoute();
   if(topic_id == "")
     { Print("ERROR: topic_id not set"); return INIT_FAILED; }

   Print("Telegram Route → Group:", group_id, " Topic:", topic_id);
   SendTelegramMessage(__FILE__ +
      " Asymmetric:" + DoubleToString(AsymmetricRangeDistanceInPrice,1) +
      " BB:" + BaseBufferPrice +
      " EMinRF:" + DoubleToString(EntryMinRangeFactor,1) +
      " EMaxRF:" + DoubleToString(EntryMaxRangeFactor,1));

   Print("=== CandleMultiOrder OnInit() completed ===");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(gCandleHandle != INVALID_HANDLE)
     {
      IndicatorRelease(gCandleHandle);
      gCandleHandle = INVALID_HANDLE;
     }
   Print("CandleMultiOrder EA stopped. Reason=", reason);
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!UpdateCandleData()) return;

   PosLists poslists;
   BuildAllListsSorted(poslists);
   int nAll      = ArraySize(poslists.lstAll);
   int nAllDeals = ArraySize(poslists.lstAllDeals);

   // Update resonance window
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(windowCount < WindowSize)
      priceWindow[windowCount++] = currentPrice;
   else
     {
      for(int i = 0; i < WindowSize-1; i++) priceWindow[i] = priceWindow[i+1];
      priceWindow[WindowSize-1] = currentPrice;
     }

   DisplayDebugging();

   if(!IsTradingAllowedNow() && nAllDeals==0) return;

   // Every tick: compression + budget execution
   if(gCompressionActive) ManageCompressionProtect(poslists);
   if(gBudgetExhausted)   ManageBudget(poslists);

   // Once per bar: decision makers
   if(IsNewBar())
     {
      ManageArming(poslists);
      ExhaustBudgetCheck(poslists);
      EnterCompressionProtect(poslists);
      ManageOpenPendingOrder(poslists);
     }

   if(!IsTradingAllowedNow() && nAll==0) return;

   // Reset state if no deals
   if(nAllDeals==0)
     {
      if(gABWCLArmed || gbuyEntry_range!=0.0 || gsellEntry_range!=0.0 ||
         ArraySize(gEpochWinnerTickets)>0 || ArraySize(gEpochLoserTickets)>0)
        {
         ResetABWCLCore(false);
         ResetAnchorAndRange();
         ResetBudgetExhausted();
        }
     }

   // Placement gate (debounced)
   ENUM_TIMEFRAMES tf = (Timeframe==0 ? (ENUM_TIMEFRAMES)Period() : Timeframe);
   datetime barId = iTime(_Symbol, tf, 0);
   bool newBarSincePlacement = (barId != gLastPlaceBar);
   bool quietAfterTx         = (TimeCurrent() - gLastTxTime >= 2);

   if(newBarSincePlacement || quietAfterTx)
     {
      if(!gBudgetExhausted && !HasPendingOrder(_Symbol, MagicNumber))
        {
         PlaceBreakoutOrders(_Symbol, poslists);
         gLastPlaceBar = barId;
        }
     }
}

//+------------------------------------------------------------------+
//| OnTradeTransaction                                                |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   // Filter: our symbol and magic only
   const string txn_symbol = (StringLen(trans.symbol) ? trans.symbol : "");
   if(txn_symbol != _Symbol) return;

   if(!UpdateCandleData()) return;

   PosLists poslists;
   BuildAllListsSorted(poslists);
   int nAll      = ArraySize(poslists.lstAll);
   int nAllDeals = ArraySize(poslists.lstAllDeals);

   ManageOpenPendingOrder(poslists);

   // Immediate actions on deal fill
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      if(nAll > 3)
         SendTelegramMessage("Deal qty:" + IntegerToString(nAll) +
                             " MarginUsed:" + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN),0) +
                             " Buffer:" + DoubleToString(gdebugD04,0));

      if(!gCompressionActive && !gABWCLArmed && UseCompressionProtect)
         EnterCompressionProtect(poslists);

      if(gCompressionActive)
         ManageCompressionProtect(poslists);

      ExhaustBudgetCheck(poslists);
      if(gBudgetExhausted) ManageBudget(poslists);

      if(gABWCLArmed) ManageArming(poslists);

      ManageOpenPendingOrder(poslists);
     }

   if(trans.type == TRADE_TRANSACTION_DEAL_DELETE ||
      trans.type == TRADE_TRANSACTION_POSITION)
     {
      if(gABWCLArmed) ManageArming(poslists);
      ManageOpenPendingOrder(poslists);
     }

   gLastTxTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| OnChartEvent (optional — extend for dashboard button later)      |
//+------------------------------------------------------------------+
// void OnChartEvent(const int id, const long &lparam,
//                   const double &dparam, const string &sparam) {}
