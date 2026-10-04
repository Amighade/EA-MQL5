// Optional observations only: no trade requests or changes to GridState.
#ifndef FAILURE_DIAGNOSTICS_MQH
#define FAILURE_DIAGNOSTICS_MQH
#include "../Inputs.mqh"
#include "../Models/GridState.mqh"

#define DIAG_TRADE_CAPACITY 128
#define DIAG_GROUP_CAPACITY 128

struct DiagnosticTrade
{
   MqlTradeRequest request;
   MqlTradeResult result;
   MqlTick quote;
   string symbol;
   bool sent;
   int error;
   long stops;
   long freeze;
   double point;
   double tickSize;
   ulong startMs;
   ulong elapsedUs;
   int attempt;
   int widenStep;
   double originalEntry;
   double candidateSL;
   double adjustedSL;
   double oldSL;
};
struct DiagnosticGroup
{
   string key;
   string latest;
   ulong repeats;
   ulong lastPrintMs;
};
DiagnosticTrade g_diagTrades[DIAG_TRADE_CAPACITY];
int g_diagTradeCount = 0;
ulong g_diagTradeOverflow = 0;
DiagnosticGroup g_diagGroups[DIAG_GROUP_CAPACITY];
int g_diagGroupNext = 0;
int g_diagMagic = 0;
string g_diagLastSafetyReason = "none";
int g_diagAttempt = 0;
int g_diagWidenStep = 0;
double g_diagOriginalEntry = 0;
ulong g_diagSLTicket = 0;
double g_diagCandidateSL = 0;
double g_diagAdjustedSL = 0;
double g_diagOldSL = 0;

void FailureDiagnosticsLog(string key, string detail)
{
   if(!InpEnableFailureDiagnostics) return;
   ulong now = GetTickCount64();
   int slot = -1;
   for(int i = 0; i < DIAG_GROUP_CAPACITY; i++)
      if(g_diagGroups[i].key == key) { slot = i; break; }
   if(slot < 0)
   {
      slot = g_diagGroupNext;
      g_diagGroupNext = (g_diagGroupNext + 1) % DIAG_GROUP_CAPACITY;
      if(g_diagGroups[slot].repeats > 0)
         PrintFormat("[DIAG REPEAT] count=%I64u %s", g_diagGroups[slot].repeats,
                     g_diagGroups[slot].latest);
      g_diagGroups[slot].key = key;
      g_diagGroups[slot].latest = detail;
      g_diagGroups[slot].repeats = 0;
      g_diagGroups[slot].lastPrintMs = now;
      Print(detail);
      return;
   }
   g_diagGroups[slot].latest = detail;
   g_diagGroups[slot].repeats++;
}

void FailureDiagnosticsRepeats(bool force = false)
{
   if(!InpEnableFailureDiagnostics) return;
   ulong now = GetTickCount64();
   for(int i = 0; i < DIAG_GROUP_CAPACITY; i++)
      if(g_diagGroups[i].repeats > 0 &&
         (force || now - g_diagGroups[i].lastPrintMs >= 10000))
      {
         PrintFormat("[DIAG REPEAT] count=%I64u %s", g_diagGroups[i].repeats,
                     g_diagGroups[i].latest);
         g_diagGroups[i].repeats = 0;
         g_diagGroups[i].lastPrintMs = now;
      }
}

void FailureDiagnosticsAttempt(int attempt, int widenStep, double originalEntry)
{
   if(!InpEnableFailureDiagnostics) return;
   g_diagAttempt = attempt;
   g_diagWidenStep = widenStep;
   g_diagOriginalEntry = originalEntry;
}

void FailureDiagnosticsSLContext(ulong ticket, double candidate, double adjusted)
{
   if(!InpEnableFailureDiagnostics) return;
   g_diagSLTicket = ticket;
   g_diagCandidateSL = candidate;
   g_diagAdjustedSL = adjusted;
   // The caller has already selected this position; do not select another one.
   g_diagOldSL = PositionGetDouble(POSITION_SL);
}

