//+------------------------------------------------------------------+
// Expert Advisor: Candle Multi-Order RR (MT5) - Rev 8.6
//
// STRATEGY: Laddering with three independent protective systems
//   1. ABWCL - Epoch-based wall protection (Phase A winners, Phase B losers)
//   2. COMPRESSION - Non-epoch adaptive protection (close unprofitable deals)
//   3. BUDGET - Margin-based sequential SL chain (oldest deal first)
//
// THREE ENTRY MODES (ComputeEntry dispatcher):
//   • MODE_FLOATING_BREAKOUT: Above/below HA[1]/HA[2] extremes
//   • MODE_RANGE_ANCHOR: Above/below persistent range cluster
//   • MODE_ASYMMETRIC_ANCHOR: One side HA, opposite by distance
//
// TICK STRUCTURE:
//   Every tick: if(gCompressionActive) ManageCompressionProtect()
//   Once per bar: ManageArming(), ManageBudget(), ManageOpenPendingOrder()
//   Anytime: EnsurePendingOrder() (debounced 1 sec OR new bar)
//
// OnTradeTransaction (IMMEDIATE on DEAL_ADD):
//   [1] Check compression threshold (any tick entry)
//   [2] ManageBudget() (chain continuation)
//   [3] ManageCompressionProtect() (if active, regardless of budget)
//
// FIVE MANAGERS:
// ManageArming()         - [MOP-0-5] epoch state machine
// ExhaustBudgetCheck()         - Margin exhaustion
// ManageCompressionProtect()  
// EnterCompressionProtect(poslists); - Adaptive non-epoch protection
// ManageOpenPendingOrder(poslists);

// CRITICAL (Rev 8.3):
//    [1] MAny of BuildAllListsSorted(poslists) are commented to make it faster
//    [2] many of CancelAllPending are commented except in ManageCompressionProtect
//    [3] 
//    [4] 
//
//+------------------------------------------------------------------+
#property strict
//#property tester_indicator "Examples\\Heiken_Ashi.ex5"

#include <Trade\Trade.mqh>      // Required for trading operations  

// --- Ensure all trade retcodes exist even if broker's include is incomplete
#ifndef TRADE_RETCODE_INVALID_FILL
   #define TRADE_RETCODE_INVALID_FILL   10031
#endif
#ifndef TRADE_RETCODE_INVALID
   #define TRADE_RETCODE_INVALID        10030
#endif
#ifndef TRADE_RETCODE_INVALID_PARAMS
   #define TRADE_RETCODE_INVALID_PARAMS 10033
#endif
#ifndef TRADE_RETCODE_INVALID_STOPS
   #define TRADE_RETCODE_INVALID_STOPS  10034
#endif
// --- Ensure runtime error constants exist
#ifndef ERR_REQUOTE
   #define ERR_REQUOTE            138
#endif
#ifndef ERR_OFF_QUOTES
   #define ERR_OFF_QUOTES         136
#endif
#ifndef ERR_INVALID_PRICE
   #define ERR_INVALID_PRICE      129
#endif

input string _________Section1 = "--- General Settings ---";
input bool EnableDebugLogs = false;
enum SignalType{SIGNAL_NONE = 0,SIGNAL_BUY  = 1,SIGNAL_SELL = -1};

enum RiskModeEnum { RISK_PERCENT, RISK_VALUE };
input RiskModeEnum RiskMode = RISK_PERCENT;  // Choose risk mode
input double   RiskValue               = 10.0;      // % of balance or fixed currency value
input double   RiskPercent             = 0.5;       // Fixed % risk per trade

//enum StopLossModeEnum { SL_INPUT, SL_AUTO };
//input StopLossModeEnum StopLossMode    = SL_INPUT;
//input double   StopLossPriceInput       = 0.25;

enum LotSizeModeEnum { LS_INPUT, LS_AUTO };
input LotSizeModeEnum LotSizeMode      = LS_INPUT;
input double   LotSizeInput            = 0.01;  

//input double   RR_Multiplier           = 2.0;
input int      Slippage                = 5;
input ENUM_TIMEFRAMES Timeframe        = (ENUM_TIMEFRAMES)0;
input ulong    InMagicNumber             = 555111;
//input int      BreakoutOrderBufferPips = 0;

//--- input parameters for time filters
input bool     UseTimeFilter           = false;
input bool     EnableLondon            = true;
input bool     EnableNewYork           = true;
input bool     EnableAsia              = true;
input string   ExtraWindow1            = "";
//HH:MM-HH:MM
input string   ExtraWindow2            = "";
//HH:MM-HH:MM

//input bool     UseBreakeven            = false;
//input double   BreakevenRMultiplier    = 1.0;
//input double   BreakevenBufferPrice     = 0.02;

//input bool     UseTrailingStop         = false; 
//input double   TrailingStopStartPrice  = 0.1;
//input double   TrailingStopStepPrice   = 0.5;

input double   LotMin                  = 0;
input double   LotMax                  = 0;
input int      MaxTradesInCycle        = 0;

input bool     UseATRinBuffer          = false;
input double   ATR_BufferFactor        = 1.0;
input int      ATR_Period              = 14;
input string   BaseBufferPrice         = "0";
input double   MarginUsedBufferLevel   = 4000;
input double   BufferLotDivisor        = 4.0;
input int      BufferLotQty        = 0;
// ============================================================
// 4.8 Inputs: Budget Exhaustion + Compression Protection Layer
// ============================================================
enum BreakoutModeEnum
{
   MODE_FLOATING_BREAKOUT = 0,
   MODE_RANGE_ANCHOR      = 1,
   MODE_ASYMMETRIC_ANCHOR = 2
};
input BreakoutModeEnum BreakoutMode = MODE_RANGE_ANCHOR;

input double AsymmetricRangeDistanceInPrice = 1.5;  
// price distance between buy and sell (gold:2.0, )

// --- Budget exhaustion (margin-based)
input bool   UseBudgetExhaustion = true;
input double MarginReserve       = 0.0;
// FreeMargin AFTER placing next pending must stay >= this
input double AllowedEquity       = 0.0;
// Allowed Equity could be used
input int    ExhaustMaxOpenDeals        = 0;
input int    ExhaustMaxOpenDeals_2        = 0;
// If open deals >= this number, trigger budget exhaustion (0 = disabled)
input double ExhaustMaxDealSize = 0;
input double ExhaustMaxDealSize_2 = 0;
input double ExhaustMaxDealSize_3 = 0;
// If last deals lot >= this number, trigger budget exhaustion (0 = disabled)
// --- Compression protection (adaptive keep-count)
input bool   UseCompressionProtect = true;
input int    CompressionStartDeals = 3;
// enter compression when non-epoch count reaches this

// keep targets based on breakout direction vs FIRST deal side:
input int    DealsKeepToward  = 1;
// keep this many if breakout is toward FIRST deal side
input int    DealsKeepAgainst = 2;
// keep this many if breakout is against FIRST deal side
//+------------------------------------------------------------------+
input int WindowSize = 4;        // Number of points for resonance calculation
double priceWindow[];            // Array to store recent prices
int windowCount = 0;             // Current number of prices in window
input int widenMaxSteps = 10;
double gMarginUsedBufferLevel = 0.0;

enum EntryMode
{
   PREV_N_CANDLE_HIGH_LOW_MAX_MIN       = 0,
   PREV_N_CANDLE_BODY_MAX_MIN    = 1,
   PREV_N_CANDLE_HIGH_LOW_AVRG          = 2,
   PREV_N_CANDLE_BODY_AVRG       = 3,
   PREV_N_CANDLE_HIGH_LOW_BODY_AVRG_MAX_MIN = 4,
   PREV_N_CANDLE_HIGH_LOW_MID_P_RANGE = 5
};

input EntryMode InpEntryMode = PREV_N_CANDLE_HIGH_LOW_MAX_MIN;
input int InpEntryModeN = 1;

input bool   UseEntryRangeFilter_1 = true;
input bool   UseEntryRangeFilter_2 = false;
input double EntryMinRangeFactor = 0.5;
input double EntryMaxRangeFactor = 2.0;

enum WinnerWallMode
{
   PREV_CANDLE_BODY       = 0,
   PREV_CANDLE_HIGH_LOW    = 1,
   PREV_CANDLE_AVRG    = 2
};

input WinnerWallMode InpWinnerWallMode = PREV_CANDLE_BODY;

enum CandleSourceMode
{
   CANDLE_SOURCE_HA = 0,
   CANDLE_SOURCE_RC = 1
};

input CandleSourceMode InpCandleSourceMode = CANDLE_SOURCE_HA;

double resonanceScore = 0;
double resonanceRange = 0;
string resonanceDirection;
string resonanceType = "";
double gCommissionPerLot = 0.0;
ulong MagicNumber = 0;
double gArmedSL = 0;

struct DealRecord
{
   ulong     ticket;
   string    symbol;
   long      type;
   double    lots;
   double    openPrice;
   datetime  openTime;
   double    profit;
   double   sl;
};

struct PosSnap
{
   ulong    ticket;
   int      type;
   double   lots;
   double   openPrice;
   datetime openTime;
   double   profit;
   double   sl;
};

struct PosLists
{
   PosSnap lstAll[];
   PosSnap lstWNSL[];
   PosSnap lstAllDeals[];
   double  totalLot;
};

struct SymbolRoute
{
   string symbolKey;
   string demoTopic;
   string liveTopic;
};

SymbolRoute routes[] =
{
   {"XAUUSD", "2",  "14"},  // GOLD
   {"UKOUSD", "459",  "460"},  // OIL
   {"DJ30",   "476",  "477"},  // INDEX
   {"AUDUSD", "478",  "479"},   // FX
   {"AUDNZD", "478",  "479"},   // FX
   {"BTCUSD", "483",  "485"}   // BTCUSD
};

double         bufferMap[];
int            gCandleHandle                     = INVALID_HANDLE;
double         gOpenBuf[], gHighBuf[], gLowBuf[], gCloseBuf[];
int            gReadyForHAReverse      = 0;
// history arrays
double         entryHistory[100];
double         lotHistory[100];
int            dealCount               = 0;    // number of active/opened deals in current cycle
int            entryCount              = 0;
int            TradesInCycle           = 0;
datetime       lastTradeTime           = 0;

int gLastReversalDir = 0;   // +1 = Candle turned bullish, -1 = bearish
datetime gLastReversalBar = 0; // time of last reversal bar

int gLastSmallestBufferIndex = -1;

enum SendFailAction
{
   SEND_OK,
   RETRY_SAME,
   RETRY_WIDEN,
   FAIL_FATAL,
   FAIL_OTHER
};

struct TradeActionResult
{
   bool           success;
   bool           sent;
   uint           retcode;
   int            lastError;
   SendFailAction action;
};

