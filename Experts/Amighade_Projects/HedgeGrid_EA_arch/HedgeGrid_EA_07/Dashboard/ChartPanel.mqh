//+------------------------------------------------------------------+
//| ChartPanel.mqh                                                    |
//| Visual dashboard panel — draggable via drag handle               |
//| Shows all GridState fields for debugging                         |
//+------------------------------------------------------------------+
#ifndef CHART_PANEL_MQH
#define CHART_PANEL_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"

#define PANEL_PREFIX  "HG_PANEL_"
#define PANEL_FONT    "Courier New"
#define BTN_NAME      PANEL_PREFIX "BTN_EMERGENCY"
#define DRAG_NAME     PANEL_PREFIX "DRAG"

// Panel dimensions
#define PANEL_W       500
#define ROW_H         20
#define ROWS          30
#define PANEL_H       (ROWS * ROW_H + 20)  // 620

// Panel position — updated by drag
int  g_panelX      = 250;
int  g_panelY      = 30;
bool g_dragging    = false;
int  g_dragOffsetX = 0;
int  g_dragOffsetY = 0;
bool g_emergencyPressed = false;

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
void HG_CreateLabel(string name, int x, int y, string text, color clr, int fs=9)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetString(0,  name, OBJPROP_TEXT,       text);
   ObjectSetString(0,  name, OBJPROP_FONT,       PANEL_FONT);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   fs);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
}

void HG_SetRect(string name, int x, int y, int w, int h, color bg, color border)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,        w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,        h);
   ObjectSetInteger(0, name, OBJPROP_CORNER,       CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,      bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,   false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,       true);
}

void HG_UpdateVal(string name, string text, color clr, int x, int y)
{
   if(ObjectFind(0,name)<0) HG_CreateLabel(name, x, y, text, clr);
   else
     {
      ObjectSetString(0,  name, OBJPROP_TEXT,      text);
      ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
     }
}