// With diagnostics off this is exactly one unchanged native OrderSend call.
// With diagnostics on, copy the outcome immediately and render it after the task.
bool FailureDiagnosticsOrderSend(MqlTradeRequest &request, MqlTradeResult &result)
{
   if(!InpEnableFailureDiagnostics) return OrderSend(request, result);
   DiagnosticTrade event;
   event.request = request;
   event.symbol = (request.symbol == "") ? _Symbol : request.symbol;
   ZeroMemory(event.quote);
   SymbolInfoTick(event.symbol, event.quote);
   event.stops = SymbolInfoInteger(event.symbol, SYMBOL_TRADE_STOPS_LEVEL);
   event.freeze = SymbolInfoInteger(event.symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   event.point = SymbolInfoDouble(event.symbol, SYMBOL_POINT);
   event.tickSize = SymbolInfoDouble(event.symbol, SYMBOL_TRADE_TICK_SIZE);
   event.attempt = (request.action == TRADE_ACTION_PENDING ||
                    request.action == TRADE_ACTION_SLTP ||
                    request.action == TRADE_ACTION_DEAL) ? g_diagAttempt : 0;
   event.widenStep = (request.action == TRADE_ACTION_PENDING) ? g_diagWidenStep : 0;
   event.originalEntry = (request.action == TRADE_ACTION_PENDING) ? g_diagOriginalEntry : 0;
   event.candidateSL = 0;
   event.adjustedSL = 0;
   event.oldSL = 0;
   if(request.action == TRADE_ACTION_SLTP && request.position == g_diagSLTicket)
   {
      event.candidateSL = g_diagCandidateSL;
      event.adjustedSL = g_diagAdjustedSL;
      event.oldSL = g_diagOldSL;
   }
   event.startMs = GetTickCount64();
   ulong startUs = GetMicrosecondCount();
   bool sent = OrderSend(request, result);
   int error = GetLastError(); // Capture before any diagnostic rendering/API lookup.
   event.elapsedUs = GetMicrosecondCount() - startUs;
   event.sent = sent;
   event.error = error;
   event.result = result;
   if(g_diagTradeCount < DIAG_TRADE_CAPACITY)
      g_diagTrades[g_diagTradeCount++] = event;
   else
      g_diagTradeOverflow++;
   return sent;
}

void FailureDiagnosticsTrades()
{
   if(!InpEnableFailureDiagnostics) return;
   for(int i = 0; i < g_diagTradeCount; i++)
   {
      DiagnosticTrade event = g_diagTrades[i];
      bool accepted = event.sent &&
         (event.result.retcode == TRADE_RETCODE_DONE ||
          event.result.retcode == TRADE_RETCODE_DONE_PARTIAL ||
          event.result.retcode == TRADE_RETCODE_PLACED ||
          event.result.retcode == TRADE_RETCODE_NO_CHANGES);
      string key = StringFormat("TRADE:%s:%d:%d:%s:%I64u:%I64u:%u",
         accepted ? "accepted" : "failed", (int)event.request.action,
         (int)event.request.type, event.symbol, event.request.order,
         event.request.position, event.result.retcode);
      string detail = StringFormat(
         "[DIAG TRADE] outcome=%s symbol=%s action=%s type=%s requestMagic=%I64u eaMagic=%d "
         "order=%I64u position=%I64u price=%.8f volume=%.8f sl=%.8f tp=%.8f "
         "sent=%s retcode=%u comment=%s error=%d resultOrder=%I64u resultDeal=%I64u "
         "startTickMs=%I64u elapsedMs=%.3f BidBefore=%.8f AskBefore=%.8f quoteTimeMs=%I64d "
         "stopsPoints=%I64d freezePoints=%I64d point=%.8f tickSize=%.8f "
         "attempt=%d widenStep=%d originalEntry=%.8f candidateSL=%.8f adjustedSL=%.8f oldSL=%.8f",
         accepted ? "accepted-result" : "failed-result", event.symbol,
         EnumToString(event.request.action), EnumToString(event.request.type),
         event.request.magic, g_diagMagic, event.request.order, event.request.position,
         event.request.price, event.request.volume, event.request.sl, event.request.tp,
         event.sent ? "true" : "false", event.result.retcode, event.result.comment,
         event.error, event.result.order, event.result.deal, event.startMs,
         (double)event.elapsedUs / 1000.0, event.quote.bid, event.quote.ask,
         event.quote.time_msc, event.stops, event.freeze, event.point, event.tickSize,
         event.attempt, event.widenStep, event.originalEntry,
         event.candidateSL, event.adjustedSL, event.oldSL);
      FailureDiagnosticsLog(key, detail);
   }
   g_diagTradeCount = 0;
   if(g_diagTradeOverflow > 0)
   {
      PrintFormat("[DIAG] trade snapshot buffer overflow: %I64u records omitted; trading unchanged",
                  g_diagTradeOverflow);
      g_diagTradeOverflow = 0;
   }
}

void FailureDiagnosticsBrokerCounts(int magic, int &positions, int &orders)
{
   positions = 0; orders = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == magic) positions++;
   }
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         OrderGetInteger(ORDER_MAGIC) == magic) orders++;
   }
}