class DealManager
{
private:
   DealRecord deals[];   // internal list of active deals

public:
   // ============================================================
   // 🔄 Refresh the list of open positions
   // ============================================================
   void Refresh(ulong magic, string symbol)
   {
      ArrayResize(deals, 0);

      int total = PositionsTotal();
      for(int i=0; i<total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != magic) continue;

         DealRecord d;
         d.ticket    = ticket;
         d.symbol    = symbol;
         d.type      = PositionGetInteger(POSITION_TYPE);
         d.lots      = PositionGetDouble(POSITION_VOLUME);
         d.openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         d.openTime  = (datetime)PositionGetInteger(POSITION_TIME);
         d.profit    = PositionGetDouble(POSITION_PROFIT);
         d.sl        = PositionGetDouble(POSITION_SL);
         
         int sz = ArraySize(deals);
         ArrayResize(deals, sz+1);
         deals[sz] = d;
      }
   }

   // ============================================================
   // 📊 Basic statistics
   // ============================================================
   int Count(int typeFilter = -1)
   {
      int cnt = 0;
      for(int i=0; i<ArraySize(deals); i++)
         if(typeFilter==-1 || deals[i].type == typeFilter)
            cnt++;
      return cnt;
   }

   double Lots(int typeFilter = -1)
   {
      double sum = 0;
      for(int i=0; i<ArraySize(deals); i++)
         if(typeFilter==-1 || deals[i].type == typeFilter)
            sum += deals[i].lots;
      return sum;
   }

   double AvgEntry(int typeFilter = -1)
   {
      double sum = 0, lots = 0;
      for(int i=0; i<ArraySize(deals); i++)
      {
         if(typeFilter==-1 || deals[i].type == typeFilter)
         {
            sum  += deals[i].openPrice * deals[i].lots;
            lots += deals[i].lots;
         }
      }
      if(lots == 0) return 0;
      return sum / lots;
   }

   double NetProfit(int typeFilter = -1)
   {
      double sum = 0;
      for(int i=0; i<ArraySize(deals); i++)
         if(typeFilter==-1 || deals[i].type == typeFilter)
            sum += deals[i].profit;
      return sum;
   }

   // ============================================================
   // ❌ Close all or selected deals
   // 2) CloseAll that takes tickets (no stale cache)
   // ============================================================
   int CloseAll(const ulong &tickets[])
   {
      int closed=0;
      for(int i=ArraySize(tickets)-1; i>=0; --i){
         ulong t=tickets[i];
         if(!PositionSelectByTicket(t)){ closed++; continue; }
         if(InternalClose(t)) closed++;
         Sleep(5);
      }
      return closed;
   }

   // 3) Helper to collect tickets by filters, then call CloseAll
   int CloseAllByQuery(string symbol = "", long magicFilter = -1, int typeFilter = -1)
   {
      // Resolve runtime defaults here
      string sym = (symbol == "" ? _Symbol : symbol);
      long   mag = (magicFilter == -1 ? (long)MagicNumber : magicFilter);
   
      ulong tickets[];
      for(int i=PositionsTotal()-1; i>=0; --i)
      {
         ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t)) continue;
   
         if(PositionGetString(POSITION_SYMBOL) != sym) continue;
         if(mag != -1 && (long)PositionGetInteger(POSITION_MAGIC) != mag) continue;
         if(typeFilter != -1 && (int)PositionGetInteger(POSITION_TYPE) != typeFilter) continue;
   
         int n = ArraySize(tickets); ArrayResize(tickets, n+1); tickets[n] = t;
      }
      return CloseAll(tickets);  // your ticket-based closer
   }

   bool CloseUnprotected(int typeFilter = -1)
   {
      bool anyClosed = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;

         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

         long type = PositionGetInteger(POSITION_TYPE);
         double sl = PositionGetDouble(POSITION_SL);

         if((typeFilter == -1 || type == typeFilter) && sl <= 0.0)
         {
            if(ClosePosition(ticket))
            {
               PrintFormat("Closed unprotected %s position (ticket=%I64u)", 
                           (type == POSITION_TYPE_BUY ? "BUY" : "SELL"), ticket);
               anyClosed = true;
            }
         }
      }
      return anyClosed;
   }

   // ============================================================
   // 🧩 Public ClosePosition wrapper
   // ============================================================
   bool ClosePosition(ulong ticket, bool verbose = true)
   {
      Refresh(MagicNumber, _Symbol);

      if(!PositionSelectByTicket(ticket))
      {
         if(verbose) 
            PrintFormat("⚠️ ClosePosition: ticket %I64u not found or already closed.", ticket);
         return false;
      }

      return InternalClose(ticket, verbose);
   }

   bool FastClosePosition(ulong ticket, bool verbose = true)
   {
      Refresh(MagicNumber, _Symbol);

      if(!PositionSelectByTicket(ticket))
      {
         if(verbose) 
            PrintFormat("⚠️ ClosePosition: ticket %I64u not found or already closed.", ticket);
         return false;
      }

      return FastClose(ticket, verbose);
   }
   // ============================================================
   // 🔍 Helpers
   // ============================================================
   long LastPositionType()
   {
      long     lastType  = -1;
      datetime latest    = 0;
   
      for(int i = 0; i < ArraySize(deals); i++)
      {
         if(deals[i].openTime > latest)
         {
            latest   = deals[i].openTime;
            lastType = deals[i].type;
         }
      }
      return lastType;
   }

   long LastOrderType()
   {
      long lastType = -1;
      datetime latestTime = 0;

      int total = OrdersTotal();
      for (int i = 0; i < total; i++)
      {
         ulong ticket = OrderGetTicket(i);
         if (!OrderSelect(ticket)) continue;
         if (OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
         if ((ulong)OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;

         datetime timePlaced = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
         if (timePlaced > latestTime)
         {
            latestTime = timePlaced;
            lastType = OrderGetInteger(ORDER_TYPE);
         }
      }
      return lastType;
   }

   int CountUnprotected(int typeFilter = -1)
   {
      int cnt = 0;
      for (int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong t = PositionGetTicket(i);
         if (!PositionSelectByTicket(t)) continue;
         if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if ((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

         long   type = PositionGetInteger(POSITION_TYPE);
         double sl   = PositionGetDouble(POSITION_SL);

         if ((typeFilter == -1 || type == typeFilter) && sl <= 0.0)
            ++cnt;
      }
      return cnt;
   }

private:
   // ============================================================
   // ⚙️ Internal close logic (never call directly from outside)
   // ============================================================
   // ------------------------------------------------------------------
   // Ticket-based, partial-aware close with early exit after success
   // ------------------------------------------------------------------
   bool InternalClose(ulong ticket, bool verbose = true)
   {
      // Retry a few times in case of partials/requotes/busy server
      for (int attempt = 0; attempt < 3; ++attempt)
      {
         // If already gone, we're done
         if (!PositionSelectByTicket(ticket))
         {
            if (verbose) PrintFormat("✅ Closed ticket=%I64u", ticket);
            return true;
         }
   
         // Gather current state
         string sym = PositionGetString(POSITION_SYMBOL);
         double vol = PositionGetDouble(POSITION_VOLUME);
         int    typ = (int)PositionGetInteger(POSITION_TYPE);
         ulong  mg  = (ulong)PositionGetInteger(POSITION_MAGIC);
   
         // Build close request for THIS ticket
         MqlTradeRequest req = {};
         MqlTradeResult  res = {};
         req.action       = TRADE_ACTION_DEAL;
         req.symbol       = sym;
         req.position     = ticket;                                  // bind to ticket
         req.volume       = vol;                                     // flatten remaining volume
         req.type         = (typ == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
         req.price        = (typ == POSITION_TYPE_BUY ? SymbolInfoDouble(sym, SYMBOL_BID)
                                                      : SymbolInfoDouble(sym, SYMBOL_ASK));
         req.magic        = mg;
         req.deviation    = 20;
         req.type_filling = gFillMode;                               // IOC is fine, allows partials
         req.type_time    = ORDER_TIME_GTC;
   
         if (OrderSend(req, res))
         {
            if (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_DONE_PARTIAL)
            {
               // ✅ Early verification: is the ticket fully closed now?
               Sleep(20);
               if (!PositionSelectByTicket(ticket)) return true;
               if (PositionGetDouble(POSITION_VOLUME) <= 0.0) return true;
   
               // Partial fill → try again
               if (res.retcode == TRADE_RETCODE_DONE_PARTIAL)
               {
                  Sleep(60);
                  continue;
               }
   
               // Rare: DONE but still volume>0 → give it another shot
               Sleep(80);
               continue;
            }
            else if (res.retcode == TRADE_RETCODE_REQUOTE || res.retcode == TRADE_RETCODE_PRICE_CHANGED)
            {
               Sleep(60);
               continue;
            }
            else if (res.retcode == TRADE_RETCODE_TOO_MANY_REQUESTS)
            {
               Sleep(80);
               continue;
            }
            else
            {
               if (verbose)
                  PrintFormat("❌ ticket=%I64u ret=%d (%s)", ticket, res.retcode, RetcodeToString(res.retcode));
               return false;
            }
         }
         else
         {
            int err = GetLastError();
            if (verbose)
               PrintFormat("⚠️ OrderSend() failed err=%d for ticket=%I64u (attempt %d) — retrying",
                           err, ticket, attempt+1);
            ResetLastError();
            Sleep(120);
         }
      }
   
      // Final check after retries
      if (!PositionSelectByTicket(ticket)) return true;
      if (verbose) PrintFormat("❌ Exhausted retries; ticket=%I64u still open", ticket);
      return false;
   }
   // Fast close: Send one close command and return immediately
   // Returns true if OrderSend succeeded, false otherwise
   // Does NOT wait or verify if position actually closed
   bool FastClose(ulong ticket, bool verbose = true)
   {
      // Quick check if position exists
      if (!PositionSelectByTicket(ticket))
      {
         if (verbose) PrintFormat("592 FastClose: ticket=%I64u already closed", ticket);
         return true;
      }
   
      // Gather current state
      string sym = PositionGetString(POSITION_SYMBOL);
      double vol = PositionGetDouble(POSITION_VOLUME);
      int    typ = (int)PositionGetInteger(POSITION_TYPE);
      ulong  mg  = (ulong)PositionGetInteger(POSITION_MAGIC);
   
      // Build close request
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
   
      // Send close command and return immediately
      if (OrderSend(req, res))
      {
         //AGH
         //if (verbose)
            //PrintFormat("621 FastClose: ticket=%I64u sent, retcode=%d (%s)", 
            //            ticket, res.retcode, RetcodeToString(res.retcode));
         return true;
      }
      else
      {
         int err = GetLastError();
         //AGH
         //if (verbose)
         //   PrintFormat("629 FastClose: ticket=%I64u OrderSend failed, err=%d", ticket, err);
         ResetLastError();
         return false;
      }
   }

};


// Globals
DealManager dm;   // global object
// === AG Panel Globals (minimal, ASCII only) ===
bool AG_PanelVisible = true;
int  AG_PanelX = 20, AG_PanelY = 300;
#define AG_PANEL_BG     "AG_InfoPanelBG"
#define AG_PANEL_TEXT   "AG_InfoPanelText"
#define AG_BTN_TOGGLE   "AG_BtnToggleInfo"
#define AG_BTN_CLOSEALL "AG_BtnCloseAll"

// === ABWCL Epoch-based control ===
int      gArmEpoch            = 0;
int      gABWCLWinnerSide     = -1;   // 0 = POSITION_TYPE_BUY / 1 = POSITION_TYPE_SELL / -1 = none
ulong    gEpochWinnerTickets[];
ulong    gEpochLoserTickets[];
double   gABWCL_SL_winner     =0.0;
double   gABWCL_SL_loser = 0.0;

PosSnap    gEpochToCloseArray[];
PosSnap    gEpochWallToArray[];

// === ABWCL Globals ===
bool     gABWCLArmed = false;   // true when at least one side is protected
double   gABWCLSLbuy = 0.0;     // current wall SL for BUY side
double   gABWCLSLsell = 0.0;     // current wall SL for SELL side


bool     gdebugB01 = false ;
int      gdebugI01 = 0 ;
int      gdebugI02 = 0 ;
int      gdebugI03 = 0 ;
double   gdebugD01 = 0 ;
double   gdebugD02 = 0 ;
double   gdebugD03 = 0 ;
double   gdebugD04 = 0 ;
double   gdebugD05 = 0 ;
string   gdebugS01 ="" ;

CTrade trade;
ENUM_ORDER_TYPE_FILLING gFillMode = ORDER_FILLING_IOC;

double gbuyEntry = 0.0;
double gsellEntry = 0.0;

datetime gLastTxTime = 0;         // last trade-transaction time
datetime gLastPlaceBar = 0;         // bar-id of last placement on tick

// === Newcomer tracking ===
datetime gArmTime = 0;              // time when current epoch was armed
datetime gEpochStartTime = 0;

double gbuyEntry_range = 0;
double gsellEntry_range = 0;
double grange = 0;

string botToken = "8662430168:AAGwgNPnRwdCZpn9wDQKi25S43s0_vaVs4Y";
string chatID = "111902083";
//string channelID = "-1003742587639";
string group_id = "-1003742587639";
//gold-demo
string topic_id = "";

double gMinLot  = 0.0;
double gMaxLot  = 0.0;
double gLotStep = 0.0;
double gTickSize = 0.0;
double gTickValue = 0.0;
double gPoint = 0.0;

// ============================================================
// 4.8 Globals
// ============================================================

// Budget exhaustion flag: when true => no new pending orders allowed
bool gBudgetExhausted = false;
bool gBudgetCheckEMGCY = false;

// Compression flag: when true => compression owns pending logic (cancel/replace)
bool gCompressionActive = false;

// current compression target (computed dynamically)
int  gCompressionKeepTarget = 0;
// POSITION_TYPE_BUY/SELL locked at compression entry
int  gCompressionProtectedSide = -1; 
// first deal side locked at compression entry
int  gFirstNonEpochSideType     = -1; 
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
/*{
    PrintBrokerFillingSupport();
    return INIT_SUCCEEDED;
}
*/
{
   Print("=== OnInit() started ===");
   DetectWorkingFillMode();
   
   ENUM_TIMEFRAMES tf = Timeframe == 0 ? (ENUM_TIMEFRAMES)Period() : Timeframe;
   
   LoadRangeState();
   
   if(InpCandleSourceMode == CANDLE_SOURCE_HA)
   {
      gCandleHandle = iCustom(_Symbol, tf, "Examples\\Heiken_Ashi");
      if(gCandleHandle == INVALID_HANDLE)
      {
         int err = GetLastError();
         PrintFormat("Failed to create Heiken Ashi handle for %s, error=%d", _Symbol, err);
         return INIT_FAILED;
      }
   }
   else
   {
      gCandleHandle = INVALID_HANDLE;
   }

   PrintFormat("Risk mode: %s | Risk value: %.2f | Stop loss mode: %s | SL input: %.1f pips",
               EnumToString(RiskMode),
               RiskValue);

   long filling_mode = 0;
   long trade_mode   = 0;
   long exec_mode    = 0;
   SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE, filling_mode);
   SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE, trade_mode);
   SymbolInfoInteger(_Symbol, SYMBOL_TRADE_EXEMODE, exec_mode);

   double contract_sz = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);

   PrintFormat("Symbol Info for %s:", _Symbol);
   PrintFormat("  • Filling mode   = %d (%s)", (int)filling_mode,
               (filling_mode==ORDER_FILLING_FOK   ? "FOK" :
                filling_mode==ORDER_FILLING_IOC   ? "IOC" :
                filling_mode==ORDER_FILLING_RETURN? "RETURN" : "Unknown"));
   PrintFormat("  • Trade mode     = %d", (int)trade_mode);
   PrintFormat("  • Execution mode = %d (%s)", (int)exec_mode,
               (exec_mode==SYMBOL_TRADE_EXECUTION_REQUEST ? "REQUEST" :
                exec_mode==SYMBOL_TRADE_EXECUTION_INSTANT ? "INSTANT" :
                exec_mode==SYMBOL_TRADE_EXECUTION_MARKET  ? "MARKET" :
                exec_mode==SYMBOL_TRADE_EXECUTION_EXCHANGE? "EXCHANGE" : "Unknown"));
   PrintFormat("  • Contract size  = %.2f", contract_sz);

   if((trade_mode==SYMBOL_TRADE_MODE_DISABLED) || (trade_mode==SYMBOL_TRADE_MODE_CLOSEONLY))
      PrintFormat("⚠️ Trading disabled or close-only on %s. EA will run in observe mode.", _Symbol);
   else
      Print("✅ Trading enabled and ready.");
   
   //SendTelegramMessage("MT5 connected successfully");
   
   SetTelegramRoute();

   if(topic_id == "")
   {
      Print("ERROR: topic_id not set");
      return(INIT_FAILED);
   }

   Print("Telegram Route → Group:", group_id, " Topic:", topic_id);
   
   //SendTelegramMessage("MT5 connected successfully");
   
   SendTelegramMessage(
      __FILE__
      + " Asymmetric:" + DoubleToString(AsymmetricRangeDistanceInPrice, 1)
      + " BB:" + BaseBufferPrice
      + " EMinRF:" + DoubleToString(EntryMinRangeFactor, 1)
      + " EMaxRF:" + DoubleToString(EntryMaxRangeFactor, 1)
   );
                  
   if(ParseBufferMap(BaseBufferPrice) == 0)
   {
      Print("Buffer map parsing failed");
      return INIT_FAILED;
   }  

   ArrayResize(priceWindow, WindowSize);
   ArrayInitialize(priceWindow, 0);
   windowCount = 0;
   resonanceDirection = "NONE";
   
   gMinLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   gMaxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   gLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   gTickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   gTickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   gPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(gTickSize <= 0)
     {
      gTickSize = gPoint;
     }

   if(gTickSize <= 0.0 || gTickValue <= 0.0)
   {
      Print("OnInit: invalid tickSize/tickValue ");
      return INIT_FAILED;
   }
   
   gCommissionPerLot = GetSymbolCommissionPerLot(_Symbol);
   
   gMarginUsedBufferLevel = MarginUsedBufferLevel;
   if(gMarginUsedBufferLevel == 0.0)
   {
      gMarginUsedBufferLevel =
         (AccountInfoDouble(ACCOUNT_BALANCE) - AccountInfoDouble(ACCOUNT_MARGIN)) /
         (LotSizeInput / gMinLot);
   }
   
   MagicNumber = (InMagicNumber == 0 ? BuildMagicNumber(_Symbol, tf) : InMagicNumber);
   
   Print("=== OnInit() completed successfully ===");                           
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(gCandleHandle != INVALID_HANDLE)
   {
      IndicatorRelease(gCandleHandle);
      gCandleHandle = INVALID_HANDLE;
   }

   Print("EA stopped.");
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{   
   if (!UpdateCandleData()) return;
   
   PosLists poslists;
   BuildAllListsSorted(poslists);
   int nAll = ArraySize(poslists.lstAll);
   int nWNSL = ArraySize(poslists.lstWNSL);
   int nAllDeals = ArraySize(poslists.lstAllDeals);
   double totalLot = poslists.totalLot;
   gdebugD05 = totalLot;
   
   //if (nAll ==1 && poslists.lstAll[0].lots != LotSizeInput )
   //{
   //   FastCloseNonEpochFromEndToTarget(poslists, 0);
   //}
   
   double floatingNet = 0.0;

   for(int i = 0; i < nAll; i++)
   {
      floatingNet += poslists.lstAll[i].profit;
      if(gCommissionPerLot > 0.0)
            floatingNet -= gCommissionPerLot * poslists.lstAll[i].lots;
   }
   
   //gdebugD01 = floatingNet;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(windowCount < WindowSize)
   {
      priceWindow[windowCount] = currentPrice;
      windowCount++;
   }
   else
   {
      for(int i = 0; i < WindowSize - 1; i++)
      {
         priceWindow[i] = priceWindow[i + 1];
      }
      priceWindow[WindowSize - 1] = currentPrice;
   }
   
   //AGH
   //if(windowCount == WindowSize)
   //{
   //   CalculateResonance(priceWindow, WindowSize);
   //}
   
   DisplayDebugging();
   
   if(!IsTradingAllowedNow() && nAllDeals == 0) return;
   
   // ===== EVERY TICK: Compression execution =====
   double currentorderlot = 0.0;   
   double currentorderprice = 0.0;   
   ENUM_ORDER_TYPE currentordertype = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
      
         if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
         if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
         
         currentorderprice = OrderGetDouble(ORDER_PRICE_OPEN);
         currentorderlot  = OrderGetDouble(ORDER_VOLUME_CURRENT);
         currentordertype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      }
   double exhaustlottrigger = (LotSizeInput / gMinLot) * ExhaustMaxDealSize;
   if (currentorderlot < exhaustlottrigger) 
      {
      gBudgetCheckEMGCY = false;
      gdebugD01 = currentorderlot;
      gdebugD02 = exhaustlottrigger;
      gdebugD03 = floatingNet;
      gdebugD04 = -1*nWNSL;
      }
      
   if ( currentorderlot >= exhaustlottrigger ) ExhaustBudgetCheckEMGCY(poslists,currentorderprice, currentorderlot, currentordertype, floatingNet);
   if(gCompressionActive)
   {
      ManageCompressionProtect(poslists);  // Every tick if active
      //ManageOpenPendingOrder(poslists);
   }
   if(gBudgetExhausted)
   {
      ManageBudget(poslists);             // Budget entry check
   }
   // ===== ONCE PER BAR: Decision makers =====
   if (IsNewBar())
   {
      // --- ALWAYS run management logic
      ManageArming(poslists);
      ExhaustBudgetCheck(poslists,currentorderprice, currentorderlot, currentordertype);
      EnterCompressionProtect(poslists);
      ManageOpenPendingOrder(poslists);
   }
   // ===== PLACEMENT GATE: ANYTIME (debounced) =====
   //if(!IsTradingAllowedNow()) return;
   nAll = ArraySize(poslists.lstAll);
   if(!IsTradingAllowedNow() && (nAll) == 0) return;
     
   // Reset
   //if(!HasPendingOrder(_Symbol, MagicNumber) && nAllDeals==0)
   //AGH_REV_8_6
   if(nAllDeals==0)
   {
      if (gABWCLArmed || gbuyEntry_range != 0.0 || gsellEntry_range != 0.0 ||
          ArraySize(gEpochWinnerTickets) > 0 || ArraySize(gEpochLoserTickets) > 0)
      {
         ResetABWCLCore(false);
         ResetAnchorAndRange();
         ResetBudgetExhausted();
      }
   }
   
   // Debounce
   const datetime barId = iTime(_Symbol, (Timeframe==0 ? (ENUM_TIMEFRAMES)Period() : Timeframe), 0);
   const bool newBarSinceLastPlacement = (barId != gLastPlaceBar);
   const bool quietAfterTx = (TimeCurrent() - gLastTxTime >= 2);

   if(newBarSinceLastPlacement || quietAfterTx)
   {
      if(!gBudgetExhausted && !HasPendingOrder(_Symbol, MagicNumber))
      {
         PlaceBreakoutOrders(_Symbol, poslists);
         gLastPlaceBar = barId;
      }
   }
}
//+------------------------------------------------------------------+
//| OnTradeTransaction - RESTRUCTURED for IMMEDIATE RESPONSE
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
{
   // === Filter: Only our symbol and magic ===
   const string txn_symbol = (StringLen(trans.symbol) ? trans.symbol : request.symbol);
   if(txn_symbol != _Symbol) return;
   if(request.magic != 0 && request.magic != MagicNumber) return;

   // === Filter: Only execution events ===
   const bool isExecutionEvent =
         (trans.type == TRADE_TRANSACTION_DEAL_ADD    ||
          trans.type == TRADE_TRANSACTION_DEAL_UPDATE ||
          trans.type == TRADE_TRANSACTION_DEAL_DELETE ||
          trans.type == TRADE_TRANSACTION_ORDER_ADD   ||
          trans.type == TRADE_TRANSACTION_ORDER_UPDATE||
          trans.type == TRADE_TRANSACTION_ORDER_DELETE||
          trans.type == TRADE_TRANSACTION_POSITION);

   PosLists poslists;
   BuildAllListsSorted(poslists);
   int nAll = ArraySize(poslists.lstAll);
   int nWSL = ArraySize(poslists.lstWNSL);
   int nAllDeals = ArraySize(poslists.lstAllDeals);
   
   double currentorderlot = 0.0;   
   double currentorderprice = 0.0;   
   ENUM_ORDER_TYPE currentordertype = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
      
         if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
         if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
         
         currentorderprice = OrderGetDouble(ORDER_PRICE_OPEN);
         currentorderlot  = OrderGetDouble(ORDER_VOLUME_CURRENT);
         currentordertype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      }
   
   ManageOpenPendingOrder(poslists);

   // === Setup: Update Candle and refresh deal list ===
   if (!UpdateCandleData()) return;
   

   
   /*if(!gCompressionActive && UseCompressionProtect)
   {
      EnterCompressionProtect(poslists);  // ← Entry can happen any tick
   }*/
   // ============================================================
   // ===== IMMEDIATE ACTIONS: When deal fills (DEAL_ADD) =====
   // ============================================================
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if (nAll > 8 )  
      SendTelegramMessage(
                        "Deal qty : " + IntegerToString(nAll) 
                        + ", MarginUsed: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN),0)
                        + ", Buffer: " + DoubleToString(gdebugD04,0)
                        );
                        
      ExhaustBudgetCheck(poslists,currentorderprice, currentorderlot, currentordertype);
      if(!gCompressionActive && !gABWCLArmed && UseCompressionProtect)
      {
         EnterCompressionProtect(poslists);  // ← Entry can happen any tick
      }
      if(gCompressionActive)
      {
         ManageCompressionProtect(poslists);
      }
      ExhaustBudgetCheck(poslists,currentorderprice, currentorderlot, currentordertype);
      if(gBudgetExhausted)
      {
         ManageBudget(poslists);
      }
      if(gABWCLArmed)
      {
         ManageArming(poslists);
      }
      ManageOpenPendingOrder(poslists);
   }
   
   if(trans.type == TRADE_TRANSACTION_DEAL_DELETE)
   {
      if(gABWCLArmed)
      {
         ManageArming(poslists);
      }
      ManageOpenPendingOrder(poslists);
   }
  
   if(trans.type == TRADE_TRANSACTION_POSITION)
   {
      if(gABWCLArmed)
      {
         ManageArming(poslists);
      }
      ManageOpenPendingOrder(poslists);
   }
   // ============================================================
   // ===== RECORD TIMING: For placement debounce
   // ============================================================
   gLastTxTime = TimeCurrent();
   if(EnableDebugLogs)
      PrintFormat("[OTX-TIME] gLastTxTime updated to %s", TimeToString(gLastTxTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));

}
//+------------------------------------------------------------------+
//| Expert OnChartEvent function                                      |
//+------------------------------------------------------------------+
//void OnChartEvent(const int id,
//                  const long &lparam,
//                  const double &dparam,
//                  const string &sparam)
//{
//   InfoPanel_OnChartEvent(id, lparam, dparam, sparam);
//}
//+------------------------------------------------------------------+
//| Manage Existing Positions: Break-even logic, Trailing stop logic |
//| Handles cycle transitions (IDLE → ACTIVE → REVERSAL → RESET)     |
//+------------------------------------------------------------------+
void ManageArming(PosLists &poslists)
{
   int nWSL = ArraySize(poslists.lstWNSL);   
   int nAll = ArraySize(poslists.lstAll);
   int nAllDeals = ArraySize(poslists.lstAllDeals);
   
   double floatingNet = 0;
   for(int i = 0; i < nAll; i++)
       floatingNet += poslists.lstAll[i].profit;   
   //double floatingNet = AccountInfoDouble(ACCOUNT_EQUITY)
   //                   - AccountInfoDouble(ACCOUNT_BALANCE);
   // ============================================================
   // [MOP-0] Idle maintenance / Reset when unarmed
   // ============================================================
   if(!gABWCLArmed)
   {
      int posCount = dm.Count(-1);
      if(EnableDebugLogs)
         PrintFormat("[MOP-0] Idle → Armed=%d | WinnerSide=%d | netProfit=%.2f | posCount=%d",
                  gABWCLArmed, gABWCLWinnerSide, floatingNet, posCount);

      // 🧹 Reset leftover state if needed
      if(gABWCL_SL_winner != 0.0 || gABWCL_SL_loser != 0.0 || gABWCLWinnerSide != -1 ||
         ArraySize(gEpochWinnerTickets) > 0 || ArraySize(gEpochLoserTickets) > 0)
      {
         gABWCL_SL_winner = 0.0;
         gABWCL_SL_loser = 0.0;
         gABWCLWinnerSide = -1;
         ArrayResize(gEpochWinnerTickets, 0);
         ArrayResize(gEpochLoserTickets, 0);
         if(EnableDebugLogs)Print("[MOP-0.0] Reset to baseline → epoch cleared (idle state).");
      }

      // 💤 Stay idle until profit turns positive
      if(EnableDebugLogs)PrintFormat("[MOP-0.1] Idle waiting → netProfit=%.2f | posCount=%d", floatingNet, posCount);
   }
   if(EnableDebugLogs)PrintFormat("[DBG] Armed=%d | WinSz=%d | LosSz=%d | AllClosed(W)= %d | AllClosed(L)= %d",
               gABWCLArmed,
               ArraySize(gEpochWinnerTickets),
               ArraySize(gEpochLoserTickets),
               AllClosed(gEpochWinnerTickets),
               AllClosed(gEpochLoserTickets));
               
   if(gABWCLArmed)
   {
      // 🧹 Reset leftover state if needed
      if (
         (ArraySize(gEpochWinnerTickets) + ArraySize(gEpochLoserTickets) != nAllDeals - nAll) ||
         (nAllDeals > 2*(nAllDeals - nAll))
         )
      {
         ResetABWCLCore(false);
      }
   }
   // ============================================================
   // [MOP-1] Epoch ended (all tracked positions closed)
   // ============================================================
   if(gABWCLArmed && AllClosed(gEpochWinnerTickets) && AllClosed(gEpochLoserTickets))
   {
      ResetABWCLCore(false);   // epoch ended naturally, DO NOT touch anchor/range
      
      if(EnableDebugLogs)Print("[MOP-1.1] Epoch ended → all tracked positions closed and disarmed.");

      if(nAllDeals > 0)
         if(EnableDebugLogs)Print("[MOP-1.2] New trades detected after epoch closure → waiting for profit to start next epoch.");

      return;
   }
   // ============================================================
   // [MOP-2] Start new epoch (Phase A)
   // ============================================================
   if(!gABWCLArmed &&
      gABWCL_SL_winner == 0.0 &&
      gABWCL_SL_loser == 0.0 &&
      nAllDeals   > 0 &&
      floatingNet      > 0)
   {
      if(EnableDebugLogs)Print("[MOP-2] New Epoch → Phase A triggered (net profit > 0).");
      ArmBreakevenWallCoverLoss_Rev_8_2_2(poslists);
      BuildAllListsSorted(poslists);
      return;
   }
   // ============================================================
   // [MOP-3] Phase A active (winners trailing)
   // ============================================================
   if(gABWCLArmed &&
      gABWCL_SL_winner > 0.0 &&
      gABWCL_SL_loser == 0.0 &&
      !AllClosed(gEpochWinnerTickets))
   {
      double rawRef = (gABWCLWinnerSide == POSITION_TYPE_BUY ? gLowBuf[1] : gHighBuf[1] );
      double ref    = (gABWCLWinnerSide == POSITION_TYPE_BUY)
                      ? MathMax(gABWCL_SL_winner, rawRef)   // BUY: never lower the wall
                      : MathMin(gABWCL_SL_winner, rawRef);  // SELL: never raise the wall
      //AGH_REV_8_5
      gABWCL_SL_winner = ref;
      gABWCL_SL_loser = 0;                
      gArmedSL = ref;
      //AGH_REV_8_5
      if(EnableDebugLogs)PrintFormat("[MOP-3] Phase A Trailing → Side=%s | Ref=%.5f | Epoch=%d",
                  (gABWCLWinnerSide==POSITION_TYPE_BUY?"BUY":"SELL"), ref, gArmEpoch);
      ApplyTrailingForType(gABWCLWinnerSide, ref, poslists);
      
      //AGH_REV_8_5
      if(CanCloseLosersAgainstWinnerWall(ref))
      {
         FastCloseTickets(gEpochLoserTickets, true);
      }
      //AGH_REV_8_5
      
      BuildAllListsSorted(poslists);
      
      return;
   }

   // ============================================================
   // [MOP-4] Transition A → B (winners closed, losers remain)
   // ============================================================
   if(gABWCLArmed &&
      gABWCL_SL_winner > 0.0 &&
      gABWCL_SL_loser == 0.0 &&
      AllClosed(gEpochWinnerTickets) &&
      ArraySize(gEpochLoserTickets) > 0)
   {
      
      double minStop = MinStopDistancePrice(_Symbol);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double LoserSL;
      //AGH_REV_8_6
      ArrayResize(gEpochWinnerTickets, 0);
      //AGH_REV_8_6
      
      if(gABWCLWinnerSide == POSITION_TYPE_BUY) {
         // Losers are SELL → SL must be > ask + minStop
         LoserSL = MathMax(gABWCL_SL_winner + minStop, ask + minStop);
      } else {
         // Losers are BUY → SL must be < bid - minStop
         LoserSL = MathMin(gABWCL_SL_winner - minStop, bid - minStop);
      }
      LoserSL = AlignToTick(_Symbol, LoserSL);
      
      if(EnableDebugLogs)PrintFormat("[MOP-4.0] Transition A→B | PrevWinnerSL=%.5f | minStop=%.5f | NewLoserSL=%.5f | Epoch=%d",
                  gABWCL_SL_winner, minStop, LoserSL, gArmEpoch);

      int prot = ApplyWallToTickets(gEpochLoserTickets, LoserSL);
      BuildAllListsSorted(poslists);
      
      if(prot > 0)
      {
         gABWCL_SL_winner = 0.0;
         gABWCL_SL_loser = LoserSL;
         gArmedSL = LoserSL;
         if(EnableDebugLogs)PrintFormat("[MOP-4.1] Phase B armed → Loser wall %.5f | Protected=%d | Epoch=%d",
                     LoserSL, prot, gArmEpoch);
      }
      else
      {
         if(EnableDebugLogs)Print("[MOP-4.2] No losers protected — awaiting epoch reset on next tick.");
      }
      return;
   }

   // ============================================================
   // [MOP-5] Phase B active (losers trailing)
   // ============================================================
   if(gABWCLArmed &&
      gABWCL_SL_loser > 0.0 &&
      !AllClosed(gEpochLoserTickets))
   {
      int oppType = (gABWCLWinnerSide == POSITION_TYPE_BUY
                     ? POSITION_TYPE_SELL : POSITION_TYPE_BUY);
   
      double rawRef = (oppType == POSITION_TYPE_BUY ? gLowBuf[1] : gHighBuf[1] );
      double ref    = (oppType == POSITION_TYPE_BUY)
                      ? MathMax(gABWCL_SL_loser, rawRef)   // BUY losers: never lower the wall
                      : MathMin(gABWCL_SL_loser, rawRef);  // SELL losers: never raise the wall
      //AGH_REV_8_5
      gABWCL_SL_winner = 0;
      gABWCL_SL_loser = ref;                
      gArmedSL = ref;
      //AGH_REV_8_5

      if(EnableDebugLogs)PrintFormat("[MOP-5] Phase B Trailing → Side=%s | Ref=%.5f | Epoch=%d",
                  (oppType==POSITION_TYPE_BUY?"BUY":"SELL"), ref, gArmEpoch);
                  
      //AGH_REV_8_5, adding new added deal to losers if is positive.
      if(nWSL == 1 && poslists.lstWNSL[0].profit > 0)
      {
         ulong t = poslists.lstWNSL[0].ticket;
      
         int sz2 = ArraySize(gEpochLoserTickets);
         ArrayResize(gEpochLoserTickets, sz2 + 1);
         gEpochLoserTickets[sz2] = t;
      }
      //AGH_REV_8_5
     
      ApplyTrailingForType(oppType, ref, poslists);
      BuildAllListsSorted(poslists);
      return;
   }
}

void ManageBudget(PosLists &poslists)
{
   if(!UseBudgetExhaustion) return;
   if(gABWCLArmed) { ResetBudgetExhausted(); return; }
   
   int nAll = ArraySize(poslists.lstAll);
   
   // Auto-reset if margin freed
   if(nAll < 2)
   {
      ResetBudgetExhausted();
      return;
   }   
   // ===== CHAIN CONTINUATION (event-driven) =====
   if(gBudgetExhausted)
   {
      AddSLToNextOppositeDeal(poslists);
   }
}

void AddSLToNextOppositeDeal(PosLists &poslists)
{
   int n = ArraySize(poslists.lstAll);
   SortByOpenTimeAscending(poslists.lstAll);
   
   //int n = ArraySize(lst);
   ulong  lastTicket = poslists.lstAll[n-1].ticket;
   double lastSL     = poslists.lstAll[n-1].sl;

   // If last already has SL → done
   if(lastSL > 0.0)
      return;

   double refPrice = poslists.lstAll[n-2].openPrice;

   bool ok = UpdateSL(lastTicket, refPrice);
   BuildAllListsSorted(poslists);

   if(EnableDebugLogs)
      PrintFormat("[BUD] EnterBudgetExhausted: canceled=%d last=%I64u SL->%.5f ok=%s",
                  lastTicket, refPrice, ok?"YES":"NO");
}