// Legacy wrapper used by old code
void UpdateLabel(string name, string text, color clr)
{
   if(ObjectFind(0,name)<0) HG_CreateLabel(name, 0, 0, text, clr);
   else
     {
      ObjectSetString(0,  name, OBJPROP_TEXT,  text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
     }
}

//+------------------------------------------------------------------+
//| Reposition all objects after drag                                |
//+------------------------------------------------------------------+
void RepositionPanel()
{
   int px = g_panelX, py = g_panelY;
   int lx = px + 5;         // label x
   int vx = px + 300;       // value x

   HG_SetRect(PANEL_PREFIX "BG",   px, py,   PANEL_W, PANEL_H, C'20,20,20', clrGray);
   HG_SetRect(DRAG_NAME,           px, py,   PANEL_W, 16,      C'40,40,80', clrSteelBlue);
   ObjectSetInteger(0, PANEL_PREFIX "TITLE", OBJPROP_XDISTANCE, lx);
   ObjectSetInteger(0, PANEL_PREFIX "TITLE", OBJPROP_YDISTANCE, py+2);

   for(int i=1; i<=ROWS; i++)
     {
      int ry = py + 16 + (i-1)*ROW_H + 2;
      string li = PANEL_PREFIX+"L"+IntegerToString(i);
      string vi = PANEL_PREFIX+"V"+IntegerToString(i);
      if(ObjectFind(0,li)>=0){ ObjectSetInteger(0,li,OBJPROP_XDISTANCE,lx); ObjectSetInteger(0,li,OBJPROP_YDISTANCE,ry); }
      if(ObjectFind(0,vi)>=0){ ObjectSetInteger(0,vi,OBJPROP_XDISTANCE,vx); ObjectSetInteger(0,vi,OBJPROP_YDISTANCE,ry); }
     }

   // Emergency button
   ObjectSetInteger(0, BTN_NAME, OBJPROP_XDISTANCE, px);
   ObjectSetInteger(0, BTN_NAME, OBJPROP_YDISTANCE,  py + PANEL_H + 2);
}

//+------------------------------------------------------------------+
//| InitDashboard                                                    |
//+------------------------------------------------------------------+
void InitDashboard()
{
   if(!InpShowDashboard) return;

   int px=g_panelX, py=g_panelY, lx=px+5;

   HG_SetRect(PANEL_PREFIX "BG", px, py, PANEL_W, PANEL_H, C'20,20,20', clrGray);
   HG_SetRect(DRAG_NAME,         px, py, PANEL_W, 16,      C'40,40,80', clrSteelBlue);
   HG_CreateLabel(PANEL_PREFIX "TITLE", lx, py+2, "=== HedgeGrid EA  [drag] ===", clrWhite, 9);

   // Static row labels — match UpdateDashboard order
   string labels[] = {
      "cycleActive :", "gridPlaced :", "passCounter :", "lotMode :",
      "anchorBuy :", "anchorSell :", "lastHitDirection :", "lastHitLot :",
      "lastHitPrice :", "lastHitTime :", "lastHitTicket :", "farthestHitBuy :",
      "farthestHitSell :", "currentBlockLot :", "basketProfit :", "basketBuyProfit :",
      "basketSellProfit :", "slApplied :", "slLevel :", "slWinnerSide :",
      "slWallArmed :", "slAllWinnersClosed :", "refillNeeded :", "cleanupType :",
      "cleanupInProgress :", "cleanupStep :", "marginWarning :", "sessionAllowed :",
      "gapFaultDetected :", "Bricks :"
   };
   color lblColors[] = {
      clrYellow,clrWhite,clrYellow,clrWhite,clrYellow,clrWhite,clrYellow,clrWhite,
      clrYellow,clrWhite,clrYellow,clrWhite,clrYellow,clrWhite,clrYellow,clrWhite,
      clrYellow,clrWhite,clrYellow,clrWhite,clrYellow,clrWhite,clrYellow,clrWhite,
      clrYellow,clrWhite,clrYellow,clrWhite,clrYellow,clrSilver
   };

   for(int i=0; i<ROWS; i++)
     {
      int ry = py + 16 + i*ROW_H + 2;
      HG_CreateLabel(PANEL_PREFIX+"L"+IntegerToString(i+1), lx, ry, labels[i], lblColors[i]);
     }

   // Emergency button
   if(ObjectFind(0,BTN_NAME)<0) ObjectCreate(0, BTN_NAME, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, BTN_NAME, OBJPROP_XDISTANCE, px);
   ObjectSetInteger(0, BTN_NAME, OBJPROP_YDISTANCE,  py+PANEL_H+2);
   ObjectSetInteger(0, BTN_NAME, OBJPROP_XSIZE,      PANEL_W);
   ObjectSetInteger(0, BTN_NAME, OBJPROP_YSIZE,      22);
   ObjectSetInteger(0, BTN_NAME, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetString(0,  BTN_NAME, OBJPROP_TEXT,       "!! EMERGENCY CLOSE !!");
   ObjectSetInteger(0, BTN_NAME, OBJPROP_COLOR,      clrWhite);
   ObjectSetInteger(0, BTN_NAME, OBJPROP_BGCOLOR,    clrDarkRed);
   ObjectSetInteger(0, BTN_NAME, OBJPROP_FONTSIZE,   9);
   ObjectSetInteger(0, BTN_NAME, OBJPROP_HIDDEN,     true);

   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| UpdateDashboard — all 30 state fields                            |
//+------------------------------------------------------------------+
void UpdateDashboard(const GridState &state)
{
   if(!InpShowDashboard) return;

   int vx = g_panelX + 300;
   int py = g_panelY;

   #define RY(i) (py + 16 + (i)*ROW_H + 2)

   HG_UpdateVal(PANEL_PREFIX "V1",  state.cycleActive?"YES":"NO",                       state.cycleActive?clrOrange:clrMagenta,           vx, RY(0));
   HG_UpdateVal(PANEL_PREFIX "V2",  state.gridPlaced?"YES":"NO",                        state.gridPlaced?clrOrange:clrMagenta,             vx, RY(1));
   HG_UpdateVal(PANEL_PREFIX "V3",  IntegerToString(state.passCounter),                 clrAqua,                                           vx, RY(2));
   HG_UpdateVal(PANEL_PREFIX "V4",  state.lotMode==LOT_FULL?"FULL":"HALF",              state.lotMode==LOT_FULL?clrLime:clrOrange,         vx, RY(3));
   HG_UpdateVal(PANEL_PREFIX "V5",  DoubleToString(state.anchorBuy,2),                  clrAqua,                                           vx, RY(4));
   HG_UpdateVal(PANEL_PREFIX "V6",  DoubleToString(state.anchorSell,2),                 clrAqua,                                           vx, RY(5));
   HG_UpdateVal(PANEL_PREFIX "V7",  state.lastHitDirection==ORDER_TYPE_BUY?"BUY":"SELL",state.lastHitDirection==ORDER_TYPE_BUY?clrLime:clrMagenta, vx, RY(6));
   HG_UpdateVal(PANEL_PREFIX "V8",  DoubleToString(state.lastHitLot,2),                 clrAqua,                                           vx, RY(7));
   HG_UpdateVal(PANEL_PREFIX "V9",  DoubleToString(state.lastHitPrice,2),               clrOrange,                                         vx, RY(8));
   HG_UpdateVal(PANEL_PREFIX "V10", TimeToString(state.lastHitTime,TIME_SECONDS),       clrOrange,                                         vx, RY(9));
   HG_UpdateVal(PANEL_PREFIX "V11", IntegerToString(state.lastHitTicket),               clrAqua,                                           vx, RY(10));
   HG_UpdateVal(PANEL_PREFIX "V12", DoubleToString(state.farthestHitBuy,2),             clrAqua,                                           vx, RY(11));
   HG_UpdateVal(PANEL_PREFIX "V13", DoubleToString(state.farthestHitSell,2),            clrAqua,                                           vx, RY(12));
   HG_UpdateVal(PANEL_PREFIX "V14", DoubleToString(state.currentBlockLot,2),            clrAqua,                                           vx, RY(13));
   HG_UpdateVal(PANEL_PREFIX "V15", DoubleToString(state.basketProfit,2),               state.basketProfit>=0?clrLime:clrMagenta,          vx, RY(14));
   HG_UpdateVal(PANEL_PREFIX "V16", DoubleToString(state.basketBuyProfit,2),            clrAqua,                                           vx, RY(15));
   HG_UpdateVal(PANEL_PREFIX "V17", DoubleToString(state.basketSellProfit,2),           clrAqua,                                           vx, RY(16));
   HG_UpdateVal(PANEL_PREFIX "V18", state.slApplied?"YES":"NO",                         state.slApplied?clrOrange:clrMagenta,              vx, RY(17));
   HG_UpdateVal(PANEL_PREFIX "V19", DoubleToString(state.slLevel,2),                    clrAqua,                                           vx, RY(18));
   HG_UpdateVal(PANEL_PREFIX "V20", state.slWinnerSide==0?"BUY":"SELL",                 state.slWinnerSide==0?clrLime:clrMagenta,          vx, RY(19));
   HG_UpdateVal(PANEL_PREFIX "V21", state.slWallArmed?"YES":"NO",                       state.slWallArmed?clrOrange:clrMagenta,            vx, RY(20));
   HG_UpdateVal(PANEL_PREFIX "V22", state.slAllWinnersClosed?"YES":"NO",                state.slAllWinnersClosed?clrOrange:clrMagenta,     vx, RY(21));
   HG_UpdateVal(PANEL_PREFIX "V23", state.refillNeeded?"YES":"NO",                      state.refillNeeded?clrOrange:clrMagenta,           vx, RY(22));
   HG_UpdateVal(PANEL_PREFIX "V24", state.cleanupType==CLEANUP_CLOSE_ALL?"CLOSE_ALL":"CLOSE_POSITIONS", state.cleanupType==CLEANUP_CLOSE_ALL?clrMagenta:clrLime, vx, RY(23));
   HG_UpdateVal(PANEL_PREFIX "V25", state.cleanupInProgress?"YES":"NO",                 state.cleanupInProgress?clrOrange:clrMagenta,      vx, RY(24));
   HG_UpdateVal(PANEL_PREFIX "V26", IntegerToString(state.cleanupStep),                 clrAqua,                                           vx, RY(25));
   HG_UpdateVal(PANEL_PREFIX "V27", state.marginWarning?"YES":"NO",                     state.marginWarning?clrOrange:clrSilver,           vx, RY(26));
   HG_UpdateVal(PANEL_PREFIX "V28", state.sessionAllowed?"YES":"NO",                    state.sessionAllowed?clrOrange:clrSilver,          vx, RY(27));
   HG_UpdateVal(PANEL_PREFIX "V29", state.gapFaultDetected?"YES":"NO",                  state.gapFaultDetected?clrOrange:clrSilver,        vx, RY(28));

   string bricks = StringFormat("L%s S%s R%s I%s O%s",
      InpEnableLotIncrease  ?"+":"-", InpEnableShifting     ?"+":"-",
      InpEnableRecentering  ?"+":"-", InpEnableRefillInside ?"+":"-",
      InpEnableRefillOutside?"+":"-");
   HG_UpdateVal(PANEL_PREFIX "V30", bricks, clrYellow, vx, RY(29));

   #undef RY
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| DeinitDashboard                                                  |
//+------------------------------------------------------------------+
void DeinitDashboard()
{
   ObjectsDeleteAll(0, PANEL_PREFIX);
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| HandleChartEvent — drag + emergency button                       |
//+------------------------------------------------------------------+
bool HandleChartEvent(const int id, const long &lparam,
                      const double &dparam, const string &sparam)
{
   if(!InpShowDashboard) return false;

   // Emergency button click
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BTN_NAME)
     {
      ObjectSetInteger(0, BTN_NAME, OBJPROP_STATE, false);
      ChartRedraw();
      g_emergencyPressed = true;
      return true;
     }

   // Drag via MOUSE_MOVE
   if(id == CHARTEVENT_MOUSE_MOVE)
     {
      int  mx = (int)lparam;
      int  my = (int)dparam;
      uint ms = (uint)StringToInteger(sparam);
      bool held = ((ms & 1) != 0);

      if(!held) { g_dragging = false; return false; }

      bool overDrag = (mx >= g_panelX && mx <= g_panelX+PANEL_W &&
                       my >= g_panelY && my <= g_panelY+16);

      if(!g_dragging && overDrag)
        {
         g_dragging    = true;
         g_dragOffsetX = mx - g_panelX;
         g_dragOffsetY = my - g_panelY;
        }

      if(g_dragging)
        {
         int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
         int ch = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
         g_panelX = MathMax(0, MathMin(mx-g_dragOffsetX, cw-PANEL_W));
         g_panelY = MathMax(0, MathMin(my-g_dragOffsetY, ch-PANEL_H-30));
         RepositionPanel();
         ChartRedraw();
        }
     }

   return false;
}

#endif