void FailureDiagnosticsSafety(GridState &state, string reason, string stage)
{
   if(!InpEnableFailureDiagnostics) return;
   int positions, orders;
   FailureDiagnosticsBrokerCounts(state.magicNumber, positions, orders);
   g_diagLastSafetyReason = reason;
   FailureDiagnosticsLog(StringFormat("SAFETY:%s:%s:%d:%d", stage, reason, positions, orders),
      StringFormat("[DIAG SAFETY] stage=%s reason=%s symbol=%s magic=%d "
                   "positions=%d orders=%d gridPlaced=%s cycleActive=%s cleanupInProgress=%s",
         stage, reason, _Symbol, state.magicNumber, positions, orders,
         state.gridPlaced ? "true" : "false", state.cycleActive ? "true" : "false",
         state.cleanupInProgress ? "true" : "false"));
}

void FailureDiagnosticsBuild(GridState &state)
{
   if(!InpEnableFailureDiagnostics) return;
   FailureDiagnosticsLog("BUILD:" + g_diagLastSafetyReason,
      StringFormat("[DIAG BUILD] permitted-by-existing-code symbol=%s magic=%d "
                   "gridPlaced=%s cycleActive=%s cleanupInProgress=%s sessionAllowed=%s lastSafetyReason=%s",
         _Symbol, state.magicNumber, state.gridPlaced ? "true" : "false",
         state.cycleActive ? "true" : "false", state.cleanupInProgress ? "true" : "false",
         state.sessionAllowed ? "true" : "false", g_diagLastSafetyReason));
}

void FailureDiagnosticsVerify(GridState &state, int level, double buyPrice,
                              double sellPrice, double lot, bool buyFound, bool sellFound)
{
   if(!InpEnableFailureDiagnostics) return;
   string actual = "";
   string tickets = "";
   int positions, orders;
   FailureDiagnosticsBrokerCounts(state.magicNumber, positions, orders);
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || OrderGetString(ORDER_SYMBOL) != _Symbol ||
         OrderGetInteger(ORDER_MAGIC) != state.magicNumber) continue;
      tickets += StringFormat(":%I64u", ticket);
      actual += StringFormat(" {ticket=%I64u type=%s price=%.8f volume=%.8f sl=%.8f}",
         ticket, EnumToString((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)),
         OrderGetDouble(ORDER_PRICE_OPEN), OrderGetDouble(ORDER_VOLUME_CURRENT),
         OrderGetDouble(ORDER_SL));
   }
   FailureDiagnosticsLog(StringFormat("VERIFY:%d:%d:%d:%d:%d", level,
         (int)buyFound, (int)sellFound, positions, orders) + tickets,
      StringFormat("[DIAG VERIFY] FAILED symbol=%s magic=%d level=%d "
                   "expectedBuy=%.8f expectedSell=%.8f expectedLot=%.8f priceTolerance=%.8f "
                   "buyFound=%s sellFound=%s positions=%d orders=%d actualOrders=%s "
                   "note=existing-verifier-checks-price-presence-not-lot",
         _Symbol, state.magicNumber, level, buyPrice, sellPrice, lot, InpGridSpacing,
         buyFound ? "true" : "false", sellFound ? "true" : "false", positions, orders,
         actual == "" ? "none" : actual));
}

// One-time, read-only inventory across open charts. Work is spread over timers.
long g_diagObjectChart = -2;
int g_diagObjectIndex = 0;
int g_diagObjectTotal = 0;
int g_diagObjectRead = 0;
int g_diagObjectErrors = 0;
int g_diagPanelObjects = 0;
string g_diagPrefixes[32];
int g_diagPrefixCounts[32];
int g_diagPrefixUsed = 0;
int g_diagOtherPrefixes = 0;
int g_diagTypes[64];
int g_diagTypeCounts[64];
int g_diagTypeUsed = 0;
bool g_diagObjectStarted = false;

void FailureDiagnosticsObjectStart()
{
   g_diagObjectIndex = 0; g_diagObjectRead = 0; g_diagObjectErrors = 0;
   g_diagPanelObjects = 0; g_diagPrefixUsed = 0; g_diagOtherPrefixes = 0;
   g_diagTypeUsed = 0;
   g_diagObjectTotal = ObjectsTotal(g_diagObjectChart, -1, -1);
   g_diagObjectStarted = true;
   PrintFormat("[DIAG OBJECTS] START chart=%I64d symbol=%s period=%d total=%d; one-time incremental inventory",
      g_diagObjectChart, ChartSymbol(g_diagObjectChart), ChartPeriod(g_diagObjectChart), g_diagObjectTotal);
}