//+------------------------------------------------------------------+
//| Manage Existing PendingOrder:TP and SL change or Candle indicator-based closures|
//+------------------------------------------------------------------+
void ManageOpenPendingOrder_archived(PosLists &poslists)
{
   // loop through all pending orders of this EA
   int total = OrdersTotal();
   for(int i=total-1; i>=0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;

      // --- manage this order
      long type = OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         ModifyPendingOrder(ticket, poslists);
   }
}
//ManageOpenPendingOrder_REV_8_4
void ManageOpenPendingOrder(PosLists &poslists)
{
   int nWNSL = ArraySize(poslists.lstWNSL);
   SortByOpenTimeAscending(poslists.lstWNSL);
   
   ENUM_ORDER_TYPE expectedType = (ENUM_ORDER_TYPE)-1;

   if(nWNSL > 0)
   {
      int lastSide = poslists.lstWNSL[nWNSL - 1].type;

      if(lastSide == POSITION_TYPE_BUY)
         expectedType = ORDER_TYPE_SELL_STOP;
      else if(lastSide == POSITION_TYPE_SELL)
         expectedType = ORDER_TYPE_BUY_STOP;
   }

   // loop through all pending orders of this EA
   int total = OrdersTotal();

   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;

      long type = OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_STOP && type != ORDER_TYPE_SELL_STOP) continue;

      // If positions exist, pending must be opposite to last WNSL position.
      if(expectedType != (ENUM_ORDER_TYPE)-1 && type != expectedType)
      {
         if(EnableDebugLogs)
         {
            PrintFormat("[MOP] Canceling wrong-side pending ticket=%I64u type=%d expected=%d",
                        ticket,
                        type,
                        expectedType);
         }

         CancelPendingOrder(ticket);
         continue;
      }

      ModifyPendingOrder(ticket, poslists);
   }
}
//+------------------------------------------------------------------+
//| HasPendingOrder                                          |
//+------------------------------------------------------------------+
bool HasPendingOrder(string symbol, ulong magic)
{
   int total = OrdersTotal();  // total active orders
   for(int i = 0; i < total; i++)
   {
      ulong ticket = OrderGetTicket(i);       // get the ticket by index
      if(OrderSelect(ticket))                 // select the order
      {
         long type  = OrderGetInteger(ORDER_TYPE);
         string sym = OrderGetString(ORDER_SYMBOL);
         ulong mg   = (ulong)OrderGetInteger(ORDER_MAGIC);

         // Only consider pending orders
         if((type == ORDER_TYPE_BUY_STOP  || type == ORDER_TYPE_SELL_STOP  ||
             type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT ||
             type == ORDER_TYPE_BUY_STOP_LIMIT || type == ORDER_TYPE_SELL_STOP_LIMIT) &&
             sym == symbol && mg == magic)
         {
            return true;  // pending order found
         }
      }
   }
   return false; // no matching pending orders
}
//+------------------------------------------------------------------+
//| ModifyPendingOrder                                             |
//+------------------------------------------------------------------+
void ModifyPendingOrder(ulong ticket, PosLists &poslists)
{
   if(!SelectPendingOrderByTicket(ticket))
      return;

   string symbol   = OrderGetString(ORDER_SYMBOL);
   long   type     = OrderGetInteger(ORDER_TYPE);
   double oldPrice = OrderGetDouble(ORDER_PRICE_OPEN);
   double oldLot   = OrderGetDouble(ORDER_VOLUME_CURRENT);
   double oldSL    = OrderGetDouble(ORDER_SL);
   double oldTP    = OrderGetDouble(ORDER_TP);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread  = ask - bid;

   int nWNSL = ArraySize(poslists.lstWNSL);
   int nAllDeals = ArraySize(poslists.lstAllDeals);
   
   if(nWNSL > 0)
   {
      int lastSide = poslists.lstWNSL[nWNSL - 1].type;
      type = (lastSide == POSITION_TYPE_BUY ? ORDER_TYPE_SELL_STOP : ORDER_TYPE_BUY_STOP);
   }

   double buyEntry = 0.0, sellEntry = 0.0;
   ComputeEntry(buyEntry, sellEntry, poslists, type);

   double newEntry = (type == ORDER_TYPE_BUY_STOP)
                   ? ClampPendingEntry(symbol, ORDER_TYPE_BUY_STOP, buyEntry)
                   : ClampPendingEntry(symbol, ORDER_TYPE_SELL_STOP, sellEntry);

   newEntry = AlignToTick(symbol, newEntry);

   double newLot = ComputeNextLotSizeINC_EntryAware_Rev_8_2((ENUM_ORDER_TYPE)type, newEntry, poslists);
   // If lot size is zero → nothing to do
   if(newLot <= 0)
      return;
   bool priceDiff = false;
   if(type == ORDER_TYPE_BUY_STOP)
   {
      priceDiff = !NearlyEqualPrice(newEntry, oldPrice, spread) && (newEntry < oldPrice);
   }
   else if(type == ORDER_TYPE_SELL_STOP)
   {
      priceDiff = !NearlyEqualPrice(newEntry, oldPrice, spread) && (newEntry > oldPrice);
   }
   bool lotDiff   = !NearlyEqualVol(newLot, oldLot);

   if(!priceDiff && !lotDiff)
      return;

   if(!lotDiff)
   {
      TradeActionResult modRes = ModifyPendingOrderWithWidening(
         ticket,
         symbol,
         (ENUM_ORDER_TYPE)type,
         newEntry,
         oldSL,
         oldTP,
         widenMaxSteps
      );

      if(!modRes.success && EnableDebugLogs)
      {
         PrintFormat("[MPO] Modify failed retcode=%u lastErr=%d action=%d -> keeping old pending unchanged.",
                     modRes.retcode, modRes.lastError, modRes.action);
      }

      return;
   }

   TradeActionResult placeRes = ModifyPlacePendingOrderWithWidening(
      ticket,
      symbol,
      (ENUM_ORDER_TYPE)type,
      newLot,
      newEntry,
      0.0,
      0.0,
      widenMaxSteps
   );

   if(placeRes.success)
   {
      CancelPendingOrder(ticket);
      return;
   }

   if(EnableDebugLogs)
   {
      PrintFormat("[MPO] Replace failed retcode=%u lastErr=%d action=%d -> keeping old pending alive.",
                  placeRes.retcode, placeRes.lastError, placeRes.action);
   }
}

void ModifyPendingOrder_ONGOING(ulong ticket, PosLists &poslists)
{


   int nWNSL = ArraySize(poslists.lstWNSL);
   int nAllDeals = ArraySize(poslists.lstAllDeals);
   
   int lastSidenAllDeals = (nAllDeals > 0) ? poslists.lstAllDeals[nAllDeals-1].type : -1;
   double lastPricenAllDeals = (nAllDeals > 0) ? poslists.lstAllDeals[nAllDeals-1].openPrice : 0;
   
   int lastSidelstWNSL = (nWNSL> 0) ? poslists.lstWNSL[nWNSL-1].type : -1;
   double lastPricelstWNSL= (nWNSL> 0) ? poslists.lstWNSL[nWNSL-1].openPrice : 0;
      
}
//+------------------------------------------------------------------+
//| SelectOrderByTicket                                               |
//+------------------------------------------------------------------+
bool SelectPendingOrderByTicket(ulong ticket)
{
   if(!OrderSelect(ticket)) return false;  // selects from current (trades) pool
   long t = OrderGetInteger(ORDER_TYPE);
   return (t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT ||
           t == ORDER_TYPE_BUY_STOP  || t == ORDER_TYPE_SELL_STOP);
}
//+------------------------------------------------------------------+
//| CancelPendingOrder                                               |
//+------------------------------------------------------------------+
TradeActionResult CancelPendingOrder(ulong ticket)
{
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};

   req.action = TRADE_ACTION_REMOVE;
   req.order  = ticket;

   ResetLastError();
   ZeroMemory(res);

   bool sent = OrderSend(req, res);

   TradeActionResult out = MakeTradeActionResult(sent, res);
   out.action = ClassifySendFailure(sent, res, out.lastError);

   //AGH-recheck
   //if(out.success)
   //   Print("Pending order canceled: ", ticket);
   //else if(!out.sent)
   //   PrintFormat("Cancel pending order failed (transport): ticket=%I64u lastErr=%d",
   //               ticket, out.lastError);
   //else
   //   PrintFormat("Cancel pending order failed: rc=%u (%s)",
   //               out.retcode, RetcodeToString(out.retcode));

   return out;
}
//+------------------------------------------------------------------+
//| Cancel all pending orders for this EA (symbol + MagicNumber)     |
//| Returns number of canceled orders                                |
//+------------------------------------------------------------------+
int CancelAllPending()
{
   int canceled = 0;

   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if (!OrderSelect(ticket)) continue;

      // Filter: same symbol and same EA
      if (OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if ((ulong)OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;

      // Consider only pending orders
      long type = OrderGetInteger(ORDER_TYPE);
      bool isPending =
         (type == ORDER_TYPE_BUY_LIMIT)      ||
         (type == ORDER_TYPE_SELL_LIMIT)     ||
         (type == ORDER_TYPE_BUY_STOP)       ||
         (type == ORDER_TYPE_SELL_STOP)      ||
         (type == ORDER_TYPE_BUY_STOP_LIMIT) ||
         (type == ORDER_TYPE_SELL_STOP_LIMIT);

      if (!isPending) continue;

      CancelPendingOrder(ticket);
      canceled++;
   }
   //AGH-recheck
   //if (canceled > 0)
   //   PrintFormat("✅ CancelAllPending: %d orders removed.", canceled);
   //else
   //   Print("ℹ️ CancelAllPending: no matching pending orders found.");
   
   return canceled;
}
//+------------------------------------------------------------------+
//| PlaceBreakoutOrders                                              |
//| What it does:                                                    |
//|   • Normal-mode pending placement (one stop order at a time).     |
//|   • Skips placement if:                                           |
//|       - Budget exhausted (gBudgetExhausted)                       |
//|       - Compression active (gCompressionActive)                   |
//|   • Computes anchors via ComputeEntryAnchors()                    |
//|   • Computes lot via ComputeNextLotSizeINC()                      |
//|   • Chooses which stop to place based on your "cases"             |
//|   • Runs BudgetExhaustion check JUST BEFORE sending the order     |
//|   • Places with retry; on repeated failure closes current range   |
//+------------------------------------------------------------------+
void PlaceBreakoutOrders(const string sym, PosLists &poslists)
{   
   bool  hasBuyPosition             = false;
   bool  hasSellPosition            = false;
   
   // --- Broker's minimum stop distance
   double minStopDistPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDistPrice  = minStopDistPoints * _Point;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread  = ask - bid;
   
   int nAll = ArraySize(poslists.lstAll);
   int nWSL = ArraySize(poslists.lstWNSL);
   int nAllDeals = ArraySize(poslists.lstAllDeals);
   
   SortByOpenTimeAscending(poslists.lstAll);
   SortByOpenTimeAscending(poslists.lstWNSL);
   SortByOpenTimeAscending(poslists.lstAllDeals);
   long last_position_type = (nAllDeals > 0) ? poslists.lstAllDeals[nAllDeals-1].type : -1;
   
   // Entry levels rev5.1
   double buyEntry=0.0, sellEntry=0.0;
   ENUM_ORDER_TYPE ptype = -1;
   ComputeEntry(buyEntry, sellEntry, poslists, ptype);  // handles all 3 modes automatically
   
   // --- Validate Buy Stop (must be above Ask + minStopDist)
   if(buyEntry <= ask + minStopDistPrice)
   {
      buyEntry = ask + minStopDistPrice + spread;
      //Print(" BuyEntry adjusted to valid value: ", buyEntry);
   }
      
   // --- Validate Sell Stop (must be below Bid - minStopDist)
   if(sellEntry >= bid - minStopDistPrice)
   {
      sellEntry = bid - minStopDistPrice - spread;
      //Print(" SellEntry adjusted to valid value: ", sellEntry);
   }
   
   //gbuyEntry = buyEntry;
   //gsellEntry = sellEntry;
         
   // Raw Stop losses
   double buySL  = 0;
   double sellSL = 0;
   
   // Distances for TP calculation
   double buyTP  = 0;
   double sellTP = 0;
   
   // Lot calculation
   double lot  = ComputeNextLotSizeINC_Rev8_2(ptype, buyEntry, sellEntry, poslists);
   // If lot size is zero → nothing to do
   if(lot <= 0)
      return;
   // ===========================================================
   // Decide *what* to place (single pending), instead of placing
   // inside each case.
   // ===========================================================
   ENUM_ORDER_TYPE pendingType = (ENUM_ORDER_TYPE)-1;
   double          pendLot     = 0.0;
   double          pendEntry   = 0.0;
   double          pendSL      = 0.0;
   double          pendTP      = 0.0;
   bool            wantOrder   = false;

   // --- CASE 1: No positions & no pending orders & DownTrend → place Buy
   if (nAllDeals == 0 &&
       (IsDownTrend() ))//|| GetHAReversalDirection()==1))
   {
      pendingType = ORDER_TYPE_BUY_STOP;
      pendLot     = lot;
      pendEntry   = buyEntry;
      pendSL      = buySL;
      pendTP      = buyTP;
      wantOrder   = true;
   }

   // --- CASE 2: No positions & no pending orders & UpTrend → place Sell
   else if (nAllDeals == 0 &&
            (IsUpTrend() ))//|| GetHAReversalDirection()==-1))
   {
      pendingType = ORDER_TYPE_SELL_STOP;
      pendLot     = lot;
      pendEntry   = sellEntry;
      pendSL      = sellSL;
      pendTP      = sellTP;
      wantOrder   = true;
   }
   
   // --- CASE 5: Buy&Sell positions & no pending orders & Last Sell → place Buy
   else if (nAllDeals != 0 &&
            last_position_type == POSITION_TYPE_SELL)
   {
      pendingType = ORDER_TYPE_BUY_STOP;
      pendLot     = lot;
      pendEntry   = buyEntry;
      pendSL      = buySL;
      pendTP      = buyTP;
      wantOrder   = true;
   }
   
   // --- CASE 6: Buy&Sell positions & no pending orders & Last Buy → place Sell
   else if (nAllDeals != 0 &&
            last_position_type == POSITION_TYPE_BUY)
   {
      pendingType = ORDER_TYPE_SELL_STOP;
      pendLot     = lot;
      pendEntry   = sellEntry;
      pendSL      = sellSL;
      pendTP      = sellTP;
      wantOrder   = true;
   }

   // If none of the cases triggered → nothing to do
   if(!wantOrder)
      return;
      
   // ===========================================================
   // Centralised placement + retry logic
   // ===========================================================
   TradeActionResult placeRes = PlacePendingOrderWithWidening(
      _Symbol,
      pendingType,
      pendLot,
      pendEntry,
      pendSL,
      pendTP
   );
   
   if(placeRes.success)
      return;
   
   if(placeRes.action == FAIL_FATAL)
   {
      PrintFormat("[PBO] FATAL placement failure rc=%u -> closing current non-epoch range.",
                  placeRes.retcode);
      CloseCurrentRangeNonEpoch();
   }
   else
   {
      PrintFormat("[PBO] Placement failed rc=%u lastErr=%d action=%d -> keep range, retry later.",
                  placeRes.retcode, placeRes.lastError, placeRes.action);
   }
}
//==================================================================
// Generic Pending Order Sender
//==================================================================
TradeActionResult MakeTradeActionResult(bool sent, const MqlTradeResult &res)
{
   TradeActionResult out = {};

   out.sent      = sent;
   out.success   = sent && (res.retcode == TRADE_RETCODE_DONE ||
                            res.retcode == TRADE_RETCODE_PLACED ||
                            res.retcode == TRADE_RETCODE_NO_CHANGES);
   out.retcode   = res.retcode;
   out.lastError = GetLastError();
   out.action    = FAIL_OTHER;

   return out;
}

bool IsTransientTransportError(int err)
{
   return false;
}

SendFailAction ClassifySendFailure(bool sent, const MqlTradeResult &res, int lastErr)
{
   if(res.retcode != 0)
   {
      switch(res.retcode)
      {
         case TRADE_RETCODE_DONE:
         case TRADE_RETCODE_PLACED:
         case TRADE_RETCODE_NO_CHANGES:
            return SEND_OK;

         case TRADE_RETCODE_REQUOTE:
         case TRADE_RETCODE_PRICE_CHANGED:
         case TRADE_RETCODE_TOO_MANY_REQUESTS:
         case TRADE_RETCODE_CONNECTION:
         case TRADE_RETCODE_TIMEOUT:
         case TRADE_RETCODE_LOCKED:
            return RETRY_SAME;

         case TRADE_RETCODE_PRICE_OFF:
         case TRADE_RETCODE_INVALID_PRICE:
         case TRADE_RETCODE_INVALID_STOPS:
         case TRADE_RETCODE_FROZEN:
            return RETRY_WIDEN;

         case TRADE_RETCODE_INVALID:
         case TRADE_RETCODE_INVALID_PARAMS:
         case TRADE_RETCODE_INVALID_FILL:
         case TRADE_RETCODE_INVALID_VOLUME:
         case TRADE_RETCODE_NO_MONEY:
         case TRADE_RETCODE_TRADE_DISABLED:
         case TRADE_RETCODE_MARKET_CLOSED:
         case TRADE_RETCODE_ONLY_REAL:
            return FAIL_FATAL;

         default:
            return FAIL_OTHER;
      }
   }

   if(!sent)
      return FAIL_OTHER;

   return FAIL_OTHER;
}


double WidenPendingEntry_rev71(const string sym, ENUM_ORDER_TYPE type, double entry, int stepCount)
{
   if(stepCount <= 0)
      return AlignToTick(sym, entry);

   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double spread = ask - bid;

   double tick = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0)
      tick = _Point;

   double stops  = MinStopDistancePrice(sym);
   double freeze = (double)SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   double base   = stops + freeze + 2.0 * tick;
   double dist   = base + stepCount * spread * 0.2;

   if(type == ORDER_TYPE_BUY_STOP)
      entry += dist;
   else if(type == ORDER_TYPE_SELL_STOP)
      entry -= dist;

   return AlignToTick(sym, entry);
}

TradeActionResult PlacePendingOrder(
   const string sym,
   ENUM_ORDER_TYPE orderType,
   double lot,
   double price,
   double sl,
   double tp
)
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
   ZeroMemory(res);

   bool sent = OrderSend(req, res);

   TradeActionResult out = MakeTradeActionResult(sent, res);
   out.action = ClassifySendFailure(sent, res, out.lastError);
   return out;
}

TradeActionResult ModifyPendingOrderPrice(
   ulong ticket,
   const string sym,
   double price,
   double sl,
   double tp
)
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
   ZeroMemory(res);

   bool sent = OrderSend(req, res);

   TradeActionResult out = MakeTradeActionResult(sent, res);
   out.action = ClassifySendFailure(sent, res, out.lastError);
   return out;
}

TradeActionResult PlacePendingOrderWithWidening(
   const string sym,
   ENUM_ORDER_TYPE orderType,
   double lot,
   double entry,
   double sl,
   double tp,
   int samePriceMaxRetries = 3,
   int samePriceSleepMs = 50
)
{
   TradeActionResult out = {};

   for(int step = 0; step <= widenMaxSteps; ++step)
   {
      double tryEntry = WidenPendingEntry_rev71(sym, orderType, entry, step);
      int maxAttempts = (step == 0 ? samePriceMaxRetries : 1);

      for(int attempt = 1; attempt <= maxAttempts; ++attempt)
      {
         out = PlacePendingOrder(sym, orderType, lot, tryEntry, sl, tp);

         if(out.success)
            return out;

         if(out.action == RETRY_SAME && attempt < maxAttempts)
         {
            Sleep(samePriceSleepMs * attempt);
            continue;
         }

         break;
      }

      if(out.action == RETRY_WIDEN)
      {
         if(step >= 3 && step < widenMaxSteps)
            Sleep(step == 3 ? 10 : 25);

         continue;
      }

      return out;
   }

   return out;
}

TradeActionResult ModifyPlacePendingOrderWithWidening(
   ulong ticket,
   const string sym,
   ENUM_ORDER_TYPE orderType,
   double lot,
   double entry,
   double sl,
   double tp,
   int samePriceMaxRetries = 3,
   int samePriceSleepMs = 50
)
{
   TradeActionResult out = {};
   out.action = FAIL_OTHER;
   if(!SelectPendingOrderByTicket(ticket))
   {
   out.success = false;
   out.lastError = GetLastError();
   return out;
   }
   double currentEntry = OrderGetDouble(ORDER_PRICE_OPEN);
   for(int step = 0; step <= widenMaxSteps; ++step)
   {
      double tryEntry = WidenPendingEntry_rev71(sym, orderType, entry, step);
      if(orderType == ORDER_TYPE_BUY_STOP  
         && tryEntry >= currentEntry)
      {
         return out;
      }
      if(orderType == ORDER_TYPE_SELL_STOP
         && tryEntry <= currentEntry)
      {
         return out;
      }
      
      int maxAttempts = (step == 0 ? samePriceMaxRetries : 1);
      for(int attempt = 1; attempt <= maxAttempts; ++attempt)
      {
         out = PlacePendingOrder(sym, orderType, lot, tryEntry, sl, tp);

         if(out.success)
            return out;

         if(out.action == RETRY_SAME && attempt < maxAttempts)
         {
            Sleep(samePriceSleepMs * attempt);
            continue;
         }

         break;
      }

      if(out.action == RETRY_WIDEN)
      {
         if(step >= 3 && step < widenMaxSteps)
            Sleep(step == 3 ? 10 : 25);

         continue;
      }

      return out;
   }

   return out;
}

TradeActionResult ModifyPendingOrderWithWidening(
   ulong ticket,
   const string sym,
   ENUM_ORDER_TYPE orderType,
   double entry,
   double sl,
   double tp,
   int samePriceMaxRetries = 3,
   int samePriceSleepMs = 50
)
{
   TradeActionResult out = {};
   out.action = FAIL_OTHER;
   if(!SelectPendingOrderByTicket(ticket))
   {
   out.success = false;
   out.lastError = GetLastError();
   return out;
   }
   double currentEntry = OrderGetDouble(ORDER_PRICE_OPEN);
   for(int step = 0; step <= widenMaxSteps; ++step)
   {
      double tryEntry = WidenPendingEntry_rev71(sym, orderType, entry, step);
      if(orderType == ORDER_TYPE_BUY_STOP  
         && tryEntry >= currentEntry)
      {
         return out;
      }
      if(orderType == ORDER_TYPE_SELL_STOP
         && tryEntry <= currentEntry)
      {
         return out;
      }
      
      int maxAttempts = (step == 0 ? samePriceMaxRetries : 1);
      //PrintFormat("[MPOWW] Widening step=%d old=%.5f widened=%.5f", step, entry, tryEntry);
                        
      for(int attempt = 1; attempt <= maxAttempts; ++attempt)
      {
         out = ModifyPendingOrderPrice(ticket, sym, tryEntry, sl, tp);

         if(out.success)
            return out;

         if(out.action == RETRY_SAME && attempt < maxAttempts)
         {
            Sleep(samePriceSleepMs * attempt);
            continue;
         }

         break;
      }

      if(out.action == RETRY_WIDEN)
      {
         if(step >= 3 && step < widenMaxSteps)
            Sleep(step == 3 ? 10 : 25);

         continue;
      }

      return out;
   }

   return out;
}

TradeActionResult UpdateSLOnce(ulong ticket, double newSL)
{
   TradeActionResult out = {};

   if(!PositionSelectByTicket(ticket))
      return out;

   string symbol = PositionGetString(POSITION_SYMBOL);
   double curTP  = PositionGetDouble(POSITION_TP);
   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};

   req.action   = TRADE_ACTION_SLTP;
   req.position = ticket;
   req.symbol   = symbol;
   req.sl       = NormalizeDouble(newSL, digits);
   req.tp       = curTP;

   ResetLastError();
   ZeroMemory(res);

   bool sent = OrderSend(req, res);

   out = MakeTradeActionResult(sent, res);
   out.action = ClassifySendFailure(sent, res, out.lastError);

   return out;
}

