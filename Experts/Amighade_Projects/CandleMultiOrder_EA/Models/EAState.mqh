//+------------------------------------------------------------------+
//| EAState.mqh                                                       |
//| All global state variables, structs, position list functions     |
//| DealManager class converted to plain DM_* functions             |
//+------------------------------------------------------------------+
#ifndef CMO_EA_STATE_MQH
#define CMO_EA_STATE_MQH

#include "../Inputs.mqh"

//+------------------------------------------------------------------+
//| STRUCTS                                                           |
//+------------------------------------------------------------------+

struct DealRecord
{
   ulong    ticket;
   string   symbol;
   long     type;
   double   lots;
   double   openPrice;
   datetime openTime;
   double   profit;
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
   PosSnap lstAll[];       // Non-epoch open positions
   PosSnap lstWNSL[];      // Non-epoch positions without SL
   PosSnap lstAllDeals[];  // All open positions including epoch
};

//+------------------------------------------------------------------+
//| GLOBAL STATE VARIABLES                                            |
//+------------------------------------------------------------------+

ulong  MagicNumber              = 0;
double gCommissionPerLot        = 0.0;
double gArmedSL                 = 0.0;
double gMinLot                  = 0.0;
double gMaxLot                  = 0.0;
double gLotStep                 = 0.0;
double gTickSize                = 0.0;
double gTickValue               = 0.0;
double gPoint                   = 0.0;
double gMarginUsedBufferLevel   = 0.0;

// Candle data buffers (filled by CandleUtils)
int    gCandleHandle            = INVALID_HANDLE;
double gOpenBuf[];
double gHighBuf[];
double gLowBuf[];
double gCloseBuf[];

// ABWCL epoch state
int    gArmEpoch                = 0;
int    gABWCLWinnerSide         = -1;
ulong  gEpochWinnerTickets[];
ulong  gEpochLoserTickets[];
double gABWCL_SL_winner         = 0.0;
double gABWCL_SL_loser          = 0.0;
bool   gABWCLArmed              = false;
double gABWCLSLbuy              = 0.0;
double gABWCLSLsell             = 0.0;
datetime gArmTime               = 0;
datetime gEpochStartTime        = 0;

// Compression epoch arrays
PosSnap gEpochToCloseArray[];
PosSnap gEpochWallToArray[];

// Compression state
bool   gCompressionActive        = false;
int    gCompressionKeepTarget    = 0;
int    gCompressionProtectedSide = -1;
int    gFirstNonEpochSideType    = -1;

// Budget state
bool   gBudgetExhausted         = false;

// Entry anchors
double gbuyEntry                = 0.0;
double gsellEntry               = 0.0;
double gbuyEntry_range          = 0.0;
double gsellEntry_range         = 0.0;
double grange                   = 0.0;

// Timing / debounce
datetime gLastTxTime            = 0;
datetime gLastPlaceBar          = 0;

// Buffer map (parsed from BaseBufferPrice input)
double bufferMap[];
int    gLastSmallestBufferIndex = -1;

// Resonance
double priceWindow[];
int    windowCount              = 0;
double resonanceScore           = 0;
double resonanceRange           = 0;
string resonanceDirection       = "NONE";
string resonanceType            = "";

// Fill mode (detected at OnInit by TradeUtils)
ENUM_ORDER_TYPE_FILLING gFillMode = ORDER_FILLING_IOC;

// Telegram routing
string botToken  = "8662430168:AAGwgNPnRwdCZpn9wDQKi25S43s0_vaVs4Y";
string chatID    = "111902083";
string group_id  = "-1003742587639";
string topic_id  = "";

// Debug helpers (set from any engine, read by DebugLogger)
bool   gdebugB01 = false;
int    gdebugI01 = 0;
int    gdebugI02 = 0;
int    gdebugI03 = 0;
double gdebugD01 = 0;
double gdebugD02 = 0;
double gdebugD03 = 0;
double gdebugD04 = 0;
string gdebugS01 = "";

//+------------------------------------------------------------------+
//| EPOCH HELPERS                                                     |
//+------------------------------------------------------------------+

bool IsEpochTicket(ulong t)
{
   for(int i = 0; i < ArraySize(gEpochWinnerTickets); ++i)
      if(gEpochWinnerTickets[i] == t) return true;
   for(int i = 0; i < ArraySize(gEpochLoserTickets); ++i)
      if(gEpochLoserTickets[i] == t) return true;
   return false;
}

bool AllClosed(ulong &tickets[])
{
   for(int i = 0; i < ArraySize(tickets); i++)
      if(PositionSelectByTicket(tickets[i])) return false;
   return true;
}

//+------------------------------------------------------------------+
//| POSITION LIST BUILDER                                             |
//+------------------------------------------------------------------+

