//+------------------------------------------------------------------+
//| ChartPanel.mqh                                                    |
//| Visual dashboard panel on chart                                  |
//| Shows: pass counter, block lot, basket P&L, session, margin      |
//| Includes: Emergency Close button                                 |
//+------------------------------------------------------------------+
#ifndef CHART_PANEL_MQH
#define CHART_PANEL_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"

//--- Panel object name prefix (unique to avoid conflicts)
#define PANEL_PREFIX "HG_PANEL_"

//--- Panel dimensions and position
#define PANEL_X       10
#define PANEL_Y       30
#define PANEL_W       220
#define PANEL_H       200
#define PANEL_FONT    "Courier New"
#define PANEL_SIZE    9

//--- Emergency button
#define BTN_NAME      PANEL_PREFIX "BTN_EMERGENCY"
#define BTN_X         10
#define BTN_Y         240
#define BTN_W         220
#define BTN_H         25

// Track if emergency button was pressed
bool g_emergencyPressed = false;

//+------------------------------------------------------------------+
//| Create a label object on the chart                               |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int fontSize = 9)
  {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetString(0,  name, OBJPROP_TEXT,       text);
   ObjectSetString(0,  name, OBJPROP_FONT,       PANEL_FONT);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  }

//+------------------------------------------------------------------+
//| Update or create a label                                         |
//+------------------------------------------------------------------+
void UpdateLabel(string name, string text, color clr)
  {
   if(ObjectFind(0, name) < 0)
      CreateLabel(name, 0, 0, text, clr);
   else
     {
      ObjectSetString(0,  name, OBJPROP_TEXT,  text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
     }
  }

//+------------------------------------------------------------------+
//| Initialize dashboard — create all panel objects                  |
//+------------------------------------------------------------------+
void InitDashboard()
  {
   if(!InpShowDashboard) return;

   // Background rectangle
   ObjectCreate(0, PANEL_PREFIX "BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, PANEL_PREFIX "BG", OBJPROP_XDISTANCE,  PANEL_X - 5);
   ObjectSetInteger(0, PANEL_PREFIX "BG", OBJPROP_YDISTANCE,  PANEL_Y - 5);
   ObjectSetInteger(0, PANEL_PREFIX "BG", OBJPROP_XSIZE,      PANEL_W);
   ObjectSetInteger(0, PANEL_PREFIX "BG", OBJPROP_YSIZE,      PANEL_H);
   ObjectSetInteger(0, PANEL_PREFIX "BG", OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, PANEL_PREFIX "BG", OBJPROP_BGCOLOR,    C'20,20,20');
   ObjectSetInteger(0, PANEL_PREFIX "BG", OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, PANEL_PREFIX "BG", OBJPROP_SELECTABLE, false);

   // Title
   CreateLabel(PANEL_PREFIX "TITLE", PANEL_X, PANEL_Y, "=== HedgeGrid EA ===", clrWhite, 10);

   // Row labels (static)
   CreateLabel(PANEL_PREFIX "L1", PANEL_X, PANEL_Y + 20,  "Strategy  :", clrSilver);
   CreateLabel(PANEL_PREFIX "L2", PANEL_X, PANEL_Y + 35,  "Counter   :", clrSilver);
   CreateLabel(PANEL_PREFIX "L3", PANEL_X, PANEL_Y + 50,  "Block Lot :", clrSilver);
   CreateLabel(PANEL_PREFIX "L4", PANEL_X, PANEL_Y + 65,  "Basket P&L:", clrSilver);
   CreateLabel(PANEL_PREFIX "L5", PANEL_X, PANEL_Y + 80,  "Session   :", clrSilver);
   CreateLabel(PANEL_PREFIX "L6", PANEL_X, PANEL_Y + 95,  "Margin    :", clrSilver);
   CreateLabel(PANEL_PREFIX "L7", PANEL_X, PANEL_Y + 110, "SL Applied:", clrSilver);
   CreateLabel(PANEL_PREFIX "L8", PANEL_X, PANEL_Y + 125, "Lot Mode  :", clrSilver);

   // Emergency close button
   ObjectCreate(0, BTN_NAME, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, BTN_NAME, OBJPROP_XDISTANCE,  BTN_X);
   ObjectSetInteger(0, BTN_NAME, OBJPROP_YDISTANCE,  BTN_Y);
   ObjectSetInteger(0, BTN_NAME, OBJPROP_XSIZE,      BTN_W);
   ObjectSetInteger(0, BTN_NAME, OBJPROP_YSIZE,      BTN_H);
   ObjectSetInteger(0, BTN_NAME, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetString(0,  BTN_NAME, OBJPROP_TEXT,       "!! EMERGENCY CLOSE !!");
   ObjectSetInteger(0, BTN_NAME, OBJPROP_COLOR,      clrWhite);
   ObjectSetInteger(0, BTN_NAME, OBJPROP_BGCOLOR,    clrDarkRed);
   ObjectSetInteger(0, BTN_NAME, OBJPROP_FONTSIZE,   10);

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Update dashboard with current state                              |
//| Call from OnTimer                                                |
//+------------------------------------------------------------------+
void UpdateDashboard(const GridState &state)
  {
   if(!InpShowDashboard) return;

   int valueX = PANEL_X + 90;

   // Strategy style
   UpdateLabel(PANEL_PREFIX "V1",
               InpStrategyStyle == STYLE_A ? "STYLE A" : "STYLE B",
               clrYellow);
   ObjectSetInteger(0, PANEL_PREFIX "V1", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V1", OBJPROP_YDISTANCE, PANEL_Y + 20);

   // Pass counter
   UpdateLabel(PANEL_PREFIX "V2",
               IntegerToString(state.passCounter),
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V2", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V2", OBJPROP_YDISTANCE, PANEL_Y + 35);

   // Block lot
   UpdateLabel(PANEL_PREFIX "V3",
               DoubleToString(state.currentBlockLot, 2),
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V3", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V3", OBJPROP_YDISTANCE, PANEL_Y + 50);

   // Basket P&L
   color pnlColor = (state.basketProfit >= 0) ? clrLime : clrRed;
   UpdateLabel(PANEL_PREFIX "V4",
               DoubleToString(state.basketProfit, 2),
               pnlColor);
   ObjectSetInteger(0, PANEL_PREFIX "V4", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V4", OBJPROP_YDISTANCE, PANEL_Y + 65);

   // Session
   color sessionColor = state.sessionAllowed ? clrLime : clrOrange;
   UpdateLabel(PANEL_PREFIX "V5",
               state.sessionAllowed ? "ACTIVE" : "INACTIVE",
               sessionColor);
   ObjectSetInteger(0, PANEL_PREFIX "V5", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V5", OBJPROP_YDISTANCE, PANEL_Y + 80);

   // Margin
   color marginColor = state.marginWarning ? clrRed : clrLime;
   UpdateLabel(PANEL_PREFIX "V6",
               state.marginWarning ? "WARNING" : "OK",
               marginColor);
   ObjectSetInteger(0, PANEL_PREFIX "V6", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V6", OBJPROP_YDISTANCE, PANEL_Y + 95);

   // SL Applied
   UpdateLabel(PANEL_PREFIX "V7",
               state.slApplied ? "YES" : "NO",
               state.slApplied ? clrOrange : clrSilver);
   ObjectSetInteger(0, PANEL_PREFIX "V7", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V7", OBJPROP_YDISTANCE, PANEL_Y + 110);

   // Lot mode
   UpdateLabel(PANEL_PREFIX "V8",
               state.lotMode == LOT_FULL ? "FULL" : "HALF",
               state.lotMode == LOT_FULL ? clrLime : clrOrange);
   ObjectSetInteger(0, PANEL_PREFIX "V8", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V8", OBJPROP_YDISTANCE, PANEL_Y + 125);

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Remove all dashboard objects from chart                          |
//| Call from OnDeinit                                               |
//+------------------------------------------------------------------+
void DeinitDashboard()
  {
   ObjectsDeleteAll(0, PANEL_PREFIX);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Handle chart events — detect emergency button press              |
//| Call from OnChartEvent                                           |
//| Returns true if emergency close was pressed                      |
//+------------------------------------------------------------------+
bool HandleChartEvent(const int id, const long &lparam,
                      const double &dparam, const string &sparam)
  {
   if(id != CHARTEVENT_OBJECT_CLICK) return false;
   if(sparam != BTN_NAME) return false;

   // Reset button state visually
   ObjectSetInteger(0, BTN_NAME, OBJPROP_STATE, false);
   ChartRedraw();

   g_emergencyPressed = true;
   return true;
  }


#endif