double WidenSL_rev1(ulong ticket, double sl, int step)
{
   if(!PositionSelectByTicket(ticket))
      return 0.0;

   string symbol  = PositionGetString(POSITION_SYMBOL);
   int    posType = (int)PositionGetInteger(POSITION_TYPE);

   double tick = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = _Point;

   double ask    = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(symbol, SYMBOL_BID);
   double spread = ask - bid;

   double stops  = MinStopDistancePrice(symbol);
   double freeze = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   double base   = stops + freeze + 2.0 * tick;
   double dist   = base + step * spread * 0.2;

   if(posType == POSITION_TYPE_BUY)
      sl -= dist;
   else if(posType == POSITION_TYPE_SELL)
      sl += dist;

   return NormalizeDouble(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
}

bool UpdateSLWithWidening(ulong ticket, double requestedSL)
{
   if(!PositionSelectByTicket(ticket))
      return false;

   string symbol = PositionGetString(POSITION_SYMBOL);
   double oldSL  = PositionGetDouble(POSITION_SL);
   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   requestedSL = NormalizeDouble(requestedSL, digits);

   double safeSL   = ValidateStopPrice(ticket, requestedSL);
   double safeNorm = NormalizeDouble(safeSL, digits);
   double oldNorm  = NormalizeDouble(oldSL, digits);

   if(safeNorm <= 0.0)
   {
      if(EnableDebugLogs)
         PrintFormat("[UpdateSL] ticket=%I64u cannot get valid SL for req=%.5f (old=%.5f)",
                     ticket, requestedSL, oldSL);
      return false;
   }

   if(safeNorm == oldNorm)
   {
      if(oldNorm <= 0.0)
         return false;

      if(EnableDebugLogs)
         PrintFormat("[UpdateSL] ticket=%I64u newSL==oldSL=%.5f -> already protected.",
                     ticket, oldNorm);
      return true;
   }

   TradeActionResult res = {};

   for(int attempt = 1; attempt <= 3; ++attempt)
   {
      res = UpdateSLOnce(ticket, safeNorm);

      if(res.success)
         return true;

      if(res.retcode == TRADE_RETCODE_NO_CHANGES)
         return true;

      if(res.action == RETRY_SAME && attempt < 3)
      {
         Sleep(50 * attempt);
         continue;
      }

      break;
   }

   if(res.action != RETRY_WIDEN)
   {
      if(EnableDebugLogs)
      {
         PrintFormat("[UpdateSL] FAILED ticket=%I64u rc=%u lastErr=%d action=%d sl=%.5f",
                     ticket, res.retcode, res.lastError, res.action, safeNorm);
      }
      return false;
   }

   for(int step = 1; step <= widenMaxSteps; ++step)
   {
      double widenedSL = WidenSL_rev1(ticket, requestedSL, step);
      if(widenedSL <= 0.0)
         break;

      res = UpdateSLOnce(ticket, widenedSL);

      if(res.success || res.retcode == TRADE_RETCODE_NO_CHANGES)
      {
         if(EnableDebugLogs)
         {
            PrintFormat("[UpdateSL] Widened SL succeeded step=%d sl=%.5f",
                        step, widenedSL);
         }
         return true;
      }

      if(res.action != RETRY_WIDEN)
         break;

      if(step >= 3 && step < widenMaxSteps)
         Sleep(step == 3 ? 10 : 25);
   }

   if(EnableDebugLogs)
   {
      PrintFormat("[UpdateSL] FINAL FAIL ticket=%I64u rc=%u lastErr=%d action=%d",
                  ticket, res.retcode, res.lastError, res.action);
   }

   return false;
}







// Utility: Update SL rev7.1
bool UpdateSL(ulong ticket, double newSL)
{
   if(!PositionSelectByTicket(ticket))
      return false;

   string symbol = PositionGetString(POSITION_SYMBOL);
   double oldSL  = PositionGetDouble(POSITION_SL);
   double curTP  = PositionGetDouble(POSITION_TP);
   int    posType= (int)PositionGetInteger(POSITION_TYPE);
   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   newSL = NormalizeDouble(newSL, digits);

   double safeSL = ValidateStopPrice(ticket, newSL);
   double safeNorm = NormalizeDouble(safeSL, digits);
   double oldNorm  = NormalizeDouble(oldSL, digits);

   if(safeNorm <= 0.0)
   {
      if(EnableDebugLogs)
         PrintFormat("[UpdateSL] ticket=%I64u cannot get valid SL for req=%.5f (old=%.5f)",
                     ticket, newSL, oldSL);
      return false;
   }

   if(safeNorm == oldNorm)
   {
      if(oldNorm <= 0.0)
         return false;

      if(EnableDebugLogs)
         PrintFormat("[UpdateSL] ticket=%I64u newSL==oldSL=%.5f -> already protected.",
                     ticket, oldNorm);
      return true;
   }

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};

   req.action   = TRADE_ACTION_SLTP;
   req.position = ticket;
   req.symbol   = symbol;
   req.sl       = safeNorm;
   req.tp       = curTP;

   double bid     = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask     = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double minStop = MinStopDistancePrice(symbol);
   double entry   = PositionGetDouble(POSITION_PRICE_OPEN);

   if(EnableDebugLogs)
   {
      PrintFormat("[DEBUG-SL] ticket=%I64u | type=%s | entry=%.5f | bid=%.5f | ask=%.5f | oldSL=%.5f | reqSL=%.5f | safeSL=%.5f | minStop=%.5f",
                  ticket,
                  (posType == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                  entry, bid, ask, oldSL, newSL, safeNorm, minStop);
   }

   ResetLastError();
   ZeroMemory(res);

   bool sent = OrderSend(req, res);
   int lastErr = GetLastError();

   if(!sent)
   {
      if(EnableDebugLogs)
         PrintFormat("[UpdateSL] SEND FAILED ticket=%I64u newSL=%.5f lastErr=%d",
                     ticket, safeNorm, lastErr);
      return false;
   }

   if(res.retcode == TRADE_RETCODE_NO_CHANGES)
   {
      if(EnableDebugLogs)
         PrintFormat("[UpdateSL] ticket=%I64u ret=NO_CHANGES -> treat as success", ticket);
      return true;
   }

   if(res.retcode != TRADE_RETCODE_DONE)
   {
      if(EnableDebugLogs)
         PrintFormat("[UpdateSL] MODIFY FAILED ticket=%I64u retcode=%u (%s) newSL=%.5f",
                     ticket, res.retcode, RetcodeToString((int)res.retcode), safeNorm);
      return false;
   }

   return true;
}
//+------------------------------------------------------------------+
//| Risk-based lot size calculation                                  |
//+------------------------------------------------------------------+
double CalculateLotSizeOrder(string symbol, double stop_loss_price)
{
   double balance       = AccountInfoDouble(ACCOUNT_BALANCE);
   double tick_value    = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size     = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point         = SymbolInfoDouble(symbol, SYMBOL_POINT);

   if (tick_value == 0 || tick_size == 0 || stop_loss_price <= 0)
      return 0;

   double risk_amount;
   if (RiskMode == RISK_PERCENT)
      risk_amount = balance * (RiskPercent / 100.0);
   else
      risk_amount = RiskValue;

   double pip_value_per_lot = (tick_value / tick_size) * point;
   double lot = risk_amount / (stop_loss_price * pip_value_per_lot);

   double min_lot = gMinLot;
   double step    = gLotStep;
   lot = MathFloor(lot / step) * step;
   return MathMax(lot, min_lot);
}
//+------------------------------------------------------------------+
//| Log trade to terminal (extendable to file)                       |
//+------------------------------------------------------------------+
void LogTrade(double lot, double sl, double tp)
{
   if(EnableDebugLogs)Print("Trade Log: Lot=", lot,
         " SL=", DoubleToString(sl, _Digits),
         " TP=", DoubleToString(tp, _Digits),
         " Time=", TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));
}
//+------------------------------------------------------------------+
//| Detect new bar for timeframe                                     |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBarTime = 0;
   ENUM_TIMEFRAMES tf = Timeframe == 0 ? (ENUM_TIMEFRAMES)Period() : Timeframe;

   datetime currentBarTime = iTime(_Symbol, tf, 0);
   if (currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}
//+------------------------------------------------------------------+
//| Update Heikin Ashi values (call once per tick)                   |
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

      if(c0 == barsToCopy &&
         c1 == barsToCopy &&
         c2 == barsToCopy &&
         c3 == barsToCopy)
      {
         ArraySetAsSeries(gOpenBuf,  true);
         ArraySetAsSeries(gHighBuf,  true);
         ArraySetAsSeries(gLowBuf,   true);
         ArraySetAsSeries(gCloseBuf, true);
         return true;
      }

      PrintFormat("Failed to update Candle buffers: need=%d got open=%d high=%d low=%d close=%d err=%d",
                  barsToCopy, c0, c1, c2, c3, GetLastError());

      return false;
   }
   else
   {
      int c0 = CopyOpen(_Symbol, PERIOD_CURRENT, 0, barsToCopy, gOpenBuf);
      int c1 = CopyHigh(_Symbol, PERIOD_CURRENT, 0, barsToCopy, gHighBuf);
      int c2 = CopyLow(_Symbol, PERIOD_CURRENT, 0, barsToCopy, gLowBuf);
      int c3 = CopyClose(_Symbol, PERIOD_CURRENT, 0, barsToCopy, gCloseBuf);

      if(c0 == barsToCopy &&
         c1 == barsToCopy &&
         c2 == barsToCopy &&
         c3 == barsToCopy)
      {
         ArraySetAsSeries(gOpenBuf,  true);
         ArraySetAsSeries(gHighBuf,  true);
         ArraySetAsSeries(gLowBuf,   true);
         ArraySetAsSeries(gCloseBuf, true);
         return true;
      }

      PrintFormat("Failed to update regular candle data: need=%d got open=%d high=%d low=%d close=%d err=%d",
                  barsToCopy, c0, c1, c2, c3, GetLastError());

      return false;
   }
}


//+------------------------------------------------------------------+
//| Time Management                                                |
//+------------------------------------------------------------------+
//--- get broker offset in hours automatically
int GetBrokerGMTOffset()
{
   datetime broker = TimeCurrent();   // broker server time
   datetime utc    = TimeGMT();       // UTC time
   int offsetSec   = (int)(broker - utc);
   return offsetSec / 3600;           // convert to hours
}

//--- convert broker time to UTC
datetime GetUTCTime_old()
{
   datetime broker = TimeCurrent();
   int offsetHrs   = GetBrokerGMTOffset();
   return broker - offsetHrs * 3600;
}

datetime GetUTCTime()
{
   return TimeGMT();
}

datetime MakeTime(int y,int m,int d,int h,int mi,int s)
{
   MqlDateTime dt;
   dt.year=y; dt.mon=m; dt.day=d;
   dt.hour=h; dt.min=mi; dt.sec=s;
   return StructToTime(dt);
}

bool IsUKDST(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);

   int year = dt.year;

   // Last Sunday of March
   datetime marchLast = MakeTime(year, 3, 31, 1, 0, 0);
   TimeToStruct(marchLast, dt);
   int marchSunday = 31 - dt.day_of_week;

   // Last Sunday of October
   datetime octLast = MakeTime(year, 10, 31, 1, 0, 0);
   TimeToStruct(octLast, dt);
   int octSunday = 31 - dt.day_of_week;

   datetime start = MakeTime(year, 3, marchSunday, 1, 0, 0);
   datetime end   = MakeTime(year, 10, octSunday, 1, 0, 0);

   return (t >= start && t < end);
}

bool IsUSDST(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);

   int year = dt.year;

   // Second Sunday March
   datetime march1 = MakeTime(year, 3, 1, 2, 0, 0);
   TimeToStruct(march1, dt);
   int firstSunday = (7 - dt.day_of_week) % 7 + 1;
   int secondSunday = firstSunday + 7;

   // First Sunday November
   datetime nov1 = MakeTime(year, 11, 1, 2, 0, 0);
   TimeToStruct(nov1, dt);
   int novSunday = (7 - dt.day_of_week) % 7 + 1;

   datetime start = MakeTime(year, 3, secondSunday, 2, 0, 0);
   datetime end   = MakeTime(year, 11, novSunday, 2, 0, 0);

   return (t >= start && t < end);
}

bool IsLondonForexOpen()
{
   datetime utc = TimeGMT();
   int hour = GetHour(utc);

   if(IsUKDST(utc))
      return (hour >= 7 && hour < 16); // summer
   else
      return (hour >= 8 && hour < 17); // winter
}

bool IsNewYorkForexOpen()
{
   datetime utc = TimeGMT();
   int hour = GetHour(utc);

   if(IsUSDST(utc))
      return (hour >= 12 && hour < 21); // summer
   else
      return (hour >= 13 && hour < 22); // winter
}

bool IsLondonStockOpen()
{
   datetime utc = TimeGMT();
   int h = GetHour(utc);
   int m = GetMinute(utc);
   int now = h * 60 + m;

   if(IsUKDST(utc))
      return (now >= 7 * 60 && now < 15 * 60 + 30);   // 07:00-15:30 UTC
   else
      return (now >= 8 * 60 && now < 16 * 60 + 30);   // 08:00-16:30 UTC
}

bool IsNewYorkStockOpen()
{
   datetime utc = TimeGMT();
   int h = GetHour(utc);
   int m = GetMinute(utc);
   int now = h * 60 + m;

   if(IsUSDST(utc))
      return (now >= 13 * 60 + 30 && now < 20 * 60);  // 13:30-20:00 UTC
   else
      return (now >= 14 * 60 + 30 && now < 21 * 60);  // 14:30-21:00 UTC
}

bool IsAsiaOpen()
{
   int hour = GetHour(TimeGMT());
   return (hour >= 0 && hour < 6);
}

//--- helper: check if current UTC time is inside HH:MM-HH:MM window
bool IsInTimeWindow_old(string window)
{
   if (StringLen(window) < 11) return false;

   string startStr = StringSubstr(window, 0, 5);   // "HH:MM"
   string endStr   = StringSubstr(window, 6);      // "HH:MM"

   int startHour = (int)StringToInteger(StringSubstr(startStr,0,2));
   int startMin  = (int)StringToInteger(StringSubstr(startStr,3,2));
   int endHour   = (int)StringToInteger(StringSubstr(endStr,0,2));
   int endMin    = (int)StringToInteger(StringSubstr(endStr,3,2));

   datetime utcNow = GetUTCTime();
   int nowMin = GetHour(utcNow) * 60 + GetMinute(utcNow);
   int start  = startHour * 60 + startMin;
   int end    = endHour   * 60 + endMin;

   if (end < start)   // overnight session (e.g., 22:00-02:00)
      return (nowMin >= start || nowMin < end);
   else
      return (nowMin >= start && nowMin < end);
}

bool IsInTimeWindow(string window)
{
   if(StringLen(window) != 11) return false;
   if(StringGetCharacter(window, 5) != '-') return false;

   int sh = (int)StringToInteger(StringSubstr(window, 0, 2));
   int sm = (int)StringToInteger(StringSubstr(window, 3, 2));
   int eh = (int)StringToInteger(StringSubstr(window, 6, 2));
   int em = (int)StringToInteger(StringSubstr(window, 9, 2));

   // validation
   if(sh < 0 || sh > 23 || sm < 0 || sm > 59) return false;
   if(eh < 0 || eh > 23 || em < 0 || em > 59) return false;

   int now = GetHour(GetUTCTime()) * 60 + GetMinute(GetUTCTime());
   int start = sh * 60 + sm;
   int end   = eh * 60 + em;

   if(end < start)
      return (now >= start || now < end);

   return (now >= start && now < end);
}

//--- master filter
bool IsTradingAllowedNow()
{
   if (!UseTimeFilter) return true;

   bool allow = false;

   if (EnableLondon)  allow |= IsLondonStockOpen();
   if (EnableNewYork) allow |= IsNewYorkStockOpen();
   if (EnableAsia)    allow |= IsAsiaOpen();

   if (StringLen(ExtraWindow1) > 0) allow |= IsInTimeWindow(ExtraWindow1);
   if (StringLen(ExtraWindow2) > 0) allow |= IsInTimeWindow(ExtraWindow2);

   return allow;
}

//--- convert datetime → hour/minute
int GetHour(datetime t)
{
   MqlDateTime st;
   TimeToStruct(t, st);
   return st.hour;
}

int GetMinute(datetime t)
{
   MqlDateTime st;
   TimeToStruct(t, st);
   return st.min;
}
// ==========================================================
// Detect Heikin Ashi reversal
// ==========================================================
bool IsHAColorReversal()
{
   // Previous Candle candle color (1 = previous bar, 0 = current bar)
   int prevColor = GetCandleColor(1);
   int currColor = GetCandleColor(0);

   // Reversal = color flipped
   if(currColor != prevColor && currColor != 0 && prevColor != 0)
      return true;

   return false;
}
// ==========================================================
// Apply trailing stop to all open positions when net profit > 0
// ==========================================================
void ApplyTrailingForType(int type, double refLevel, PosLists &poslists)
{
   double minStopDistPrice = MinStopDistancePrice(_Symbol);

   bool anyFailed    = false;
   double refNorm    = NormalizeDouble(refLevel, _Digits);

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetInteger(POSITION_TYPE) != type) continue;
      if(!IsEpochTicket(ticket)) continue;
      
      double oldSL   = PositionGetDouble(POSITION_SL);
      double oldNorm = NormalizeDouble(oldSL, _Digits);

      // Requested == old → nothing to do, and NOT a failure
      if(refNorm == oldNorm)
      {
         if(EnableDebugLogs) PrintFormat(
            "[ApplyTrailingForType] ticket=%I64u type=%s requestedSL=%.5f == oldSL=%.5f → no-op",
            ticket,
            (type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
            refLevel, oldSL
         );
         continue;
      }

      if(EnableDebugLogs) PrintFormat(
         "[ApplyTrailingForType] ticket=%I64u type=%s trying trailSL=%.5f (old=%.5f)",
         ticket,
         (type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
         refLevel, oldSL
      );

      bool success = UpdateSL(ticket, refLevel);

      if(!success)
      {
         if(EnableDebugLogs)PrintFormat(
            "[ApplyTrailingForType] trailing SL rejected for ticket=%I64u at %.5f → mark failure",
            ticket, refLevel
         );
         anyFailed = true;
      }
   }

   // 04.6 semantics: ANY failure in trailing → close the whole epoch
   if(anyFailed)
   {
      if(EnableDebugLogs)Print(
         "[ApplyTrailingForType] at least one epoch position refused trailing SL → CloseAllEpochPositions()"
      );
      CloseAllEpochPositions();    // your existing function; no direct position closes here

      // Do NOT try to update gABWCLSLbuy/sell here; epoch is being killed.
      return;
   }

   // after the for-loop, reselect one position of that type before reading SL
   for(int i=PositionsTotal()-1;i>=0;--i){
      ulong t=PositionGetTicket(i);
      if(PositionSelectByTicket(t) && PositionGetInteger(POSITION_TYPE)==type
         && PositionGetString(POSITION_SYMBOL)==_Symbol
         && (ulong)PositionGetInteger(POSITION_MAGIC)==MagicNumber){
         if(!IsEpochTicket(t)) continue;
         if(type==POSITION_TYPE_BUY)  
            gABWCLSLbuy  = PositionGetDouble(POSITION_SL);
         else                         
            gABWCLSLsell = PositionGetDouble(POSITION_SL);
         break;
      }
   }
}

// ==========================================================
// Returns Candle candle color for given bar index
// index = 0 → current forming bar
// index = 1 → previous closed bar, etc.
// ==========================================================
bool IsUpTrend()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (gHighBuf[1] < bid);  // price above last Candle high
}

bool IsDownTrend()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (gLowBuf[1] > ask);   // price below last Candle low
}

// Visual Candle reversal
int GetHAReversalDirection()
{
   int twoprevColor = GetCandleColor(2);
   int prevColor = GetCandleColor(1);
   int currColor = GetCandleColor(0);

   if((currColor != prevColor && currColor != 0 && prevColor != 0)||(currColor != twoprevColor && currColor != 0 && twoprevColor != 0))
      return currColor; // +1 bullish, -1 bearish
   return 0;
}

int GetCandleColor(int index)
{
    if(index < 0 || index >= ArraySize(gOpenBuf) || index >= ArraySize(gCloseBuf))
        return 0; // invalid index

    double candleOpen  = gOpenBuf[index];  // your Candle open array
    double candleClose = gCloseBuf[index]; // your Candle close array

    if(candleClose > candleOpen)
        return +1;  // green candle
    else if(candleClose < candleOpen)
        return -1; // red candle
    else
        return 0;  // doji / neutral
}
//+------------------------------------------------------------------+
//| Convert trade retcode to human-readable text                     |
//+------------------------------------------------------------------+
string RetcodeToString(int code)
{
   switch(code)
   {
      case TRADE_RETCODE_REQUOTE:           return "Requote";
      case TRADE_RETCODE_REJECT:            return "Request rejected";
      case TRADE_RETCODE_CANCEL:            return "Request canceled by trader";
      case TRADE_RETCODE_PLACED:            return "Order placed";
      case TRADE_RETCODE_DONE:              return "Request completed";
      case TRADE_RETCODE_DONE_PARTIAL:      return "Partially completed";
      case TRADE_RETCODE_ERROR:             return "Request processing error";
      case TRADE_RETCODE_TIMEOUT:           return "Request canceled by timeout";
      case TRADE_RETCODE_INVALID:           return "Invalid request";
      case TRADE_RETCODE_INVALID_VOLUME:    return "Invalid volume";
      case TRADE_RETCODE_INVALID_PRICE:     return "Invalid price";
      case TRADE_RETCODE_INVALID_STOPS:     return "Invalid stops";
      case TRADE_RETCODE_TRADE_DISABLED:    return "Trading disabled";
      case TRADE_RETCODE_MARKET_CLOSED:     return "Market closed";
      case TRADE_RETCODE_NO_MONEY:          return "Not enough money";
      case TRADE_RETCODE_PRICE_CHANGED:     return "Prices changed";
      case TRADE_RETCODE_PRICE_OFF:         return "No quotes";
      case TRADE_RETCODE_INVALID_EXPIRATION:return "Invalid expiration";
      case TRADE_RETCODE_ORDER_CHANGED:     return "Order changed";
      case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Too frequent requests";
      case TRADE_RETCODE_NO_CHANGES:        return "No changes in request";
      case TRADE_RETCODE_LOCKED:            return "Request locked for processing";
      case TRADE_RETCODE_FROZEN:            return "Order or position frozen";
      case TRADE_RETCODE_INVALID_FILL:      return "Invalid order filling type";
      case TRADE_RETCODE_CONNECTION:        return "No connection with trade server";
      case TRADE_RETCODE_ONLY_REAL:         return "Operation allowed only on live accounts";
      // add more TRADE_RETCODE_* cases if you need them
      default: return "Unknown retcode";
   }
}
//+------------------------------------------------------------------+
//| Display debugging values from global arrays                            |
//+------------------------------------------------------------------+
void DisplayDebugging(int shift=1)  // default: previous closed candle
{
   datetime utcNow = GetUTCTime();
   double minStopDistPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double freeze = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double point = _Point;
   int    digits = _Digits;
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   int   positions_buy_count        = dm.Count(POSITION_TYPE_BUY);
   int   positions_sell_count       = dm.Count(POSITION_TYPE_SELL);
   double buyProfit  = NormalizeDouble(dm.NetProfit(POSITION_TYPE_BUY), 2);
   double sellProfit = NormalizeDouble(dm.NetProfit(POSITION_TYPE_SELL), 2);
   double netProfit = dm.NetProfit();
   double floatingNet = AccountInfoDouble(ACCOUNT_EQUITY) - AccountInfoDouble(ACCOUNT_BALANCE);
   
   //if(gCandleHandle > 0)
   //{
      string txt;
/*
      txt = "Heiken Ashi Values\n";

      // Current forming bar (updates each tick)
      txt += "TWOPREVIOUS (index 0, 2 last closed):\n";
      txt += "  O:" + DoubleToString(gOpenBuf[2], _Digits) +
             " H:" + DoubleToString(gHighBuf[2], _Digits) +
             " L:" + DoubleToString(gLowBuf[2], _Digits) +
             " C:" + DoubleToString(gCloseBuf[2], _Digits) + "\n\n";
*/
      // Previous closed bar (stable until new bar forms)
      txt += TimeToString(utcNow, TIME_DATE | TIME_SECONDS) + " " + _Symbol + ":\n";
/*      txt += "  O:" + DoubleToString(gOpenBuf[1], _Digits) +
             " H:" + DoubleToString(gHighBuf[1], _Digits) +
             " L:" + DoubleToString(gLowBuf[1], _Digits) +
             " C:" + DoubleToString(gCloseBuf[1], _Digits) + "\n\n";

      // twoPrevious forming bar (updates each tick)
      txt += "CURRENT (index 0, forming):\n";
      txt += "  O:" + DoubleToString(gOpenBuf[0], _Digits) +
             " H:" + DoubleToString(gHighBuf[0], _Digits) +
             " L:" + DoubleToString(gLowBuf[0], _Digits) +
             " C:" + DoubleToString(gCloseBuf[0], _Digits) + "\n\n";
*/       
      // minStopDistPoints (updates each tick)
      txt += "minStopDistPoints:";
      txt += DoubleToString(minStopDistPoints, _Digits);
      txt += " freeze:";
      txt += DoubleToString(freeze, _Digits); 
      txt += " point:";
      txt += DoubleToString(point, _Digits);
      txt += " digits:";
      txt += DoubleToString(digits, _Digits);
      txt += " tick size:";
      txt += DoubleToString(tick_size, _Digits);
      txt += " tick Value:";
      txt += DoubleToString(tick_value, _Digits);
      txt += " MinLot:";
      txt += DoubleToString(gMinLot, _Digits);
      txt += " commission:";
      txt += DoubleToString(gCommissionPerLot, 2) + "\n\n";
            // =====================================================
      // 🧩 Add ABWCL display section
      // =====================================================
      // --- ABWCL Info (display shared SLs)
      txt += "ABWCL Status:\n";
      txt += StringFormat("  gABWCL_SL_winner : %.5f\n", gABWCL_SL_winner);
      txt += StringFormat("  gABWCL_SL_loser : %.5f\n", gABWCL_SL_loser);
      txt += StringFormat("  gArmedSL : %.5f\n\n", gArmedSL);

      txt += StringFormat("  Epoch: %d | WinnerSide: %s\n",
                  gArmEpoch,
                  (gABWCLWinnerSide==POSITION_TYPE_BUY?"BUY":
                   gABWCLWinnerSide==POSITION_TYPE_SELL?"SELL":"NONE"));
      txt += StringFormat("  WinnerTickets=%d  LoserTickets=%d\n",
                  ArraySize(gEpochWinnerTickets), ArraySize(gEpochLoserTickets));
      txt += StringFormat("  buy#=%d  sell#=%d\n",
                  positions_buy_count, positions_sell_count);
      txt += StringFormat("  buyProfit#=%.2f  sellProfit#=%.2f netProfit#=%.2f floatingNet#=%.2f\n",
                          buyProfit, sellProfit, netProfit, floatingNet);
      txt += StringFormat("  gABWCLArmed: %s\n", (gABWCLArmed ? "YES" : "NO"));
      txt += StringFormat("  gCompressionActive: %s\n", (gCompressionActive ? "YES" : "NO"));
      txt += StringFormat("  gCompressionKeepTarget: %d\n", (gCompressionKeepTarget));
      txt += StringFormat("  gBudgetExhausted: %s\n", (gBudgetExhausted ? "YES" : "NO"));
      txt += StringFormat("  gBudgetCheckEMGCY: %s\n", (gBudgetCheckEMGCY ? "YES" : "NO"));
      
      txt += StringFormat("  gbuyEntry_range=%.2f  gsellEntry_range=%.2f",
                     gbuyEntry_range, gsellEntry_range);              
                      
      txt += "\n====================\n";             
            // --- DEBUG
      txt += "DEBUGGING:\n";
      gdebugB01 = gBudgetCheckEMGCY;
      
      txt += StringFormat(
          "DEBUGGING:\n"
          "gdebugB01 (bool)   : %s\n"
          "gdebugI01 (int)    : %d\n"
          "gdebugI02 (int)    : %d\n"
          "gdebugI03 (int)    : %d\n"
          "gdebugD01 (double) : %.5f\n"
          "gdebugD02 (double) : %.5f\n"
          "gdebugD03 (double) : %.5f\n"
          "gdebugD04 (double) : %.5f\n"
          "gdebugD05 (double) : %.5f\n"
          "gdebugS01 (string) : %s\n"
          "gbuyEntry        : %.5f\n"
          "gsellEntry       : %.5f\n",
          gdebugB01 ? "true" : "false",
          gdebugI01,
          gdebugI02,
          gdebugI03,
          gdebugD01,
          gdebugD02,
          gdebugD03,
          gdebugD04,
          gdebugD05,
          gdebugS01,
          gbuyEntry,
          gsellEntry
      );
      
      txt += "\n";
      txt += "\n";
      txt += "\n";
      txt += StringFormat("  resonanceScore=%.2f\n",resonanceScore);
      txt += StringFormat("  resonanceRange=%.2f\n",resonanceRange);
      txt += "  resonanceDirection=" + resonanceDirection + "\n";
                
      Comment(txt);
   //}
   //else
   //{
   //   Comment("Heiken Ashi not ready yet...");
   //}
}