void BuildAllListsSorted(PosLists &poslists)
{
   ArrayResize(poslists.lstAll,      0);
   ArrayResize(poslists.lstWNSL,     0);
   ArrayResize(poslists.lstAllDeals, 0);

   for(int i = PositionsTotal()-1; i >= 0; --i)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))                               continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)            continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      PosSnap p;
      p.ticket    = t;
      p.type      = (int)PositionGetInteger(POSITION_TYPE);
      p.lots      = PositionGetDouble(POSITION_VOLUME);
      p.openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      p.openTime  = (datetime)PositionGetInteger(POSITION_TIME);
      p.profit    = PositionGetDouble(POSITION_PROFIT);
      p.sl        = PositionGetDouble(POSITION_SL);

      int nAD = ArraySize(poslists.lstAllDeals);
      ArrayResize(poslists.lstAllDeals, nAD+1);
      poslists.lstAllDeals[nAD] = p;

      if(IsEpochTicket(t)) continue;

      int nAll = ArraySize(poslists.lstAll);
      ArrayResize(poslists.lstAll, nAll+1);
      poslists.lstAll[nAll] = p;

      if(p.sl <= 0)
        {
         int nWNSL = ArraySize(poslists.lstWNSL);
         ArrayResize(poslists.lstWNSL, nWNSL+1);
         poslists.lstWNSL[nWNSL] = p;
        }
     }
}

//+------------------------------------------------------------------+
//| SORTING                                                           |
//+------------------------------------------------------------------+

void SortByOpenTimeAscending(PosSnap &arr[])
{
   int n = ArraySize(arr);
   for(int a = 0; a < n-1; ++a)
      for(int b = a+1; b < n; ++b)
         if(arr[b].openTime < arr[a].openTime)
           { PosSnap tmp = arr[a]; arr[a] = arr[b]; arr[b] = tmp; }
}

void SortByOpenTimeDescending(PosSnap &arr[])
{
   int n = ArraySize(arr);
   for(int a = 0; a < n-1; ++a)
      for(int b = a+1; b < n; ++b)
         if(arr[b].openTime > arr[a].openTime)
           { PosSnap tmp = arr[a]; arr[a] = arr[b]; arr[b] = tmp; }
}

void SortByLotsAscending(PosSnap &arr[])
{
   int n = ArraySize(arr);
   for(int a = 0; a < n-1; ++a)
      for(int b = a+1; b < n; ++b)
         if(arr[b].lots < arr[a].lots)
           { PosSnap tmp = arr[a]; arr[a] = arr[b]; arr[b] = tmp; }
}

void SortByLotsDescending(PosSnap &arr[])
{
   int n = ArraySize(arr);
   for(int a = 0; a < n-1; ++a)
      for(int b = a+1; b < n; ++b)
         if(arr[b].lots > arr[a].lots)
           { PosSnap tmp = arr[a]; arr[a] = arr[b]; arr[b] = tmp; }
}

//+------------------------------------------------------------------+
//| DM_* FUNCTIONS (replaces DealManager class)                      |
//+------------------------------------------------------------------+

int DM_Count(int typeFilter = -1)
{
   int cnt = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(typeFilter != -1 && (int)PositionGetInteger(POSITION_TYPE) != typeFilter) continue;
      cnt++;
     }
   return cnt;
}

double DM_Lots(int typeFilter = -1)
{
   double sum = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(typeFilter != -1 && (int)PositionGetInteger(POSITION_TYPE) != typeFilter) continue;
      sum += PositionGetDouble(POSITION_VOLUME);
     }
   return sum;
}

double DM_AvgEntry(int typeFilter = -1)
{
   double sumPrice = 0, sumLots = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(typeFilter != -1 && (int)PositionGetInteger(POSITION_TYPE) != typeFilter) continue;
      double lot = PositionGetDouble(POSITION_VOLUME);
      sumPrice += PositionGetDouble(POSITION_PRICE_OPEN) * lot;
      sumLots  += lot;
     }
   return (sumLots > 0) ? sumPrice / sumLots : 0.0;
}

double DM_NetProfit(int typeFilter = -1)
{
   double sum = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(typeFilter != -1 && (int)PositionGetInteger(POSITION_TYPE) != typeFilter) continue;
      sum += PositionGetDouble(POSITION_PROFIT);
     }
   return sum;
}

long DM_LastPositionType()
{
   long     lastType = -1;
   datetime latest   = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      if(ot > latest) { latest = ot; lastType = PositionGetInteger(POSITION_TYPE); }
     }
   return lastType;
}

int DM_CountUnprotected(int typeFilter = -1)
{
   int cnt = 0;
   for(int i = PositionsTotal()-1; i >= 0; --i)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(typeFilter != -1 && (int)PositionGetInteger(POSITION_TYPE) != typeFilter) continue;
      if(PositionGetDouble(POSITION_SL) <= 0.0) cnt++;
     }
   return cnt;
}

int CountNonEpochPositions(int typeFilter = -1)
{
   int cnt = 0;
   for(int i = PositionsTotal()-1; i >= 0; --i)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(typeFilter != -1 && (int)PositionGetInteger(POSITION_TYPE) != typeFilter) continue;
      if(!IsEpochTicket(t)) cnt++;
     }
   return cnt;
}

#endif