void FailureDiagnosticsObjectEnd()
{
   PrintFormat("[DIAG OBJECTS] END chart=%I64d initialTotal=%d scanned=%d readErrors=%d HG_PANEL_objects=%d; no objects deleted",
      g_diagObjectChart, g_diagObjectTotal, g_diagObjectRead, g_diagObjectErrors, g_diagPanelObjects);
   for(int i = 0; i < g_diagPrefixUsed; i++)
      PrintFormat("[DIAG OBJECT PREFIX] chart=%I64d prefix=%s count=%d",
         g_diagObjectChart, g_diagPrefixes[i], g_diagPrefixCounts[i]);
   if(g_diagOtherPrefixes > 0)
      PrintFormat("[DIAG OBJECT PREFIX] chart=%I64d other-prefixes count=%d",
         g_diagObjectChart, g_diagOtherPrefixes);
   for(int i = 0; i < g_diagTypeUsed; i++)
      PrintFormat("[DIAG OBJECT TYPE] chart=%I64d type=%s count=%d",
         g_diagObjectChart, EnumToString((ENUM_OBJECT)g_diagTypes[i]), g_diagTypeCounts[i]);
}

void FailureDiagnosticsObjects(ulong frameStartUs)
{
   if(!InpEnableFailureDiagnostics || g_diagObjectChart == -1) return;
   if(GetMicrosecondCount() - frameStartUs >= SCHEDULER_BUDGET_US) return;
   if(g_diagObjectChart == -2) g_diagObjectChart = ChartFirst();
   if(g_diagObjectChart == -1) return;
   if(!g_diagObjectStarted) FailureDiagnosticsObjectStart();
   ulong startUs = GetMicrosecondCount();
   int visited = 0;
   while(g_diagObjectIndex < g_diagObjectTotal && visited < 32 &&
         GetMicrosecondCount() - startUs < 1000 &&
         GetMicrosecondCount() - frameStartUs < SCHEDULER_BUDGET_US)
   {
      string name = ObjectName(g_diagObjectChart, g_diagObjectIndex++, -1, -1);
      visited++;
      if(name == "") { g_diagObjectErrors++; continue; }
      long type;
      if(!ObjectGetInteger(g_diagObjectChart, name, OBJPROP_TYPE, 0, type))
      { g_diagObjectErrors++; continue; }
      g_diagObjectRead++;
      if(StringFind(name, "HG_PANEL_") == 0) g_diagPanelObjects++;
      string prefix = name;
      int separator = StringFind(name, "_");
      int hash = StringFind(name, "#");
      int space = StringFind(name, " ");
      if(hash >= 0 && (separator < 0 || hash < separator)) separator = hash;
      if(space >= 0 && (separator < 0 || space < separator)) separator = space;
      if(StringFind(name, "HG_PANEL_") == 0) prefix = "HG_PANEL_";
      else if(separator >= 0) prefix = StringSubstr(name, 0, separator + 1);
      else prefix = StringSubstr(name, 0, 20);
      int slot = -1;
      for(int i = 0; i < g_diagPrefixUsed; i++)
         if(g_diagPrefixes[i] == prefix) { slot = i; break; }
      if(slot < 0 && g_diagPrefixUsed < 32)
      { slot = g_diagPrefixUsed++; g_diagPrefixes[slot] = prefix; g_diagPrefixCounts[slot] = 0; }
      if(slot >= 0) g_diagPrefixCounts[slot]++;
      else g_diagOtherPrefixes++;
      slot = -1;
      for(int i = 0; i < g_diagTypeUsed; i++)
         if(g_diagTypes[i] == (int)type) { slot = i; break; }
      if(slot < 0 && g_diagTypeUsed < 64)
      { slot = g_diagTypeUsed++; g_diagTypes[slot] = (int)type; g_diagTypeCounts[slot] = 0; }
      if(slot >= 0) g_diagTypeCounts[slot]++;
   }
   if(g_diagObjectIndex >= g_diagObjectTotal)
   {
      FailureDiagnosticsObjectEnd();
      g_diagObjectChart = ChartNext(g_diagObjectChart);
      g_diagObjectStarted = false;
   }
}

#endif