void PrintBrokerFillingSupport()
{
   long modes = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   PrintFormat("SYMBOL_FILLING_MODE = %d", modes);

   MqlTradeCheckResult check;
   MqlTradeRequest req;
   ZeroMemory(req);
   ZeroMemory(check);

   ENUM_ORDER_TYPE_FILLING fills[3] = {ORDER_FILLING_FOK, ORDER_FILLING_IOC, ORDER_FILLING_RETURN};
   string names[3] = {"FOK", "IOC", "RETURN"};

   for(int i=0; i<3; i++)
   {
      ZeroMemory(req);
      req.action   = TRADE_ACTION_DEAL;
      req.symbol   = _Symbol;
      req.type     = ORDER_TYPE_BUY;
      req.volume   = 0.01;
      req.price    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.deviation = 10;
      req.type_filling = fills[i];

      bool ok = OrderCheck(req, check);
      PrintFormat("Check %s: ok=%d retcode=%d (%s)", names[i], ok, check.retcode, check.comment);
   }
}

void DetectWorkingFillMode()
{
   ENUM_ORDER_TYPE_FILLING modes[3] = {ORDER_FILLING_IOC, ORDER_FILLING_RETURN, ORDER_FILLING_FOK};
   string names[3] = {"IOC", "RETURN", "FOK"};
   MqlTradeCheckResult check;
   MqlTradeRequest req;

   for(int i=0; i<3; i++)
   {
      ZeroMemory(req);
      ZeroMemory(check);
      req.action   = TRADE_ACTION_DEAL;
      req.symbol   = _Symbol;
      req.type     = ORDER_TYPE_BUY;
      req.volume   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      req.price    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.deviation= 10;
      req.type_filling = modes[i];

      if(OrderCheck(req, check) && check.retcode == TRADE_RETCODE_DONE)
      {
         gFillMode = modes[i];
         PrintFormat("✅ Working fill mode detected for %s: %s", _Symbol, names[i]);
         return;
      }
   }
   gFillMode = ORDER_FILLING_IOC; // fallback
   PrintFormat("⚠️ No valid fill mode detected, using IOC fallback for %s", _Symbol);
}

double AlignToTick(const string sym, double price)
{
   double tick = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0) tick = _Point;
   // snap to nearest tick
   price = MathRound(price / tick) * tick;
   return NormalizeDouble(price, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
}

double MinStopDistancePrice(const string sym)
{
   double pts = (double)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   if(pts < 0) pts = 0;
   return pts * SymbolInfoDouble(sym, SYMBOL_POINT);
}

double MinPendingDistancePrice(const string sym)
{
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);

   double stops  = (double)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   double freeze = (double)SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL);

   if(stops  < 0) stops  = 0;
   if(freeze < 0) freeze = 0;

   // safety pad: +1 tick
   double tick = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0) tick = pt;

   return (stops + freeze) * pt + tick;
}

double ClampPendingEntry(const string sym, long orderType, double desired) //Version 5.1
{
   const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   const double minDist = MinPendingDistancePrice(sym);

   double p = desired;

   if(orderType == ORDER_TYPE_BUY_STOP)
      p = MathMax(p, ask + minDist);
   else if(orderType == ORDER_TYPE_SELL_STOP)
      p = MathMin(p, bid - minDist);

   return AlignToTick(sym, p);
}
// ------------------------------------------------------------------
// ArmBreakevenWallCoverLoss — shared-wall ABWCL
// ------------------------------------------------------------------

void ArmBreakevenWallCoverLoss_Rev_8_2_2(PosLists &poslists)
{
   // [ABWCL-1] Refresh and initial checks
   dm.Refresh(MagicNumber, _Symbol);

   int nWSL      = ArraySize(poslists.lstWNSL);
   int nAll      = ArraySize(poslists.lstAll);
   int nAllDeals = ArraySize(poslists.lstAllDeals);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;
   if(spread < 0.0)
      spread = 0.0;

   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0)
   {
      if(EnableDebugLogs)
         Print("[ABWCL-1] Skipped - invalid tickSize/tickValue");
      return;
   }

   double moneyPerPricePerLot = tickValue / tickSize;
   double commissionPerLotRoundTurn = gCommissionPerLot;

   double floatingNet = 0.0;
   double allLots = 0.0;

   for(int i = 0; i < nAll; i++)
   {
      floatingNet += poslists.lstAll[i].profit;
      allLots     += poslists.lstAll[i].lots;
   }

   floatingNet -= commissionPerLotRoundTurn * allLots;

   if(floatingNet <= 0.0)
   {
      if(EnableDebugLogs)
         Print("[ABWCL-1] Skipped - netProfit <= 0 after commission");
      return;
   }

   int buyCount  = dm.Count(POSITION_TYPE_BUY);
   int sellCount = dm.Count(POSITION_TYPE_SELL);

   if(nAllDeals == 0)
   {
      if(EnableDebugLogs)
         Print("[ABWCL-2] Skipped - no open positions");
      return;
   }

   // [ABWCL-3] Per-side statistics
   double B  = dm.Lots(POSITION_TYPE_BUY);
   double S  = dm.Lots(POSITION_TYPE_SELL);
   double BE = B * dm.AvgEntry(POSITION_TYPE_BUY);
   double SE = S * dm.AvgEntry(POSITION_TYPE_SELL);

   double buyProfit  = dm.NetProfit(POSITION_TYPE_BUY)  - (commissionPerLotRoundTurn * B);
   double sellProfit = dm.NetProfit(POSITION_TYPE_SELL) - (commissionPerLotRoundTurn * S);

   double denom = B - S;
   double denomProfit = buyProfit - sellProfit;
   double totalCommission = commissionPerLotRoundTurn * (B + S);

   if(MathAbs(denomProfit) < 1e-12)
   {
      if(EnableDebugLogs)
         Print("[ABWCL-5] Skipped - equal profits after commission");
      return;
   }

   // [ABWCL-5] Determine winner side after commission
   gABWCLWinnerSide = (denomProfit > 0.0 ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);

   double Sstar = 0.0;
   bool skipSstarSafety = false;

   // [ABWCL-4] Compute equilibrium S*
   if(MathAbs(denom) < 1e-12)
   {
      double basketProfit = buyProfit + sellProfit;

      if(basketProfit <= 0.0)
      {
         if(EnableDebugLogs)
            PrintFormat("[ABWCL-4] Skipped - equal lots but basketProfit <= 0 | basketProfit=%.2f",
                        basketProfit);
         return;
      }

      // Equal-lot hedge has no price equilibrium point; basket is already locked positive.
      skipSstarSafety = true;
      Sstar = (gABWCLWinnerSide == POSITION_TYPE_BUY ? bid : ask);
   }
   else
   {
      // Sstar is treated as future BID.
      // BUY closes at BID=Sstar, SELL closes at ASK=Sstar+spread.
      Sstar = (BE - SE + (S * spread) + (totalCommission / moneyPerPricePerLot)) / denom;
   }

   // [ABWCL-6] Wall from previous Candle candle
   double CandleRefLow  = gLowBuf[1];
   double CandleRefHigh = gHighBuf[1];

   switch(InpWinnerWallMode)
   {
      case PREV_CANDLE_BODY:
         CandleRefHigh = MathMax(gOpenBuf[1], gCloseBuf[1]);
         CandleRefLow  = MathMin(gOpenBuf[1], gCloseBuf[1]);
         break;

      case PREV_CANDLE_HIGH_LOW:
      default:
         CandleRefHigh = gHighBuf[1];
         CandleRefLow  = gLowBuf[1];
         break;

      case PREV_CANDLE_AVRG:
      {
         double bodyTop = MathMax(gOpenBuf[1], gCloseBuf[1]);
         double bodyBot = MathMin(gOpenBuf[1], gCloseBuf[1]);

         CandleRefHigh = (gHighBuf[1] + bodyTop) * 0.5;
         CandleRefLow  = (gLowBuf[1]  + bodyBot) * 0.5;
         break;
      }
   }

   double S_HA = (gABWCLWinnerSide == POSITION_TYPE_BUY ? CandleRefLow : CandleRefHigh);
   S_HA = AlignToTick(_Symbol, S_HA);

   // Convert wall to future BID for profit math.
   // BUY SL is BID-based. SELL SL is ASK-based, so future BID is wall - spread.
   double wallBidForMath = (gABWCLWinnerSide == POSITION_TYPE_BUY ? S_HA : S_HA - spread);

   // [ABWCL-7] Profit safety check
   bool profitSafe = true;

   if(!skipSstarSafety)
   {
      bool strategyOK = (denom > 0.0 ?
                         wallBidForMath >= Sstar :
                         wallBidForMath <= Sstar);

      bool marketOK = (denom > 0.0 ?
                       bid > Sstar :
                       ask < Sstar);

      profitSafe = strategyOK && marketOK;
   }

   if(!profitSafe)
   {
      if(EnableDebugLogs)
         PrintFormat("[ABWCL-7] Skipped - profit-safety failed | S*=%.5f | wall=%.5f | wallBid=%.5f | side=%s",
                     Sstar,
                     S_HA,
                     wallBidForMath,
                     (gABWCLWinnerSide == POSITION_TYPE_BUY ? "BUY" : "SELL"));
      return;
   }

   // [ABWCL-8] Broker min-stop check
   double minStop = MinStopDistancePrice(_Symbol);

   bool brokerOK = (gABWCLWinnerSide == POSITION_TYPE_BUY ?
                    S_HA <= bid - minStop :
                    S_HA >= ask + minStop);

   if(!brokerOK)
   {
      if(EnableDebugLogs)
         PrintFormat("[ABWCL-8] Fail (broker) | wall=%.5f", S_HA);
      return;
   }

   // [ABWCL-9] Snapshot current epoch
   gArmEpoch++;
   ResetAnchorAndRange();

   if(EnableDebugLogs)
      Print("[ABWCL-9] Range cleared on arming at epoch#.", gArmEpoch);

   gArmTime = TimeCurrent();

   SnapshotEpoch();
   gEpochStartTime = TimeCurrent();

   // [ABWCL-10] Apply shared SL to winners
   int protectedCount = ApplyWallToTickets(gEpochWinnerTickets, S_HA);

   // [ABWCL-11] Finalize outcome
   if(protectedCount > 0)
   {
      if(CanCloseLosersAgainstWinnerWall(S_HA))
      {
         FastCloseTickets(gEpochLoserTickets, true);
      }
//AGH_closing_check_of_losers

      gABWCLArmed = true;
      gABWCL_SL_winner = S_HA;
      gABWCL_SL_loser = 0.0;
      gArmedSL = S_HA;

      // Immediately drop any pre-armed pendings
      //AGH_Rev_8_3
      CancelAllPending();

      if(EnableDebugLogs)
         PrintFormat("[ABWCL-11] Epoch %d ARMED | Side=%s | Wall=%.5f | WallBid=%.5f | Prot=%d | S*=%.5f | B=%.2f | S=%.2f | Basket=%.2f | Comm=%.2f | SkipSstar=%s",
                     gArmEpoch,
                     (gABWCLWinnerSide == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                     S_HA,
                     wallBidForMath,
                     protectedCount,
                     Sstar,
                     B,
                     S,
                     buyProfit + sellProfit,
                     totalCommission,
                     (skipSstarSafety ? "true" : "false"));
   }
   else
   {
      if(EnableDebugLogs)
         Print("[ABWCL-12] No winners protected (all closed or rejected SL)");
   }
}

double CalcProfitAtWallForWinners(const ulong &winnerTickets[], double wall)
{
   double total = 0.0;

   for(int i = 0; i < ArraySize(winnerTickets); i++)
   {
      ulong t = winnerTickets[i];
      if(!PositionSelectByTicket(t))
         continue;

      int    type = (int)PositionGetInteger(POSITION_TYPE);
      double lot  = PositionGetDouble(POSITION_VOLUME);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);

      if(type == POSITION_TYPE_BUY)
         total += lot * (wall - open);
      else if(type == POSITION_TYPE_SELL)
         total += lot * (open - wall);

      if(gCommissionPerLot > 0.0)
         total -= gCommissionPerLot * lot;
   }

   return total;
}

double CalcClosableNowForLosers(const ulong &loserTickets[])
{
   double total = 0.0;

   for(int i = 0; i < ArraySize(loserTickets); i++)
   {
      ulong t = loserTickets[i];
      if(!PositionSelectByTicket(t))
         continue;

      total += PositionGetDouble(POSITION_PROFIT);

      if(gCommissionPerLot > 0.0)
         total -= gCommissionPerLot * PositionGetDouble(POSITION_VOLUME);
   }

   return total;
}

bool CanCloseLosersAgainstWinnerWall(double wall)
{
   double winnersAtWall = CalcProfitAtWallForWinners(gEpochWinnerTickets, wall);
   double losersNow     = CalcClosableNowForLosers(gEpochLoserTickets);

   double totalIfDoIt = winnersAtWall + losersNow;
   //AGH
   //PrintFormat("[CanCloseLosersAgainstWinnerWall] Line=%.2f winnersAtWall=%.2f losersNow=%.2f totalIfDoIt=%.2f",__LINE__,winnersAtWall, losersNow, totalIfDoIt);

   return (totalIfDoIt > 0.0);
}

void FastCloseTickets(const ulong &tickets[], bool verbose = true)
{
   for(int i = 0; i < ArraySize(tickets); i++)
      dm.FastClosePosition(tickets[i], verbose);
}
//+------------------------------------------------------------------+
//| Backfill comment to last closed deal of given symbol             |
//+------------------------------------------------------------------+
void TagLastClosedDeal(string symbol, string comment)
{
   // look into account history for most recent deal on this symbol
   ulong lastDeal = HistoryDealGetTicket(HistoryDealsTotal() - 1);
   if(!HistoryDealSelect(lastDeal)) return;
   if(HistoryDealGetString(lastDeal, DEAL_SYMBOL) != symbol) return;

   // this only affects MT5’s internal history display, not server log
   PrintFormat("TLC 1 Tagged deal %I64u: %s", lastDeal, comment);
}

//--- Ensure SL are valid for broker and market direction rev4.6
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

      // Too close? Push inward.
      if(newSL >= maxAllowed)
         newSL = maxAllowed ;

      // Monotonic rule: we never move SL *worse* than existing
      if(oldSL > 0.0 && newSL <= oldSL)
         newSL = oldSL;
   }
   else if(posType == POSITION_TYPE_SELL)
   {
      double minAllowed = ask + minStop;

      if(newSL <= minAllowed)
         newSL = minAllowed ;

      if(oldSL > 0.0 && newSL >= oldSL)
         newSL = oldSL;
   }
   else
   {
      return candidateSL;
   }

   // If still invalid
   if(newSL <= 0.0)
      return 0.0;

   // Snap to tick
   newSL = AlignToTick(sym, NormalizeDouble(newSL, digits));

   if(EnableDebugLogs)
      PrintFormat("[VSP] ticket=%I64u type=%s old=%.5f cand=%.5f out=%.5f bid=%.5f ask=%.5f minStop=%.5f",
                  ticket,
                  (posType==POSITION_TYPE_BUY ? "BUY" : "SELL"),
                  oldSL, candidateSL, newSL, bid, ask, minStop);

   return newSL;
}

// --- Helper: snapshot current positions into epoch groups
void SnapshotEpoch()
{
   ArrayResize(gEpochWinnerTickets, 0);
   ArrayResize(gEpochLoserTickets, 0);

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type == gABWCLWinnerSide)
      {
         int sz = ArraySize(gEpochWinnerTickets);
         ArrayResize(gEpochWinnerTickets, sz + 1);
         gEpochWinnerTickets[sz] = t;
      }
      else
      {
         int sz2 = ArraySize(gEpochLoserTickets);
         ArrayResize(gEpochLoserTickets, sz2 + 1);
         gEpochLoserTickets[sz2] = t;
      }
   }
}

// --- Helper: check if all tickets in list are closed
bool AllClosed(ulong &tickets[])
{
   for(int i=0; i<ArraySize(tickets); i++)
   {
      if(PositionSelectByTicket(tickets[i])) return false; // still open
   }
   return true;
}

// --- Helper: apply shared SL to specific tickets
// NEW 04.6: if ANY epoch position refuses the wall, kill ENTIRE epoch.
int ApplyWallToTickets(ulong &tickets[], double wallPrice)
{
    int  protectedCount = 0;
    bool anyFailed      = false;

    double wallNorm = NormalizeDouble(wallPrice, _Digits);

    for (int i = 0; i < ArraySize(tickets); i++)
    {
        ulong t = tickets[i];
        if (!PositionSelectByTicket(t))
            continue;
            
        double oldSL   = PositionGetDouble(POSITION_SL);
        double oldNorm = NormalizeDouble(oldSL, _Digits);

        // Already exactly at the wall → treated as protected, no UpdateSL call
        if(oldNorm == wallNorm && wallNorm > 0.0)
        {
            if(EnableDebugLogs)PrintFormat(
               "AWTT-EQ: ticket=%I64u already at wall SL=%.5f → counted as protected",
               t, oldSL
            );
            protectedCount++;
            continue;
        }

        if(EnableDebugLogs)Print("[TRACE] ApplyWallToTickets → attempting UpdateSL for ticket ", t); 

        bool success = UpdateSL(t, wallPrice);

        if (success)
        {
            if(EnableDebugLogs)PrintFormat("AWTT-1: UpdateSL succeeded for ticket=%I64u at SL %.5f",
                            t, wallPrice);

            if(PositionSelectByTicket(t))
            {
               double gotSL   = PositionGetDouble(POSITION_SL);
               double gotNorm = NormalizeDouble(gotSL, _Digits);
               if (gotNorm == wallNorm)
                  protectedCount++;
               else if(EnableDebugLogs)
                  PrintFormat("AWTT-1b: ticket=%I64u SL=%.5f != wall=%.5f",
                              t, gotSL, wallPrice);
            }
        }
        else
        {
            if(EnableDebugLogs)PrintFormat(
               "AWTT-2: ticket=%I64u refused wall %.5f → mark epoch failure",
               t, wallPrice
            );
            anyFailed = true;
        }
    }

    // 04.6 semantics: ANY failure → close the entire epoch via your helper
    if(anyFailed)
    {
        if(EnableDebugLogs)Print(
           "AWTT-3: at least one epoch position refused wall → CloseAllEpochPositions()"
        );
        CloseAllEpochPositions();   // <-- use your existing function, not dm.ClosePosition
        protectedCount = 0;         // epoch is effectively ended
    }

    return protectedCount;
}

bool IsEpochTicket(ulong t)
{
//    if(!PositionSelectByTicket(t)) 
//        return false;
//
//    datetime pt = (datetime)PositionGetInteger(POSITION_TIME);
//
//    // Only allow positions that opened BEFORE snapshot
//    if(pt > gEpochStartTime) 
//        return false;
        
   for(int i=0;i<ArraySize(gEpochWinnerTickets);++i)
      if(gEpochWinnerTickets[i]==t) return true;
   for(int i=0;i<ArraySize(gEpochLoserTickets);++i)
      if(gEpochLoserTickets[i]==t) return true;
   return false;
}

int CountNonEpochPositions(int typeFilter /*POSITION_TYPE_BUY/SELL or -1*/)
{
   int cnt=0;
   for(int i=PositionsTotal()-1;i>=0;--i)
   {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      int typ=(int)PositionGetInteger(POSITION_TYPE);
      if(typeFilter!=-1 && typ!=typeFilter) continue;
      if(!IsEpochTicket(t)) cnt++;
   }
   return cnt;
}

void ComputeEntry(double &buyEntry, double &sellEntry, PosLists &poslists, long type)
{
   if(BreakoutMode == MODE_FLOATING_BREAKOUT)
      ComputeEntryFloating(buyEntry, sellEntry, poslists, type);
   else if(BreakoutMode == MODE_RANGE_ANCHOR)
      ComputeEntryAnchors_R_8_1(buyEntry, sellEntry, poslists, type);
   else if(BreakoutMode == MODE_ASYMMETRIC_ANCHOR)
      ComputeEntryAsymmetric_R63(buyEntry, sellEntry, poslists, type);
   buyEntry  = AlignToTick(_Symbol, ClampPendingEntry(_Symbol, ORDER_TYPE_BUY_STOP,  buyEntry));
   sellEntry = AlignToTick(_Symbol, ClampPendingEntry(_Symbol, ORDER_TYPE_SELL_STOP, sellEntry));   
}

