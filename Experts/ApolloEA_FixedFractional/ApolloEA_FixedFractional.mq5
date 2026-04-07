
//+------------------------------------------------------------------+
//|       Apollo Lite EA with Ryan Jones Fixed Fractional Sizing     |
//+------------------------------------------------------------------+
#property strict

input double RiskPercent     = 2.0;     // % risk per trade
input double AccountRiskMin = 100.0;   // Minimum balance to base risk on
input int    Slippage        = 10;
input double StopLossPoints  = 300;
input double TakeProfitPoints= 500;
input int    ZigzagDepth     = 12;
input int    ZigzagDeviation = 5;
input int    ZigzagBackstep  = 3;
input int    MagicNumber     = 20250808;

int zzHandle;
double zzBuffer[];
datetime lastBarTime = 0;

int OnInit()
{
   zzHandle = iCustom(_Symbol, _Period, "Examples\\ZigZag", ZigzagDepth, ZigzagDeviation, ZigzagBackstep);
   if (zzHandle == INVALID_HANDLE)
   {
      Print("Failed to load ZigZag");
      return(INIT_FAILED);
   }

   ArraySetAsSeries(zzBuffer, true);
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if (currentBarTime == lastBarTime)
      return;
   lastBarTime = currentBarTime;

   if (CopyBuffer(zzHandle, 0, 0, 10, zzBuffer) <= 0)
      return;

   double latest = zzBuffer[1];
   double prev   = zzBuffer[2];

   if (latest > 0 && latest > prev && !PositionSelect(_Symbol))
      OpenTrade(ORDER_TYPE_SELL);
   else if (latest > 0 && latest < prev && !PositionSelect(_Symbol))
      OpenTrade(ORDER_TYPE_BUY);
}

double CalculateLotSize(double sl_points)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = MathMax(balance * RiskPercent / 100.0, AccountRiskMin * RiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double valuePerPoint = tickValue * point / tickSize;
   double lotSize = riskAmount / (sl_points * valuePerPoint);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   lotSize = MathFloor(lotSize / step) * step;
   return NormalizeDouble(lotSize, 2);
}

void OpenTrade(ENUM_ORDER_TYPE type)
{
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = (type == ORDER_TYPE_BUY) ? price - StopLossPoints * _Point : price + StopLossPoints * _Point;
   double tp = (type == ORDER_TYPE_BUY) ? price + TakeProfitPoints * _Point : price - TakeProfitPoints * _Point;
   double lotSize = CalculateLotSize(StopLossPoints);

   MqlTradeRequest request = {};
   MqlTradeResult  result  = {};

   request.action   = TRADE_ACTION_DEAL;
   request.symbol   = _Symbol;
   request.volume   = lotSize;
   request.type     = type;
   request.price    = price;
   request.sl       = NormalizeDouble(sl, _Digits);
   request.tp       = NormalizeDouble(tp, _Digits);
   request.deviation = Slippage;
   request.magic    = MagicNumber;
   request.type_filling = ORDER_FILLING_IOC;

   if (!OrderSend(request, result))
      Print("Trade failed: ", result.retcode);
   else
      Print("Trade opened: ", EnumToString(type), " ", lotSize, " lots");
}