// ---------------------------------------------------------------
// Core policy: decide anchors AND (when appropriate) seed the range
// ---------------------------------------------------------------
// Behavior:
// 1) Armed & NO range & NO non-epoch positions      → anchor = HA[1]
// 2) Armed & NO range & HAS non-epoch positions     → anchor = HA[1], then SEED range from HA[1]
// 3) Armed & HAS range                              → anchor = range
// 4) Not armed & NO range                           → SEED range from HA[1], anchor = range
// 5) Not armed & HAS range                          → anchor = range
//
// Notes:
// • ArmBreakevenWallCoverLoss() already clears range at [ABWCL-9].
// • First newcomer during armed epoch will cause (2) to seed range, but we KEEP using HA[1] while armed.
// • Callers still ClampPendingEntry() and AlignToTick() after this.
// ---------------------------------------------------------------
void ComputeEntryAnchors_R_8_1(double &buyEntry, double &sellEntry, PosLists &poslists, long orderType)
{
   int nAllDeals = ArraySize(poslists.lstAllDeals);
   int nAll = ArraySize(poslists.lstAll);
   int nWNSL = ArraySize(poslists.lstWNSL);
   int n = nWNSL;
   
   SortByOpenTimeAscending(poslists.lstWNSL);
   
   
   if(gABWCLArmed && gArmedSL != 0.0 && nWNSL ==0)
   {
      buyEntry = gArmedSL;
      sellEntry = gArmedSL;
      return;
   }
   
   double candleHigh = gHighBuf[1];
   double candleLow  = gLowBuf[1];

   ComputeEntryCandleRange(candleHigh, candleLow, orderType);
   
   if(UseEntryRangeFilter_1)
      {
         double candleRange = candleHigh - candleLow;
         double minRange = AsymmetricRangeDistanceInPrice * EntryMinRangeFactor;
         double maxRange = AsymmetricRangeDistanceInPrice * EntryMaxRangeFactor;
         double mid = (candleHigh + candleLow) * 0.5;
      
         if(candleRange < minRange)
         {
            if(orderType == ORDER_TYPE_BUY_STOP)
            {
               //candleHigh = candleHigh + AsymmetricRangeDistanceInPrice;
               //candleLow = candleLow - AsymmetricRangeDistanceInPrice;
               candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
            }
            else if(orderType == ORDER_TYPE_SELL_STOP)
            {
               //candleLow = candleLow - AsymmetricRangeDistanceInPrice;
               //candleHigh = candleHigh + AsymmetricRangeDistanceInPrice;
               candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
            }
            else
            {
               candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
            }
         }
         else if(candleRange > maxRange)
         {
            double mid = (candleHigh + candleLow) * 0.5;
      
            if(orderType == ORDER_TYPE_BUY_STOP)
            {
               //candleHigh = mid + AsymmetricRangeDistanceInPrice;
               //candleLow  = mid;
               //
               candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
               //
               //candleLow = candleHigh - AsymmetricRangeDistanceInPrice;
            }
            else if(orderType == ORDER_TYPE_SELL_STOP)
            {
               //candleHigh = mid;
               //candleLow  = mid - AsymmetricRangeDistanceInPrice;
               //
               candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
               //
               //candleHigh = candleLow + AsymmetricRangeDistanceInPrice;
            }
            else
            {
               candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
            }
         }
      }
   
   if(UseEntryRangeFilter_2)
      {
         double candleRange = candleHigh - candleLow;
         double minRange = AsymmetricRangeDistanceInPrice * EntryMinRangeFactor;
         double maxRange = AsymmetricRangeDistanceInPrice * EntryMaxRangeFactor;
      
         if(candleRange < minRange)
         {
            if(orderType == ORDER_TYPE_BUY_STOP)
            {
               //candleHigh = candleHigh + AsymmetricRangeDistanceInPrice;
               candleLow = candleLow - AsymmetricRangeDistanceInPrice;
            }
            else if(orderType == ORDER_TYPE_SELL_STOP)
            {
               //candleLow = candleLow - AsymmetricRangeDistanceInPrice;
               candleHigh = candleHigh + AsymmetricRangeDistanceInPrice;
            }
            else
            {
               double mid = (candleHigh + candleLow) * 0.5;
               candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
            }
         }
         else if(candleRange > maxRange)
         {
            double mid = (candleHigh + candleLow) * 0.5;
      
            if(orderType == ORDER_TYPE_BUY_STOP)
            {
               //candleHigh = mid + AsymmetricRangeDistanceInPrice;
               //candleLow  = mid;
               //
               //candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               //candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
               //
               candleLow = candleHigh - AsymmetricRangeDistanceInPrice;
            }
            else if(orderType == ORDER_TYPE_SELL_STOP)
            {
               //candleHigh = mid;
               //candleLow  = mid - AsymmetricRangeDistanceInPrice;
               //
               //candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               //candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
               //
               candleHigh = candleLow + AsymmetricRangeDistanceInPrice;
            }
            //else //AGH_REV_8_6
            //{
            //   candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
            //   candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
            //}
         }
      }
   
   // --- Two Candle sides ---
   //double candleHigh = gHighBuf[1];
   //double candleLow  = gLowBuf[1];
   
   // Distance in price units
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread = ask - bid;
   double distanceInPrice = candleHigh - candleLow;
   
   double minStop = MinStopDistancePrice(_Symbol);
   double freeze = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   double minRequired = minStop + freeze + spread;

   if(distanceInPrice < minRequired)
   {
      double pip = _Point;
      if(_Digits == 3 || _Digits == 5)
         pip = 10.0 * _Point;
      double volBuffer = 0;
      //distanceInPrice = minRequired + (2.0 * pip);
      
      ENUM_TIMEFRAMES tf = (Timeframe == 0 ? (ENUM_TIMEFRAMES)Period() : Timeframe);
      int atrHandle = iATR(_Symbol, tf, ATR_Period);
      if(atrHandle != INVALID_HANDLE)
      {
         double atrBuf[];
         if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) == 1)
         {
            double atr = atrBuf[0];   // ATR in price units
            if(atr > 0.0)
            volBuffer = atr * 0.5;
         }
         IndicatorRelease(atrHandle);
      }

      double baseMin = spread * 1.5 + minStop + freeze;
      distanceInPrice = MathMax(distanceInPrice, baseMin + volBuffer);
      if(EnableDebugLogs)
         PrintFormat("[ASYM] Distance adjusted to %.2f pips", distanceInPrice/pip);
   }

   // Get last position side (if exists)
   int lastSide = (n > 0) ? poslists.lstWNSL[n-1].type : -1;
   double lastPrice = (n > 0) ? poslists.lstWNSL[n-1].openPrice : 0;
   int firstSide = (n > 0) ? poslists.lstWNSL[0].type : -1;
   double firstPrice = (n > 0) ? poslists.lstWNSL[0].openPrice : 0;
   // ===================================================================
   // DECISION TREE
   // ===================================================================
   
   // If range is already set
   if(n > 0 && gbuyEntry_range != 0 && gsellEntry_range != 0)
   {
      // Distance is OK, use saved range
      buyEntry = gbuyEntry_range;
      sellEntry = gsellEntry_range;
      return;
   }
      
   // No range set yet → determine entries
   
   // NO POSITIONS: Use Candle breakout levels
   if(n == 0)
   {
      buyEntry  = candleHigh;
      sellEntry = candleLow;
      grange = candleHigh - candleLow;
      
      return;
   }
   
   if(n > 0 && (gbuyEntry_range == 0 || gsellEntry_range == 0))
   {
      if(firstSide == POSITION_TYPE_SELL)
      {
         sellEntry = firstPrice;
         buyEntry  = sellEntry + grange;
      }
      else if(firstSide == POSITION_TYPE_BUY)
      {
         buyEntry  = firstPrice;
         sellEntry = buyEntry - grange;
      }
   
      // Lock the range once calculated
      gbuyEntry_range = buyEntry;
      gsellEntry_range = sellEntry;
      SaveRangeState();
   }
}

void SaveRangeState_Archive()
{
   GlobalVariableSet("EA_BUY_RANGE_" + _Symbol, gbuyEntry_range);
   GlobalVariableSet("EA_SELL_RANGE_" + _Symbol, gsellEntry_range);
   GlobalVariableSet("EA_GRANGE_" + _Symbol, grange);
}

//AGH_RE_8_6
void SaveRangeState()
{
   string tf = IntegerToString(_Period);
   GlobalVariableSet("EA_BUY_RANGE_"  + _Symbol + "_" + tf, gbuyEntry_range);
   GlobalVariableSet("EA_SELL_RANGE_" + _Symbol + "_" + tf, gsellEntry_range);
   GlobalVariableSet("EA_GRANGE_"     + _Symbol + "_" + tf, grange);
}

void LoadRangeState_archive()
{
   string kBuy   = "EA_BUY_RANGE_" + _Symbol;
   string kSell  = "EA_SELL_RANGE_" + _Symbol;
   string kRange = "EA_GRANGE_" + _Symbol;

   if(GlobalVariableCheck(kBuy))
      gbuyEntry_range = GlobalVariableGet(kBuy);

   if(GlobalVariableCheck(kSell))
      gsellEntry_range = GlobalVariableGet(kSell);

   if(GlobalVariableCheck(kRange))
      grange = GlobalVariableGet(kRange);
}
//AGH_RE_8_6
void LoadRangeState()
{
   string tf     = IntegerToString(_Period);
   string kBuy   = "EA_BUY_RANGE_"  + _Symbol + "_" + tf;
   string kSell  = "EA_SELL_RANGE_" + _Symbol + "_" + tf;
   string kRange = "EA_GRANGE_"     + _Symbol + "_" + tf;
   if(GlobalVariableCheck(kBuy))
      gbuyEntry_range = GlobalVariableGet(kBuy);
   if(GlobalVariableCheck(kSell))
      gsellEntry_range = GlobalVariableGet(kSell);
   if(GlobalVariableCheck(kRange))
      grange = GlobalVariableGet(kRange);
}

void ClearRangeState_archive()
{
   GlobalVariableDel("EA_BUY_RANGE_" + _Symbol);
   GlobalVariableDel("EA_SELL_RANGE_" + _Symbol);
   GlobalVariableDel("EA_GRANGE_" + _Symbol);
}

//AGH_RE_8_6
void ClearRangeState()
{
   string tf = IntegerToString(_Period);
   GlobalVariableDel("EA_BUY_RANGE_"  + _Symbol + "_" + tf);
   GlobalVariableDel("EA_SELL_RANGE_" + _Symbol + "_" + tf);
   GlobalVariableDel("EA_GRANGE_"     + _Symbol + "_" + tf);
}
//+------------------------------------------------------------------+
//| Asymmetric anchor: one side from HA, other calculated by distance
//|
//| Behavior:
//| 1) Armed & NO range & NO non-epoch positions     → anchor = HA[1]
//| 2) Armed & NO range & HAS non-epoch positions    → anchor = HA[1], SEED range
//| 3) Armed & HAS range                             → anchor = range
//| 4) Not armed & NO range                          → SEED range from HA[1], anchor = range
//| 5) Not armed & HAS range                         → anchor = range
//|
//| For each buy/sell anchor, opposite side = anchor ± distance (respecting broker constraints)
//+------------------------------------------------------------------+
void ComputeEntryAsymmetric_R63(double &buyEntry, double &sellEntry, PosLists &poslists, long orderType)
{   
   int nAllDeals = ArraySize(poslists.lstAllDeals);
   int nAll = ArraySize(poslists.lstAll);
   int nWNSL = ArraySize(poslists.lstWNSL);
   int n = nWNSL;
   
   SortByOpenTimeAscending(poslists.lstWNSL);

   // Distance in price units
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread = ask - bid;
   double distanceInPrice = AsymmetricRangeDistanceInPrice;
   
   double minStop = MinStopDistancePrice(_Symbol);
   double freeze = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   double minRequired = minStop + freeze + spread;

   if(distanceInPrice < minRequired)
   {
      double pip = _Point;
      if(_Digits == 3 || _Digits == 5)
         pip = 10.0 * _Point;
      double volBuffer = 0;
      //distanceInPrice = minRequired + (2.0 * pip);
      
      ENUM_TIMEFRAMES tf = (Timeframe == 0 ? (ENUM_TIMEFRAMES)Period() : Timeframe);
      int atrHandle = iATR(_Symbol, tf, ATR_Period);
      if(atrHandle != INVALID_HANDLE)
      {
         double atrBuf[];
         if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) == 1)
         {
            double atr = atrBuf[0];   // ATR in price units
            if(atr > 0.0)
            volBuffer = atr * 0.5;
         }
         IndicatorRelease(atrHandle);
      }

      double baseMin = spread * 1.5 + minStop + freeze;
      distanceInPrice = MathMax(AsymmetricRangeDistanceInPrice, baseMin + volBuffer);
      if(EnableDebugLogs)
         PrintFormat("[ASYM] Distance adjusted to %.2f pips", distanceInPrice/pip);
   }
   
   // --- Two Candle sides ---
   double candleHigh = gHighBuf[1] ;
   double candleLow  = gLowBuf[1] ;

   // Get last position side (if exists)
   int lastSide = (n > 0) ? poslists.lstWNSL[n-1].type : -1;
   double lastPrice = (n > 0) ? poslists.lstWNSL[n-1].openPrice : 0;
   // ===================================================================
   // DECISION TREE
   // ===================================================================
   
   // If range is already set
   if(gbuyEntry_range != 0 && gsellEntry_range != 0)
   {
      double currentDistance = gbuyEntry_range - gsellEntry_range;
      
      // If distance is too wide, adjust it
      if(currentDistance > distanceInPrice)
      {
         buyEntry = gbuyEntry_range;
         sellEntry = buyEntry - distanceInPrice;
         
         // Update saved range
         gbuyEntry_range = buyEntry;
         gsellEntry_range = sellEntry;
         
         if(EnableDebugLogs)
            PrintFormat("[ASYM] Range adjusted: distance %.2f → %.2f", currentDistance, distanceInPrice);
      }
      else
      {
         // Distance is OK, use saved range
         buyEntry = gbuyEntry_range;
         sellEntry = gsellEntry_range;
      }
      return;
   }
      
   // No range set yet → determine entries
   
   // NO POSITIONS: Use Candle breakout levels
   if(n == 0)
   {
      buyEntry  = candleHigh;
      sellEntry = candleLow;
      return;
   }
   
   // HAS POSITIONS: Anchor to last position and calculate opposite side
   if(n > 0 && lastSide == POSITION_TYPE_BUY)
   {
      buyEntry  = lastPrice;
      sellEntry = buyEntry - distanceInPrice;
   }
   else if(lastSide == POSITION_TYPE_SELL)
   {
      sellEntry = lastPrice;
      buyEntry  = sellEntry + distanceInPrice;
   }
   
   // Lock the range once calculated
   gbuyEntry_range = buyEntry;
   gsellEntry_range = sellEntry;
   SaveRangeState();
}

void ComputeEntryFloating(double &buyEntry, double &sellEntry, PosLists &poslists, long orderType)
{   
   int nAllDeals = ArraySize(poslists.lstAllDeals);
   int nAll = ArraySize(poslists.lstAll);
   int nWNSL = ArraySize(poslists.lstWNSL);
   int n = nWNSL;
   
   if(gABWCLArmed && gArmedSL != 0.0 && nWNSL ==0)
   {
      buyEntry = gArmedSL;
      sellEntry = gArmedSL;
      return;
   }
   
   double candleHigh = gHighBuf[1];
   double candleLow  = gLowBuf[1];
   
   ComputeEntryCandleRange(candleHigh, candleLow, orderType);
   
   if(UseEntryRangeFilter_1)
      {
         double candleRange = candleHigh - candleLow;
         double minRange = AsymmetricRangeDistanceInPrice * EntryMinRangeFactor;
         double maxRange = AsymmetricRangeDistanceInPrice * EntryMaxRangeFactor;
         double mid = (candleHigh + candleLow) * 0.5;

         if(candleRange < minRange)
         {
            if(orderType == ORDER_TYPE_BUY_STOP)
            {
               //candleHigh = candleHigh + AsymmetricRangeDistanceInPrice;
               //candleLow = candleLow - AsymmetricRangeDistanceInPrice;
               candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
            }
            else if(orderType == ORDER_TYPE_SELL_STOP)
            {
               //candleLow = candleLow - AsymmetricRangeDistanceInPrice;
               //candleHigh = candleHigh + AsymmetricRangeDistanceInPrice;
               candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
            }
            else
            {
               candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
            }
         }
         else if(candleRange > maxRange)
         {
            double mid = (candleHigh + candleLow) * 0.5;
      
            if(orderType == ORDER_TYPE_BUY_STOP)
            {
               //candleHigh = mid + AsymmetricRangeDistanceInPrice;
               //candleLow  = mid;
               //
               candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
               //
               //candleLow = candleHigh - AsymmetricRangeDistanceInPrice;
            }
            else if(orderType == ORDER_TYPE_SELL_STOP)
            {
               //candleHigh = mid;
               //candleLow  = mid - AsymmetricRangeDistanceInPrice;
               //
               candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
               //
               //candleHigh = candleLow + AsymmetricRangeDistanceInPrice;
            }
            else
            {
               candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
            }
         }
      }
   
   if(UseEntryRangeFilter_2)
      {
         double candleRange = candleHigh - candleLow;
         double minRange = AsymmetricRangeDistanceInPrice * EntryMinRangeFactor;
         double maxRange = AsymmetricRangeDistanceInPrice * EntryMaxRangeFactor;
      
         if(candleRange < minRange)
         {
            if(orderType == ORDER_TYPE_BUY_STOP)
            {
               //candleHigh = candleHigh + AsymmetricRangeDistanceInPrice;
               candleLow = candleLow - AsymmetricRangeDistanceInPrice;
            }
            else if(orderType == ORDER_TYPE_SELL_STOP)
            {
               //candleLow = candleLow - AsymmetricRangeDistanceInPrice;
               candleHigh = candleHigh + AsymmetricRangeDistanceInPrice;
            }
            else
            {
               double mid = (candleHigh + candleLow) * 0.5;
               candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
            }
         }
         else if(candleRange > maxRange)
         {
            double mid = (candleHigh + candleLow) * 0.5;
      
            if(orderType == ORDER_TYPE_BUY_STOP)
            {
               //candleHigh = mid + AsymmetricRangeDistanceInPrice;
               //candleLow  = mid;
               //
               //candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               //candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
               //
               candleLow = candleHigh - AsymmetricRangeDistanceInPrice;
            }
            else if(orderType == ORDER_TYPE_SELL_STOP)
            {
               //candleHigh = mid;
               //candleLow  = mid - AsymmetricRangeDistanceInPrice;
               //
               //candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               //candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
               //
               candleHigh = candleLow + AsymmetricRangeDistanceInPrice;
            }
            else
            {
               candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
               candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
            }
         }
      }

   buyEntry = candleHigh;
   gbuyEntry_range = candleHigh;
   
   sellEntry = candleLow;
   gsellEntry_range = candleLow;
}

void ComputeEntryCandleRange(double &candleHigh, double &candleLow, long orderType)
{
   switch(InpEntryMode)
   {
      case PREV_N_CANDLE_HIGH_LOW_MAX_MIN:
      {
         int bars = MathMax(1, InpEntryModeN);

         double maxHigh = gHighBuf[1];
         double minLow  = gLowBuf[1];

         for(int i = 2; i <= bars; i++)
         {
            if(gHighBuf[i] > maxHigh)
               maxHigh = gHighBuf[i];

            if(gLowBuf[i] < minLow)
               minLow = gLowBuf[i];
         }

         candleHigh = maxHigh;
         candleLow  = minLow;
         break;
      }

      case PREV_N_CANDLE_BODY_MAX_MIN:
      {
         int bars = MathMax(1, InpEntryModeN);

         double maxBody = MathMax(gOpenBuf[1], gCloseBuf[1]);
         double minBody = MathMin(gOpenBuf[1], gCloseBuf[1]);

         for(int i = 2; i <= bars; i++)
         {
            double bodyTop = MathMax(gOpenBuf[i], gCloseBuf[i]);
            double bodyBot = MathMin(gOpenBuf[i], gCloseBuf[i]);

            if(bodyTop > maxBody)
               maxBody = bodyTop;

            if(bodyBot < minBody)
               minBody = bodyBot;
         }

         candleHigh = maxBody;
         candleLow  = minBody;
         break;
      }

      case PREV_N_CANDLE_HIGH_LOW_AVRG:
      {
         int bars = MathMax(1, InpEntryModeN);

         double sumHigh = 0.0;
         double sumLow  = 0.0;

         for(int i = 1; i <= bars; i++)
         {
            sumHigh += gHighBuf[i];
            sumLow  += gLowBuf[i];
         }

         candleHigh = sumHigh / bars;
         candleLow  = sumLow  / bars;
         break;
      }

      case PREV_N_CANDLE_BODY_AVRG:
      {
         int bars = MathMax(1, InpEntryModeN);

         double sumTop = 0.0;
         double sumBottom = 0.0;

         for(int i = 1; i <= bars; i++)
         {
            sumTop    += MathMax(gOpenBuf[i], gCloseBuf[i]);
            sumBottom += MathMin(gOpenBuf[i], gCloseBuf[i]);
         }

         candleHigh = sumTop / bars;
         candleLow  = sumBottom / bars;
         break;
      }

      case PREV_N_CANDLE_HIGH_LOW_BODY_AVRG_MAX_MIN:
      {
         int bars = MathMax(1, InpEntryModeN);

         double bodyTop1 = MathMax(gOpenBuf[1], gCloseBuf[1]);
         double bodyBot1 = MathMin(gOpenBuf[1], gCloseBuf[1]);

         double maxHigh = (gHighBuf[1] + bodyTop1) * 0.5;
         double minLow  = (gLowBuf[1]  + bodyBot1) * 0.5;

         for(int i = 2; i <= bars; i++)
         {
            double bodyTop = MathMax(gOpenBuf[i], gCloseBuf[i]);
            double bodyBot = MathMin(gOpenBuf[i], gCloseBuf[i]);

            double derivedHigh = (gHighBuf[i] + bodyTop) * 0.5;
            double derivedLow  = (gLowBuf[i]  + bodyBot) * 0.5;

            if(derivedHigh > maxHigh)
               maxHigh = derivedHigh;

            if(derivedLow < minLow)
               minLow = derivedLow;
         }

         candleHigh = maxHigh;
         candleLow  = minLow;
         break;
      }

      case PREV_N_CANDLE_HIGH_LOW_MID_P_RANGE:
      {
         int bars = MathMax(1, InpEntryModeN);

         double maxHigh = gHighBuf[1];
         double minLow  = gLowBuf[1];

         for(int i = 2; i <= bars; i++)
         {
            if(gHighBuf[i] > maxHigh)
               maxHigh = gHighBuf[i];

            if(gLowBuf[i] < minLow)
               minLow = gLowBuf[i];
         }

         double mid = (maxHigh + minLow) * 0.5;
         candleHigh = mid + AsymmetricRangeDistanceInPrice / 2.0;
         candleLow  = mid - AsymmetricRangeDistanceInPrice / 2.0;
         break;
      }
   }

}

double AlignVolume(const string sym, double vol)
{
   double minv  = gMinLot;
   double maxv  = gMaxLot;
   double step  = gLotStep;
   
   // Respect EA-defined min/max overrides
   if (LotMin > 0) minv = MathMax(minv, LotMin);
   if (LotMax > 0) maxv = MathMin(maxv, LotMax);

   if(step > 0.0)
   {
      // round UP to nearest step
      double steps = vol / step;
      steps = MathCeil(steps);
      vol   = steps * step;
   }

   // clamp to [minv, maxv]
   if(vol < minv) vol = minv;
   if(vol > maxv) vol = maxv;

   return vol;
}

double ComputeNextLotSizeINC_EntryAware_Rev_8_4(ENUM_ORDER_TYPE nextType, double nextEntry, PosLists &poslists)
{
   int nAll = ArraySize(poslists.lstAll);
   int nWSL = ArraySize(poslists.lstWNSL);
   int nAllDeals = ArraySize(poslists.lstAllDeals);

   int n = nWSL;
   SortByOpenTimeAscending(poslists.lstWNSL);
   SortByOpenTimeAscending(poslists.lstAll);

   if(n == 0)
      return AlignVolume(_Symbol, LotSizeInput);

   double B = ComputeBufferB(n, poslists);
   if(B <= 0.0)
      return AlignVolume(_Symbol, LotSizeInput);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;
   if(spread < 0.0)
      spread = 0.0;

   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0)
   {
      //Print("ComputeNextLotSizeINC_EntryAware_Rev_8_2 Line:", __LINE__, " invalid tickSize/tickValue");
      return AlignVolume(_Symbol, LotSizeInput);
   }

   double moneyPerPricePerLot = tickValue / tickSize;

   // Pstar is treated as future BID
   double Pstar = (nextType == ORDER_TYPE_BUY_STOP ? nextEntry + B : nextEntry - B);

   double pnlMoney = 0.0;

   for(int i = 0; i < n; i++)
   {
      double e   = poslists.lstWNSL[i].openPrice;
      double lot = poslists.lstWNSL[i].lots;

      double pricePnL;

      if(poslists.lstWNSL[i].type == POSITION_TYPE_BUY)
         pricePnL = Pstar - e;
      else
         pricePnL = e - (Pstar + spread);

      pnlMoney += pricePnL * moneyPerPricePerLot * lot;

      // Commission cost for existing trade, estimated as round-turn.
      pnlMoney -= gCommissionPerLot * lot;
   }

   double contribPerLotMoney =
      (nextType == ORDER_TYPE_BUY_STOP ? ((Pstar - nextEntry) - spread) * moneyPerPricePerLot
                                       : ((nextEntry - Pstar) - spread) * moneyPerPricePerLot);

   // Commission cost for the new trade, per 1.00 lot.
   contribPerLotMoney -= gCommissionPerLot;

   if(contribPerLotMoney <= 0.0)
      return AlignVolume(_Symbol, LotSizeInput);

   double neededLots = -pnlMoney / contribPerLotMoney;

   if(neededLots <= 0.0)
      return 0.0;

   return AlignVolume(_Symbol, neededLots);
}

//////

double ComputeNextLotSizeINC_Rev8_2(ENUM_ORDER_TYPE &ptype, double buyEntry, double sellEntry, PosLists &poslists)
{
   int nWSL = ArraySize(poslists.lstWNSL);

   int n = nWSL;
   SortByOpenTimeAscending(poslists.lstWNSL);

   if(n <= 0)
      return AlignVolume(_Symbol, LotSizeInput);

   int lastSide = poslists.lstWNSL[n-1].type;

   if(lastSide == POSITION_TYPE_BUY)
      ptype = ORDER_TYPE_SELL_STOP;

   if(lastSide == POSITION_TYPE_SELL)
      ptype = ORDER_TYPE_BUY_STOP;

   double B = ComputeBufferB(n, poslists);
   if(B <= 0.0 && n > 0)
   {
      //Print("ComputeNextLotSizeINC_Rev8_2 Line:", __LINE__, " B & nWSL ", B, n);
      return AlignVolume(_Symbol, LotSizeInput);
   }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;
   if(spread < 0.0)
      spread = 0.0;

   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0)
   {
      //Print("ComputeNextLotSizeINC_Rev8_2 Line:", __LINE__, " invalid tickSize/tickValue");
      //AGH_REV_8_6
      //return AlignVolume(_Symbol, LotSizeInput);
      //AGH_REV_8_6
   }

   double moneyPerPricePerLot = tickValue / tickSize;

   // Pstar is treated as future BID
   double Pstar = (ptype == ORDER_TYPE_BUY_STOP ? buyEntry + B : sellEntry - B);

   double pnlMoney = 0.0;

   for(int i = 0; i < n; i++)
   {
      double e   = poslists.lstWNSL[i].openPrice;
      double lot = poslists.lstWNSL[i].lots;

      double pricePnL;

      if(poslists.lstWNSL[i].type == POSITION_TYPE_BUY)
         pricePnL = Pstar - e;
      else
         pricePnL = e - (Pstar + spread);

      pnlMoney += pricePnL * moneyPerPricePerLot * lot;

      // Commission cost for existing trade, estimated as round-turn.
      pnlMoney -= gCommissionPerLot * lot;
   }

   double contribPerLotMoney;

   if(ptype == ORDER_TYPE_BUY_STOP)
      contribPerLotMoney = ((Pstar - buyEntry) - spread) * moneyPerPricePerLot;
   else
      contribPerLotMoney = ((sellEntry - Pstar) - spread) * moneyPerPricePerLot;

   // Commission cost for the new trade, per 1.00 lot.
   contribPerLotMoney -= gCommissionPerLot;

   if(contribPerLotMoney <= 0.0)
   {
      //Print("ComputeNextLotSizeINC_Rev8_2 Line: ", __LINE__, " contribPerLotMoney: ", contribPerLotMoney);
      //return AlignVolume(_Symbol, LotSizeInput);    // AGH_REV_8_5
      return 0.0;
      // AGH_REV_8_5
   }

   double neededLots = -pnlMoney / contribPerLotMoney;

   if(neededLots <= 0.0)
   {
      //Print("ComputeNextLotSizeINC_Rev8_1 ", __LINE__,
      //      " neededLots: ", neededLots,
      //      " contribPerLotMoney: ", contribPerLotMoney,
      //      " pnlMoney: ", pnlMoney);
      return 0.0;
   }

   return AlignVolume(_Symbol, neededLots);
}

double ComputeNextLotSizeINC_EntryAware_Rev_8_2(ENUM_ORDER_TYPE nextType, double nextEntry, PosLists &poslists)
{
   int nAll = ArraySize(poslists.lstAll);
   int nWSL = ArraySize(poslists.lstWNSL);
   int nAllDeals = ArraySize(poslists.lstAllDeals);

   int n = nWSL;
   SortByOpenTimeAscending(poslists.lstWNSL);
   SortByOpenTimeAscending(poslists.lstAll);

   if(n == 0)
      return AlignVolume(_Symbol, LotSizeInput);

   double B = ComputeBufferB(n, poslists);
   if(B <= 0.0)
      return AlignVolume(_Symbol, LotSizeInput);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;
   if(spread < 0.0)
      spread = 0.0;

   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0)
   {
      //Print("ComputeNextLotSizeINC_EntryAware_Rev_8_2 Line:", __LINE__, " invalid tickSize/tickValue");
      return AlignVolume(_Symbol, LotSizeInput);
   }

   double moneyPerPricePerLot = tickValue / tickSize;

   // Pstar is treated as future BID
   double Pstar = (nextType == ORDER_TYPE_BUY_STOP ? nextEntry + B : nextEntry - B);

   double pnlMoney = 0.0;

   for(int i = 0; i < n; i++)
   {
      double e   = poslists.lstWNSL[i].openPrice;
      double lot = poslists.lstWNSL[i].lots;

      double pricePnL;

      if(poslists.lstWNSL[i].type == POSITION_TYPE_BUY)
         pricePnL = Pstar - e;
      else
         pricePnL = e - (Pstar + spread);

      pnlMoney += pricePnL * moneyPerPricePerLot * lot;

      // Commission cost for existing trade, estimated as round-turn.
      pnlMoney -= gCommissionPerLot * lot;
   }

   double contribPerLotMoney =
      (nextType == ORDER_TYPE_BUY_STOP ? ((Pstar - nextEntry) - spread) * moneyPerPricePerLot
                                       : ((nextEntry - Pstar) - spread) * moneyPerPricePerLot);

   // Commission cost for the new trade, per 1.00 lot.
   contribPerLotMoney -= gCommissionPerLot;

   if(contribPerLotMoney <= 0.0)
      return AlignVolume(_Symbol, LotSizeInput);

   double neededLots = -pnlMoney / contribPerLotMoney;

   if(neededLots <= 0.0)
      return 0.0;

   return AlignVolume(_Symbol, neededLots);
}

double ComputeBufferB(int n, PosLists &poslists)
{
   double B = GetBuffer_REV_7_2(n, poslists);
   gdebugD04 = B;

   // --- 2) ATR part (MT5 style: use handle + CopyBuffer)
   if(UseATRinBuffer)
   {
      ENUM_TIMEFRAMES tf = (Timeframe == 0 ? (ENUM_TIMEFRAMES)Period() : Timeframe);
      int atrHandle = iATR(_Symbol, tf, ATR_Period);
      if(atrHandle != INVALID_HANDLE)
      {
         double atrBuf[];
         if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) == 1)
         {
            double atr = atrBuf[0];   // ATR in price units
            if(atr > 0.0)
               B += ATR_BufferFactor * atr;
         }
         IndicatorRelease(atrHandle);
      }
   }
   return B;
}

double GetBuffer(int n)
{
   int size = ArraySize(bufferMap);

   if(size == 0)
      return 0.0;

   if(n < size)
      return bufferMap[n];

   return bufferMap[size - 1]; // clamp
}

double GetBuffer_REV_7_2(int n, PosLists &poslists)
{
   int size = ArraySize(bufferMap);

   if(size == 0)
      return 0.0;

   bool useProgressiveMap = false;

   //if(AccountInfoDouble(ACCOUNT_MARGIN) >= gMarginUsedBufferLevel)
   //   useProgressiveMap = true;
   //if(!useProgressiveMap && BufferLotDivisor > 0.0)
   if(BufferLotDivisor > 0.0)
   {
      double triggerLot = gMaxLot / BufferLotDivisor;
      //gdebugD01 = triggerLot;
      //gdebugD02 = poslists.lstAllDeals[0].lots;
      //gdebugD03 = poslists.lstAllDeals[n-1].lots;
      //gdebugB01 = useProgressiveMap;
      if(poslists.lstAll[n-1].lots >= triggerLot)
         useProgressiveMap = true;
         //gdebugB01 = useProgressiveMap;
   }

   if (BufferLotQty>0 && n>BufferLotQty)
   {
      useProgressiveMap = true;
      //gdebugB01 = useProgressiveMap;
   }
      
   int idx = useProgressiveMap ? n : 0;

   if(idx < size)
      return bufferMap[idx];

   return bufferMap[size - 1];
}

int ParseBufferMap(string bufferString)
{
   string parts[];
   int count = StringSplit(bufferString, ',', parts);

   if(count <= 0)
      return 0;

   ArrayResize(bufferMap, count);

   double minVal = DBL_MAX;
   gLastSmallestBufferIndex = -1;

   for(int i = 0; i < count; i++)
   {
      string s = parts[i];
      StringTrimLeft(s);
      StringTrimRight(s);

      if(s == "")
      {
         Print("Empty buffer value at index ", i);
         return 0;
      }

      double val = StringToDouble(s);

      // validation
      if(val < 0)
      {
         Print("Invalid (negative) buffer value at index ", i, ": ", s);
         return 0;
      }

      bufferMap[i] = val;

      if(val < minVal)
      {
         minVal = val;
         gLastSmallestBufferIndex = i;
      }
      else if(val == minVal)
      {
         gLastSmallestBufferIndex = i;
      }
   }

   return count;
}


// --- NEW 04.6: close ALL positions in current epoch (winner + loser)
// Also cancels pendings and fully resets ABWCL + anchor/range state.
void CloseAllEpochPositions()
{
   int closed   = 0;
   int canceled = 0;

   // ============================================================
   // CASE A: ABWCL is ARMED
   //   → close ONLY epoch positions (winner + loser)
   //   → KEEP:
   //       - pending orders
   //       - newcomer positions (non-epoch)
   //   → reset ONLY ABWCL core state, not anchor/range
   // ============================================================
   if(gABWCLArmed)
   {
      ulong tickets[];
      int n = 0;

      // Collect all current epoch positions by runtime test,
      // not by trusting the stored arrays.
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

         if(!IsEpochTicket(t))         // newcomer → skip
            continue;

         ArrayResize(tickets, n + 1);
         tickets[n++] = t;
      }

      if(n > 0)
         closed = dm.CloseAll(tickets);

      // DO NOT cancel pendings here.
      // DO NOT touch newcomers (we only collected epoch tickets).

      // Reset only ABWCL-core state, keep range/anchors and placement logic
      ResetABWCLCore(false);
      gABWCLWinnerSide = -1;

      ArrayResize(gEpochWinnerTickets, 0);
      ArrayResize(gEpochLoserTickets, 0);

      gArmTime        = 0;
      gEpochStartTime = 0;

      if(EnableDebugLogs)
         PrintFormat("[EPOCH-KILL] ARMED: closed %d epoch positions, "
                     "kept pendings/newcomers, reset ABWCL core.", closed);

      return;
   }

   // ============================================================
   // CASE B: ABWCL is NOT ARMED
   //   → full chain flush:
   //       - close ALL EA positions (symbol+magic)
   //       - cancel ALL EA pendings (symbol+magic)
   //       - hard reset ABWCL + range + anchors
   // ============================================================
   {
      ulong tickets[];
      int n = 0;

      for(int i = PositionsTotal()-1; i >= 0; --i)
      {
         ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            
         ArrayResize(tickets, n + 1);
         tickets[n++] = t;
      }

      if(n > 0)
         closed = dm.CloseAll(tickets);

      // Nuke all EA pendings on this symbol/magic
      //AGH_Rev_8_3
      canceled = CancelAllPending();

      // Hard reset of ABWCL, epoch, anchor range, placement
      ResetABWCLCore(false);
      ResetAnchorAndRange();

      if(EnableDebugLogs)
         PrintFormat("[EPOCH-KILL] UNARMED: closed %d positions, canceled %d pendings, "
                     "reset ABWCL/anchors.", closed);//, canceled);
   }
}

// --- NEW: reset only ABWCL core + epoch bookkeeping
void ResetABWCLCore(bool resetEpochCounter = false)
{
   // ABWCL core
   gABWCLArmed = false;
   gABWCL_SL_winner = 0.0;
   gABWCL_SL_loser = 0.0;
   gABWCLWinnerSide = -1;
   gArmedSL = 0.0;

   ArrayResize(gEpochWinnerTickets, 0);
   ArrayResize(gEpochLoserTickets, 0);

   gArmTime        = 0;
   gEpochStartTime = 0;

   if(resetEpochCounter)
      gArmEpoch = 0;

   if(EnableDebugLogs)
      Print("[RESET] ABWCL core/epoch state reset.");
}

// --- NEW: reset anchors, range cluster and placement state
void ResetAnchorAndRange()
{
   // anchor / range cluster
   gbuyEntry_range = 0.0;
   gsellEntry_range = 0.0;
   grange = 0.0;
   ClearRangeState();
   gbuyEntry = 0.0;
   gsellEntry = 0.0;
   
   gMarginUsedBufferLevel = MarginUsedBufferLevel;
   if(gMarginUsedBufferLevel == 0.0)
   {
      gMarginUsedBufferLevel =
         (AccountInfoDouble(ACCOUNT_BALANCE) - AccountInfoDouble(ACCOUNT_MARGIN)) /
         (LotSizeInput / gMinLot);
   }

   // cycle/state/placement
   gLastPlaceBar  = 0;      // so next bar/place gate is clean

   if(EnableDebugLogs)
      Print("[RESET] Anchor/range and placement state reset.");
}

void CloseCurrentRangeNonEpoch()
{
    ulong tickets[];
    int n = 0;

    for (int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong t = PositionGetTicket(i);
        if (!PositionSelectByTicket(t)) continue;
        if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if ((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

        // Skip epoch positions (these belong to ABWCL logic)
        if (IsEpochTicket(t)) continue;

        ArrayResize(tickets, n+1);
        tickets[n++] = t;
    }

    if (n > 0)
    {
        int closed = dm.CloseAll(tickets);
        if (EnableDebugLogs)
            PrintFormat("[CLOSE-RANGE] Closed %d non-epoch positions.", closed);
    }
}

// ============================================================
// Non-epoch list builder (sorted by open time ASC)
// ============================================================
void BuildAllListsSorted(PosLists &poslists)
{   
   ArrayResize(poslists.lstAll, 0);
   ArrayResize(poslists.lstWNSL, 0);
   ArrayResize(poslists.lstAllDeals, 0);
   double totalLot = 0;
   // Collect
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      PosSnap p;
      p.ticket    = t;
      p.type      = (int)PositionGetInteger(POSITION_TYPE);
      p.lots      = PositionGetDouble(POSITION_VOLUME);
      p.openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      p.openTime  = (datetime)PositionGetInteger(POSITION_TIME);
      p.profit    = PositionGetDouble(POSITION_PROFIT);
      p.sl        = PositionGetDouble(POSITION_SL);
      
      // Add to ALL DEALS (no filter)
      int nAllDeals = ArraySize(poslists.lstAllDeals);
      ArrayResize(poslists.lstAllDeals, nAllDeals + 1);
      poslists.lstAllDeals[nAllDeals] = p;
      totalLot += p.lots; 
      
      // Skip epoch for other lists
      if(IsEpochTicket(t)) continue;
      
      // Add to non-epoch ALL
      int nAll = ArraySize(poslists.lstAll);
      ArrayResize(poslists.lstAll, nAll + 1);
      poslists.lstAll[nAll] = p;
      
      // Add to non-epoch WNSL (no SL)
      if(p.sl <= 0)
      {
         int nWNSL = ArraySize(poslists.lstWNSL);
         ArrayResize(poslists.lstWNSL, nWNSL + 1);
         poslists.lstWNSL[nWNSL] = p;
      }
   }
   poslists.totalLot = totalLot;
}

void SortByOpenTime(PosSnap &arr[])
{
   int n = ArraySize(arr);
   for(int a = 0; a < n - 1; ++a)
      for(int b = a + 1; b < n; ++b)
         if(arr[b].openTime < arr[a].openTime)
         {
            PosSnap tmp = arr[a];
            arr[a] = arr[b];
            arr[b] = tmp;
         }
}

void SortByOpenTimeAscending(PosSnap &arr[])
{
   int n = ArraySize(arr);
   for(int a = 0; a < n - 1; ++a)
      for(int b = a + 1; b < n; ++b)
         if(arr[b].openTime < arr[a].openTime)
         {
            PosSnap tmp = arr[a];
            arr[a] = arr[b];
            arr[b] = tmp;
         }
}

void SortByOpenTimeDescending(PosSnap &arr[])
{
   int n = ArraySize(arr);
   for(int a = 0; a < n - 1; ++a)
      for(int b = a + 1; b < n; ++b)
         if(arr[b].openTime > arr[a].openTime)
         {
            PosSnap tmp = arr[a];
            arr[a] = arr[b];
            arr[b] = tmp;
         }
}

void SortByLotsAscending(PosSnap &arr[])
{
   int n = ArraySize(arr);

   for(int a = 0; a < n - 1; ++a)
      for(int b = a + 1; b < n; ++b)
      {
         if(arr[b].lots < arr[a].lots)
         {
            PosSnap tmp = arr[a];
            arr[a] = arr[b];
            arr[b] = tmp;
         }
      }
}

void SortByLotsDescending(PosSnap &arr[])
{
   int n = ArraySize(arr);

   for(int a = 0; a < n - 1; ++a)
      for(int b = a + 1; b < n; ++b)
      {
         if(arr[b].lots > arr[a].lots)
         {
            PosSnap tmp = arr[a];
            arr[a] = arr[b];
            arr[b] = tmp;
         }
      }
}

// rev6.5
void ExhaustBudgetCheck(PosLists &poslists,double currentorderprice, double currentorderlot, ENUM_ORDER_TYPE currentordertype)
{
   if(!UseBudgetExhaustion) return;
   int nWNSL = ArraySize(poslists.lstWNSL);
   int nAll = ArraySize(poslists.lstAll);
   
   /*double currentorderlot = 0.0;   
   double currentorderprice = 0.0;   
   ENUM_ORDER_TYPE currentordertype = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
      
         if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
         if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
         
         currentorderprice = OrderGetDouble(ORDER_PRICE_OPEN);
         currentorderlot  = OrderGetDouble(ORDER_VOLUME_CURRENT);
         currentordertype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      }*/
   
   double totalLot = 0.0;
   for(int i = 0; i < nWNSL; i++)
   {
      double lot = poslists.lstWNSL[i].lots;
      if(lot > 0.0)
         totalLot += lot;
   }

   if(ExhaustMaxOpenDeals > 0)
   {
      int openDealCount = ArraySize(poslists.lstAll);

      if(openDealCount >= ExhaustMaxOpenDeals || totalLot >= gMaxLot)
      {
         gBudgetExhausted = true;
         return;
      }
   }

   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   const double marginUsedNow = AccountInfoDouble(ACCOUNT_MARGIN);

   double budgetLimit = (AllowedEquity > 0.0) ? AllowedEquity : balance;

   if(budgetLimit <= 0.0)
   {
      gBudgetExhausted = true;
      return;
   }

   double marginUsagePercent = (marginUsedNow / budgetLimit) * 100.0;

//   if(marginUsagePercent < 60.0)
//      return;

   double buyLots = 0.0;
   double sellLots = 0.0;

   int nAllDeals = ArraySize(poslists.lstAllDeals);
   for(int i = 0; i < nAllDeals; i++)
   {
      int type = poslists.lstAllDeals[i].type;
      double lots = poslists.lstAllDeals[i].lots;

      if(type == POSITION_TYPE_BUY)
         buyLots += lots;
      else if(type == POSITION_TYPE_SELL)
         sellLots += lots;
   }
   double buyEntry = gbuyEntry_range;
   double sellEntry = gsellEntry_range;
   
   //ENUM_ORDER_TYPE ptype;
   //double nextLot = ComputeNextLotSizeINC_Rev8_1(ptype, gbuyEntry, gsellEntry, poslists);
   /*double nextLot = ComputeNextLotSizeINC_Rev8_2(ptype, buyEntry, sellEntry, poslists);

   if(nextLot < 0.0)
   {
      gBudgetExhausted = true;
      return;
   }*/

   if(currentordertype == ORDER_TYPE_BUY || currentordertype == ORDER_TYPE_BUY_LIMIT ||
    currentordertype == ORDER_TYPE_BUY_STOP || currentordertype == ORDER_TYPE_BUY_STOP_LIMIT)
      buyLots += currentorderlot;
   else if(currentordertype == ORDER_TYPE_SELL || currentordertype == ORDER_TYPE_SELL_LIMIT ||
    currentordertype == ORDER_TYPE_SELL_STOP || currentordertype == ORDER_TYPE_SELL_STOP_LIMIT)
      sellLots += currentorderlot;
   else
   {
      gBudgetExhausted = true;
      return;
   }

   double dominantAfter = MathAbs(buyLots - sellLots);

   ENUM_ORDER_TYPE marginTypeAfter = (buyLots >= sellLots ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);

   double px = ((marginTypeAfter == ORDER_TYPE_BUY)
                ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                : SymbolInfoDouble(_Symbol, SYMBOL_BID));

   double marginReqAfter = 0.0;
   bool okAfter = true;

   if(dominantAfter > 0.0)
      okAfter = OrderCalcMargin(marginTypeAfter, _Symbol, dominantAfter, px, marginReqAfter);

   if(!okAfter)
   {
      if(EnableDebugLogs)
         PrintFormat("[BUDGET] OrderCalcMargin failed. dominantAfter=%.4f px=%.2f",
                     dominantAfter, px);

      gBudgetExhausted = true;
      return;
   }

   if(marginReqAfter > budgetLimit)
   {
      gBudgetExhausted = true;

      if(EnableDebugLogs)
         PrintFormat("[BUDGET] Margin exhausted. FutureMargin: %.2f, Limit: %.2f, UsedNow: %.2f",
                     marginReqAfter, budgetLimit, marginUsedNow);

      return;
   }

   //AGH_REV_8_5
   if(currentorderlot >= gMaxLot)
     {
      gBudgetExhausted = true;
      return;
     }
   //AGH_REV_8_5

   double exhaustlottrigger = (LotSizeInput / gMinLot) * ExhaustMaxDealSize;
   if(ExhaustMaxDealSize > 0.0)
   {
      if( nWNSL > 0)
      {
         double lastWNSLLot = poslists.lstWNSL[nWNSL-1].lots;
         //if(lastWNSLLot >= exhaustlottrigger)
         if(currentorderlot >= exhaustlottrigger)
         {
            gBudgetExhausted = true;
            if(EnableDebugLogs)
               PrintFormat("[BUDGET] Deal size exhausted. WNSLCount=%d LastWNSLLot=%.2f Trigger=%.2f",
                           nWNSL,
                           lastWNSLLot,
                           exhaustlottrigger);
            return;
         }
      }
   }
   //AGH_REV_8_7
   
   if(EnableDebugLogs)
      PrintFormat("[BUDGET] Margin OK. FutureMargin: %.2f, Limit: %.2f, UsedNow: %.2f",
                  marginReqAfter, budgetLimit, marginUsedNow);
}
   
void ExhaustBudgetCheckEMGCY(PosLists &poslists,double currentorderprice, double currentorderlot, ENUM_ORDER_TYPE currentordertype, double floatingNet)
{
   if(!UseBudgetExhaustion) return;
   int nWNSL = ArraySize(poslists.lstWNSL);
   int nAll = ArraySize(poslists.lstAll);
   double totalLot = poslists.totalLot;
    
   double exhaustlottrigger_2 = (LotSizeInput / gMinLot) * ExhaustMaxDealSize_2;
   
   gBudgetCheckEMGCY = false;
   gdebugD01 = currentorderlot;
   gdebugD02 = exhaustlottrigger_2;
   gdebugD03 = floatingNet;
   
   if(ExhaustMaxDealSize_2 > 0.0)
   {
      if( currentorderlot > exhaustlottrigger_2)
      {
         gBudgetCheckEMGCY = true;
         gdebugD01 = currentorderlot;
         gdebugD02 = exhaustlottrigger_2;
         gdebugD03 = floatingNet;
         gdebugD04 = -1*nWNSL;
         
         //double lastWNSLLot = poslists.lstWNSL[nWNSL-1].lots;
         //if(lastWNSLLot >= exhaustlottrigger)
         if(currentorderlot >= exhaustlottrigger_2 && floatingNet >= -1*nWNSL)
            {
            FastCloseNonEpochFromEndToTarget(poslists, 0);
            CancelAllPending();
            ResetBudgetExhausted();
            ResetCompression();
            BuildAllListsSorted(poslists);
            Print(" L : ", __LINE__, " ", MagicNumber, " '-1*nWNSL' ",-1*nWNSL, " currentorderlot ",  currentorderlot," floatingNet ",DoubleToString(floatingNet, 2));  
            SendTelegramMessage(IntegerToString(MagicNumber) +
                        "Deal qty : " + IntegerToString(nAll) 
                        + ", MarginUsed: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN),0)
                        + ", currentorderlot: " + DoubleToString(currentorderlot,2)
                        );
            return;
            }
            
         if(ExhaustMaxOpenDeals_2 >0 && nWNSL >= ExhaustMaxOpenDeals_2 && floatingNet >= -2*nWNSL)
            {
            FastCloseNonEpochFromEndToTarget(poslists, 0);
            CancelAllPending();
            ResetBudgetExhausted();
            ResetCompression();
            BuildAllListsSorted(poslists);
            Print(" Line : ", __LINE__, " ", MagicNumber, " 'nWNSL' ", nWNSL, " '-2*nWNSL' ",-2*nWNSL, " currentorderlot ",  currentorderlot," floatingNet ",DoubleToString(floatingNet, 2));  
            SendTelegramMessage(IntegerToString(MagicNumber) +
                        "Deal qty : " + IntegerToString(nAll) 
                        + ", MarginUsed: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN),0)
                        + ", currentorderlot: " + DoubleToString(currentorderlot,2)
                        );
            return;
            }            
            
      }
   }
   
   double exhaustlottrigger_3 = (LotSizeInput / gMinLot) * ExhaustMaxDealSize_3;
   
   if(ExhaustMaxDealSize_3 > 0.0)
   {
      if( currentorderlot > exhaustlottrigger_3)
      {
         gBudgetCheckEMGCY = true;
         gdebugD01 = currentorderlot;
         gdebugD02 = exhaustlottrigger_3;
         gdebugD03 = floatingNet;
         gdebugD04 = -2*nWNSL;
         
         //double lastWNSLLot = poslists.lstWNSL[nWNSL-1].lots;
         //if(lastWNSLLot >= exhaustlottrigger)
         if(currentorderlot >= exhaustlottrigger_3 && floatingNet >= -2*nWNSL)
            {
            FastCloseNonEpochFromEndToTarget(poslists, 0);
            CancelAllPending();
            ResetBudgetExhausted();
            ResetCompression();
            BuildAllListsSorted(poslists);
            Print(" L: ", __LINE__, " ", MagicNumber, " '-2*nWNSL' ",-2*nWNSL, " currentorderlot ",  currentorderlot," floatingNet ",DoubleToString(floatingNet, 2));  
            SendTelegramMessage(IntegerToString(MagicNumber) +
                        "Deal qty : " + IntegerToString(nAll) 
                        + ", MarginUsed: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN),0)
                        + ", currentorderlot: " + DoubleToString(currentorderlot,2)
                        );
            return;
            }
            
         if(ExhaustMaxOpenDeals_2 >0 && nWNSL >= ExhaustMaxOpenDeals_2 && floatingNet >= -4*nWNSL)
            {
            FastCloseNonEpochFromEndToTarget(poslists, 0);
            CancelAllPending();
            ResetBudgetExhausted();
            ResetCompression();
            BuildAllListsSorted(poslists);
            Print(" Line : ", __LINE__, " ", MagicNumber, " 'nWNSL' ", nWNSL, " '-4*nWNSL' ",-4*nWNSL, " currentorderlot ",  currentorderlot," floatingNet ",DoubleToString(floatingNet, 2));  
            SendTelegramMessage(IntegerToString(MagicNumber) +
                        "Deal qty : " + IntegerToString(nAll) 
                        + ", MarginUsed: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN),0)
                        + ", currentorderlot: " + DoubleToString(currentorderlot,2)
                        );
            return;
            }            
            
      }
   }
   

   
   if(ExhaustMaxOpenDeals_2 >0 && nWNSL >= ExhaustMaxOpenDeals_2 )
   {
      if( totalLot > exhaustlottrigger_2)
      {
         gBudgetCheckEMGCY = true;
         gdebugD01 = currentorderlot;
         gdebugD02 = exhaustlottrigger_3;
         gdebugD03 = floatingNet;
         gdebugD04 = -1*nWNSL;
         
         //double lastWNSLLot = poslists.lstWNSL[nWNSL-1].lots;
         //if(lastWNSLLot >= exhaustlottrigger)
         if(totalLot > exhaustlottrigger_2 && floatingNet >= -1*nWNSL)
            {
            FastCloseNonEpochFromEndToTarget(poslists, 0);
            CancelAllPending();
            ResetBudgetExhausted();
            ResetCompression();
            BuildAllListsSorted(poslists);
            Print(" #LINE# : ", __LINE__, " ", MagicNumber, " '-1*nWNSL' ",-1*nWNSL, " totalLot ",  totalLot," floatingNet ",DoubleToString(floatingNet, 2));  
            SendTelegramMessage(IntegerToString(MagicNumber) +
                        "Deal qty : " + IntegerToString(nAll) 
                        + ", MarginUsed: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN),0)
                        + ", currentorderlot: " + DoubleToString(currentorderlot,2)
                        );
            return;
            }
            
         if(totalLot > exhaustlottrigger_3 && floatingNet >= -2*nWNSL)
            {
            FastCloseNonEpochFromEndToTarget(poslists, 0);
            CancelAllPending();
            ResetBudgetExhausted();
            ResetCompression();
            BuildAllListsSorted(poslists);
            Print(" #LINE# : ", __LINE__, " ", MagicNumber, " 'nWNSL' ", nWNSL, " '-2*nWNSL' ",-2*nWNSL, " totalLot ",  totalLot," floatingNet ",DoubleToString(floatingNet, 2));  
            SendTelegramMessage(IntegerToString(MagicNumber) +
                        "Deal qty : " + IntegerToString(nAll) 
                        + ", MarginUsed: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN),0)
                        + ", currentorderlot: " + DoubleToString(currentorderlot,2)
                        );
            return;
            }            
            
      }
   }
   
   /*if(ExhaustMaxDealSize > 0.0)
   {
      if( nWNSL > 0)
      {
         double lastWNSLLot = poslists.lstWNSL[nWNSL-1].lots;
         //if(lastWNSLLot >= exhaustlottrigger)
         if(nextLot >= exhaustlottrigger * 1.5)
         {
            gBudgetExhaustedLot = true;
            if(EnableDebugLogs)
               PrintFormat("[BUDGET] Deal size exhausted. WNSLCount=%d LastWNSLLot=%.2f Trigger=%.2f",
                           nWNSL,
                           lastWNSLLot,
                           exhaustlottrigger);
            return;
         }
      }
   }*/
   //AGH_REV_8_7
   
}
   
   
void ResetBudgetExhausted()
{
   //if(!gBudgetExhausted) return;
   gBudgetExhausted = false;

   if(EnableDebugLogs) Print("[BUD] RESET BudgetExhausted (compression triggered).");
}

void ResetCompression()
{
      gCompressionActive = false;
      gCompressionKeepTarget = 0;
      gCompressionProtectedSide = -1;
      gFirstNonEpochSideType = -1;
      ArrayResize(gEpochToCloseArray, 0);
      ArrayResize(gEpochWallToArray, 0);
}  
// ============================================================
// Compression core: close newest deals until keepTarget reached
// ============================================================
void FastCloseNonEpochFromEndToTarget(PosLists &poslists,int keepTarget)
{
   if(!gCompressionActive) return;   // <- critical

   //int n = ArraySize(lst);
   int n = ArraySize(poslists.lstAll);
   if(n <= keepTarget) return;
   //SortByLotsAscending(poslists.lstAll);

   for(int i=n-1; i >= keepTarget; --i)
   {
      ulong t = poslists.lstAll[i].ticket;
      bool ok = dm.FastClosePosition(t);
      Sleep(2);
      if(ok || !PositionSelectByTicket(t)) n--;
   }
}

// HandleDealsCompression Rev6.5
void HandleDealsCompression(PosLists &poslists, int keepTarget, int ProtectedSide, int winnerSide)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minStop = MinStopDistancePrice(_Symbol);
   int n = ArraySize(poslists.lstAll);
   int nAll = ArraySize(poslists.lstAll);
   double wallBuy  = AlignToTick(_Symbol, (bid - minStop ));
   double wallSell = AlignToTick(_Symbol, (ask + minStop ));
   if(nAll == 0) return;
   //int compressionThreshold = gLastSmallestBufferIndex + 2;
   int compressionThreshold = 5;
      
   bool anyFailed = false;
   
   if (nAll < compressionThreshold)
   {
      // Build two arrays: positions to close and positions to wall
      SetCompressionEpoch(poslists, keepTarget, ProtectedSide, winnerSide);
      
      int closeCount = ArraySize(gEpochToCloseArray);
      int wallCount = ArraySize(gEpochWallToArray);
      int maxIterations = MathMax(closeCount, wallCount);
      
      // Arrays are sorted descending by lot size,
      // so iterate forward to process biggest lots first.
      for(int idx = 0; idx < maxIterations; idx++)
      {
         // Add wall to one from wall array (if available)
         if(idx < wallCount)
         {
            ulong t = gEpochWallToArray[idx].ticket;
            if(!PositionSelectByTicket(t)) continue;
            
            int type = (int)PositionGetInteger(POSITION_TYPE);
            double wall = (type == POSITION_TYPE_BUY ? wallBuy : wallSell);
            
            bool addingwallok = UpdateSL(t, wall);
            if(!addingwallok)
            { 
               anyFailed = true;
               //AGH
               //PrintFormat("[COMP-WALL] UpdateSL failed for ticket=%I64u", t);
               break;
            }
         }
         
         // Close one from close array (if available)
         if(idx < closeCount)
         {
            ulong t = gEpochToCloseArray[idx].ticket;
            if(PositionSelectByTicket(t))
            {
               bool ok = dm.FastClosePosition(t);
               //AGH
               //if(!ok)
                  //PrintFormat("[COMP] FastClose failed for ticket=%I64u", t);
            }
         }
      }
      //AGH_Rev_8_3
      CancelAllPending();
   }
   
   else
   {
      // Build two arrays: positions to close and positions to wall
      SetCompressionEpoch(poslists, keepTarget, ProtectedSide, winnerSide);
      
      int closeCount = ArraySize(gEpochToCloseArray);
      int wallCount = ArraySize(gEpochWallToArray);
      int maxIterations = MathMax(closeCount, wallCount);
      
      // Arrays are sorted descending by lot size,
      // so iterate forward to process biggest lots first.
      for(int idx = 0; idx < maxIterations; idx++)
      {
         // Add wall to one from wall array (if available)
         if(idx < wallCount)
         {
            ulong t = gEpochWallToArray[idx].ticket;
            if(PositionSelectByTicket(t))
            {
               bool ok = dm.FastClosePosition(t);
               if(!ok)
                  PrintFormat("[COMP] FastClose failed for ticket=%I64u", t);
            }
         }
         
         // Close one from close array (if available)
         if(idx < closeCount)
         {
            ulong t = gEpochToCloseArray[idx].ticket;
            if(PositionSelectByTicket(t))
            {
               bool ok = dm.FastClosePosition(t);
               if(!ok)
                  PrintFormat("[COMP] FastClose failed for ticket=%I64u", t);
            }
         }
      }
      //AGH_Rev_8_3
      CancelAllPending();
   }

   if(anyFailed)
   {
      FastCloseNonEpochFromEndToTarget(poslists, keepTarget);
      //AGH_Rev_8_3
      CancelAllPending();
      ResetCompression();
      //Print("STEP 7: after reset ");
      //AGH
      //Print("FAIL TRIGGERED → compression reset L4291");
      if(EnableDebugLogs) Print("[COMP-WALL] FAIL -> killed NON-EPOCH cohort + exited compression");
   }
}

// --- Helper: snapshot current positions into compression epoch groups
void SetCompressionEpoch(PosLists &poslists, int keepTarget, int ProtectedSide, int winnerSide)
{
   ArrayResize(gEpochToCloseArray, 0);
   ArrayResize(gEpochWallToArray, 0);
   
   int n = ArraySize(poslists.lstAll);

   for(int i = n-1; i >= keepTarget; i--)
   {
      PosSnap p = poslists.lstAll[i];

      if(!PositionSelectByTicket(p.ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(IsEpochTicket(p.ticket)) continue;
      
      if(p.type != ProtectedSide)
      {
         int sz = ArraySize(gEpochToCloseArray);
         ArrayResize(gEpochToCloseArray, sz + 1);
         gEpochToCloseArray[sz] = p;
      }
      else
      {
         int sz2 = ArraySize(gEpochWallToArray);
         ArrayResize(gEpochWallToArray, sz2 + 1);
         gEpochWallToArray[sz2] = p;
      }
   }
      
   if(EnableDebugLogs)
      PrintFormat("[COMP-EPOCH] Total=%d, Keep=%d, ToClose=%d, ToWall=%d", 
                  n, keepTarget,
                  ArraySize(gEpochToCloseArray),
                  ArraySize(gEpochWallToArray));
}

// ============================================================
// Pending replacement: cancel+place if differs
// ============================================================
bool NearlyEqualVol(double a, double b)
{
   double step = gLotStep;
   if(step <= 0.0) step = 0.01;
   return (MathAbs(a-b) <= 0.5*step);
}
//AGH-to-be-check
bool NearlyEqualPrice(double a, double b, double spread)
{
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = _Point;
   return (MathAbs(a - b) <=  tick);
}

bool NearlyEqualPrice_archive(double a, double b, double spread)
{
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0) tick = _Point;
   //return (MathAbs(a-b) <= 0.5*tick);
   return (MathAbs(a-b) <= spread);
}

//+------------------------------------------------------------------+
//| EnterCompressionProtect                                          |
//| What it does:                                                    |
//|   • Starts compression once non-epoch deals reach threshold       |
//|   • Cancels pending immediately (compression takes control)       |
//|   • Determines keep target using:                                 |
//|       - first non-epoch deal side (locked)                        |
//|       - current toward breakout side (NOT locked forever)         |
//|   • Applies wall to winners                                       |
//|   • Closes from newest until keep target reached                  |
//|   • ONLY THEN refreshes pending (cancel+replace if differs)       |
//|   • Resets BudgetExhausted after compression actually reduces risk|
//+------------------------------------------------------------------+
void EnterCompressionProtect(PosLists &poslists)
{
   if(gCompressionActive) return;
   if(!UseCompressionProtect) return;
   //AGH_REV_8_6
   //if(gABWCLArmed) return; // compression is non-epoch only
   //AGH_REV_8_6
   
   //PosLists poslists;
   int nWSL = ArraySize(poslists.lstWNSL);   
   int nAll = ArraySize(poslists.lstAll);
   int nAllDeals = ArraySize(poslists.lstAllDeals);
   
   /*static int num = 0;
   num += 1;
   gdebug102 = StringFormat("ENTCOMP-%d", num);*/
   
   int n = nAll;
   SortByOpenTimeAscending(poslists.lstAll);

   if(n < CompressionStartDeals) return;
   gCompressionActive = true;

   // Lock FIRST non-epoch side at compression entry
   gFirstNonEpochSideType = poslists.lstAll[0].type;

   // Determine winner side by PROFIT, not position order
   double buyProfit = 0, sellProfit = 0;
   for(int i = 0; i < n; i++) {
      if(poslists.lstAll[i].type == POSITION_TYPE_BUY)  buyProfit  += poslists.lstAll[i].profit;
      if(poslists.lstAll[i].type == POSITION_TYPE_SELL) sellProfit += poslists.lstAll[i].profit;
   }
   
   // Winner = side with higher profit
   gCompressionProtectedSide = (buyProfit >= sellProfit ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
   
   // Lock first side ONCE at compression entry (not every manage call)
   if(gFirstNonEpochSideType == -1)
      gFirstNonEpochSideType = poslists.lstAll[0].type;
   
   // Compute keep target
   bool favorFirst = (gCompressionProtectedSide == gFirstNonEpochSideType);
   gCompressionKeepTarget = (favorFirst ? DealsKeepToward : DealsKeepAgainst);


   if(EnableDebugLogs)
      PrintFormat("[COMP] ENTER: nonEpoch=%d start=%d firstSide=%s towardNow=%s keepTarget=%d",
                  n, CompressionStartDeals,
                  (gFirstNonEpochSideType==POSITION_TYPE_BUY?"BUY":"SELL"));
}
//+------------------------------------------------------------------+
//| ManageCompressionProtect                                         |
//| What it does (runs while compression active):                     |
//|   • Rebuild non-epoch list (sorted)                               |
//|   • Re-evaluate toward/against side (resonance can flip)          |
//|   • Recompute keep target accordingly                             |
//|   • Apply wall to winners                                         |
//|   • Close from newest until keep target reached                   |
//|   • ONLY THEN refresh pending (cancel+replace if differs)         |
//|   • Exit compression when n <= keepTarget                         |
//|   • Reset BudgetExhausted when compression ends (user rule)       |
//+------------------------------------------------------------------+
void ManageCompressionProtect(PosLists &poslists)
{
   if(!gCompressionActive) return;
   
   int nWSL = ArraySize(poslists.lstWNSL);
   int nAll = ArraySize(poslists.lstAll);
   int nAllDeals = ArraySize(poslists.lstAllDeals);
      
   int n = nAll;
   SortByOpenTimeAscending(poslists.lstWNSL);
   SortByOpenTimeAscending(poslists.lstAll);
   SortByOpenTimeAscending(poslists.lstAllDeals);
   
   //double floatingNet = 0;
   //for(int i = 0; i < n; i++)
   //      floatingNet += poslists.lstAll[i].profit;
   
   double floatingNet = 0.0;

   for(int i = 0; i < nAll; i++)
   {
      floatingNet += poslists.lstAll[i].profit;
      if(gCommissionPerLot > 0.0)
            floatingNet -= gCommissionPerLot * poslists.lstAll[i].lots;
   }
   
   //gdebugD01 = floatingNet;
   //debug

   //if(floatingNet > 1)
   if(floatingNet > 0)
   {
      // Lock FIRST non-epoch side at compression entry
      gFirstNonEpochSideType = poslists.lstAll[0].type;
   
      // Determine winner side by PROFIT, not position order
      double buyProfit = 0, sellProfit = 0;
      for(int i = 0; i < nAll; i++) {
         if(poslists.lstAll[i].type == POSITION_TYPE_BUY)  buyProfit  += poslists.lstAll[i].profit;
         if(poslists.lstAll[i].type == POSITION_TYPE_SELL) sellProfit += poslists.lstAll[i].profit;
      }
      
      // Winner = side with higher profit
      gCompressionProtectedSide = (buyProfit >= sellProfit ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
      
      // Lock first side ONCE at compression entry (not every manage call)
      gFirstNonEpochSideType = poslists.lstAll[0].type;
   
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      if(poslists.lstAll[0].openPrice < bid)
      {
         if(gFirstNonEpochSideType == POSITION_TYPE_BUY && gCompressionProtectedSide == POSITION_TYPE_BUY)
            gCompressionKeepTarget = DealsKeepToward;
         else if(gFirstNonEpochSideType == POSITION_TYPE_BUY && gCompressionProtectedSide == POSITION_TYPE_SELL)
            gCompressionKeepTarget = DealsKeepToward;
         else if(gFirstNonEpochSideType == POSITION_TYPE_SELL && gCompressionProtectedSide == POSITION_TYPE_BUY)
            gCompressionKeepTarget = DealsKeepAgainst;
         else if(gFirstNonEpochSideType == POSITION_TYPE_SELL && gCompressionProtectedSide == POSITION_TYPE_SELL)
            //gCompressionKeepTarget = DealsKeepToward;
            //AGH_REV_5_6
            gCompressionKeepTarget = DealsKeepAgainst;
      }
      else if(poslists.lstAll[0].openPrice > ask)
      {
         if(gFirstNonEpochSideType == POSITION_TYPE_SELL && gCompressionProtectedSide == POSITION_TYPE_SELL)
            gCompressionKeepTarget = DealsKeepToward;
         else if(gFirstNonEpochSideType == POSITION_TYPE_SELL && gCompressionProtectedSide == POSITION_TYPE_BUY)
            gCompressionKeepTarget = DealsKeepToward;
         else if(gFirstNonEpochSideType == POSITION_TYPE_BUY && gCompressionProtectedSide == POSITION_TYPE_SELL)
            gCompressionKeepTarget = DealsKeepAgainst;
         else if(gFirstNonEpochSideType == POSITION_TYPE_BUY && gCompressionProtectedSide == POSITION_TYPE_BUY)
            //gCompressionKeepTarget = DealsKeepToward;
            //AGH_REV_5_6
            gCompressionKeepTarget = DealsKeepAgainst;
      }
      else
      {
         gCompressionKeepTarget =
            (gFirstNonEpochSideType == gCompressionProtectedSide)
            ? DealsKeepToward
            : DealsKeepAgainst;
      }

         // ALWAYS check exit condition FIRST
      if(n <= gCompressionKeepTarget && gCompressionActive)
      {
         ResetCompression();
         return;
      }
      
      // === Verify: deals being CLOSED have enough profit ===
      double closureProfit = 0;
      for(int i = nAll - 1; i >= gCompressionKeepTarget; i--)
      {
         closureProfit += poslists.lstAll[i].profit;  // sum profit of deals that will be closed
         if(gCommissionPerLot > 0.0)
               closureProfit -= gCommissionPerLot * poslists.lstAll[i].lots;
      }
   
      if(closureProfit < 3-nAll)
      {
         return;
      }
   
      HandleDealsCompression(poslists, gCompressionKeepTarget, gCompressionProtectedSide, gCompressionProtectedSide);
      ResetCompression();
      BuildAllListsSorted(poslists);
      //AGH_Rev_8_3
      //CancelAllPending();
      // if wall failed and disabled compression → stop now
      if(!gCompressionActive)
         return;

   }
}
//+------------------------------------------------------------------+
//| SetTelegramRoute
//+------------------------------------------------------------------+

void SetTelegramRoute()
{
   bool isDemo = (AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO);
   string s = _Symbol;

   topic_id = ""; // reset

   for(int i = 0; i < ArraySize(routes); i++)
   {
      if(StringFind(s, routes[i].symbolKey) >= 0)
      {
         topic_id = isDemo ? routes[i].demoTopic : routes[i].liveTopic;
         break;
      }
   }

   // fallback
   if(topic_id == "")
      topic_id = isDemo ? "99" : "199";
}

void SendTelegramMessage(string text)
{
   if(topic_id == "")
   {
      Print("ERROR: topic_id not set");
      return;
   }

   string safeText = UrlEncode(text);

   string url = "https://api.telegram.org/bot" + botToken + "/sendMessage";
   string data = "chat_id=" + group_id +
                 "&message_thread_id=" + topic_id +
                 "&text=" + safeText;

   char post[];
   StringToCharArray(data, post);

   char result[];
   string headers;

   int res = WebRequest("POST", url, "", "", 5000, post, ArraySize(post), result, headers);

   if(res == -1)
      Print("WebRequest failed. Error: ", GetLastError());
}

string UrlEncode(string str)
{
   string encoded = "";
   uchar c;

   for(int i = 0; i < StringLen(str); i++)
   {
      c = (uchar)StringGetCharacter(str, i);

      // Unreserved characters (no encoding needed)
      if((c >= 'A' && c <= 'Z') ||
         (c >= 'a' && c <= 'z') ||
         (c >= '0' && c <= '9') ||
         c == '-' || c == '_' || c == '.' || c == '~')
      {
         encoded += CharToString(c);
      }
      else
      {
         encoded += "%" + StringFormat("%02X", c);
      }
   }

   return encoded;
}

//+------------------------------------------------------------------+
//| Calculate Resonance                                              |
//+------------------------------------------------------------------+
void CalculateResonance(double &prices[], int size)
{
   if(size < 3)
   {
      resonanceScore = 0;
      resonanceRange = 0;
      resonanceDirection = "NONE";
      resonanceType = "";
      return;
   }
   
   double P1 = prices[0];
   double PN = prices[size - 1];
   
   // Calculate range (max - min)
   double maxPrice = prices[0];
   double minPrice = prices[0];
   
   for(int i = 1; i < size; i++)
   {
      if(prices[i] > maxPrice) maxPrice = prices[i];
      if(prices[i] < minPrice) minPrice = prices[i];
   }
   
   resonanceRange = maxPrice - minPrice;
   
   if(resonanceRange == 0)
   {
      resonanceScore = 0;
      resonanceDirection = "FLAT";
      resonanceType = "FLAT";
      return;
   }
   
   // Find extreme point and its location
   double maxDistance = 0;
   int extremeIdx = 0;
   
   for(int i = 0; i < size; i++)
   {
      double distance = MathAbs(prices[i] - P1);
      if(distance > maxDistance)
      {
         maxDistance = distance;
         extremeIdx = i;
      }
   }
   
   double P_extreme = prices[extremeIdx];
   double extremePosition = (double)extremeIdx / (double)size;  // 0.0 to 1.0
   
   // Check reversal
   double directionStart = P_extreme - P1;
   double directionEnd = PN - P_extreme;
   bool isReversal = (directionStart * directionEnd) < 0;
   
   // Calculate score
   double penetration = MathAbs(P_extreme - P1);
   double recovery = MathAbs(PN - P_extreme);
   double totalMovement = penetration + recovery;
   double netMovement = MathAbs(PN - P1);
   
   if(totalMovement == 0)
   {
      resonanceScore = 0;
      resonanceDirection = "FLAT";
      resonanceType = "FLAT";
      return;
   }
   
   double returnRatio = 1.0 - (netMovement / totalMovement);
   resonanceScore = returnRatio * 100.0;
   
   // Determine direction (first 30% vs last 30%)
   int sectionSize = size * 3 / 10;  // 30% of window
   if(sectionSize < 1) sectionSize = 1;
   if(sectionSize > size) sectionSize = size;
   
   double firstSection = 0;
   double lastSection = 0;
   
   for(int i = 0; i < sectionSize; i++)
   {
      firstSection += prices[i];
   }
   firstSection = firstSection / sectionSize;
   
   for(int i = size - sectionSize; i < size; i++)
   {
      lastSection += prices[i];
   }
   lastSection = lastSection / sectionSize;
   
   // Classify type: TRENDING, RANGING, or REVERSED
   if(resonanceScore < 30)
   {
      // Low score = trending
      resonanceType = "TRENDING";
      
      if(lastSection > firstSection)
         resonanceDirection = "TREND UP";
      else if(lastSection < firstSection)
         resonanceDirection = "TREND DOWN";
      else
         resonanceDirection = "FLAT";
   }
   else
   {
      // High score = either RANGING or REVERSED
      
      // Check if extreme was early (first 60%)
      bool extremeWasEarly = extremePosition < 0.6;
      
      // Check if range is small (ranging) or large (reversed)
      // Small range = less than 0.5% of current price
      double rangePercent = (resonanceRange / PN) * 100.0;
      bool smallRange = rangePercent < 0.5;
      
      if(smallRange || !extremeWasEarly)
      {
         resonanceType = "RANGING";
         resonanceDirection = "RANGING";
      }
      else
      {
         resonanceType = "REVERSED";
         
         if(lastSection > firstSection)
            resonanceDirection = "UP";
         else
            resonanceDirection = "DOWN";
      }
   }
}

double GetSymbolCommissionPerLot(const string sym)
{
   if(sym == "XAUUSD" || sym == "XAUUSD+")
      return 6.0;
   if(sym == "AUDUSD" || sym == "AUDUSD+")
      return 6.0;
   if(sym == "AUDUSD" || sym == "AUDUSD+")
      return 6.0;

   return 0.0;
}

int GetTimeframeCode(ENUM_TIMEFRAMES tf)
{
   int tfCode = (int)tf;

   if(tfCode > 0)
      return tfCode;

   return 0;
}

int GetSymbolCode_old(const string sym)
{
   if(sym == "XAUUSD" || sym == "XAUUSD+") return 101;
   if(sym == "BTCUSD" || sym == "BTCUSD+") return 102;
   if(sym == "DJ30") return 103;
   if(sym == "UKOUSD") return 104;
   return 999;
}

int GetSymbolCode(const string sym)
{
   string s = sym;

   StringToUpper(s);

   if(StringLen(s) > 0 && StringGetCharacter(s, StringLen(s) - 1) == '+')
      s = StringSubstr(s, 0, StringLen(s) - 1);

   int code = 0;

   for(int i = 0; i < StringLen(s); i++)
      code += StringGetCharacter(s, i);

   return 100 + (code % 900);
}

int BuildMagicNumber(const string sym, ENUM_TIMEFRAMES tf)
{
   return GetSymbolCode(sym) * 100000 + GetTimeframeCode(tf);
}
