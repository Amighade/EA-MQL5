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
#define PANEL_X       250
#define PANEL_Y       30
#define PANEL_W       500
#define PANEL_H       650
#define PANEL_FONT    "Courier New"
#define PANEL_SIZE    9

//--- Emergency button
#define BTN_NAME      PANEL_PREFIX "BTN_EMERGENCY"
#define BTN_X         760
#define BTN_Y         30
#define BTN_W         400
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
void InitDashboard_orgn()
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
   CreateLabel(PANEL_PREFIX "L1", PANEL_X, PANEL_Y + 20,  "Bricks    :", clrSilver);
   CreateLabel(PANEL_PREFIX "L2", PANEL_X, PANEL_Y + 40,  "Counter   :", clrSilver);
   CreateLabel(PANEL_PREFIX "L3", PANEL_X, PANEL_Y + 60,  "Block Lot :", clrSilver);
   CreateLabel(PANEL_PREFIX "L4", PANEL_X, PANEL_Y + 80,  "Basket P&L:", clrSilver);
   CreateLabel(PANEL_PREFIX "L5", PANEL_X, PANEL_Y + 100,  "Session   :", clrSilver);
   CreateLabel(PANEL_PREFIX "L6", PANEL_X, PANEL_Y + 120,  "Margin    :", clrSilver);
   CreateLabel(PANEL_PREFIX "L7", PANEL_X, PANEL_Y + 140, "SL Applied:", clrSilver);
   CreateLabel(PANEL_PREFIX "L8", PANEL_X, PANEL_Y + 160, "Lot Mode  :", clrSilver);

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
   CreateLabel(PANEL_PREFIX "L1", PANEL_X, PANEL_Y + 20,  "cycleActive :", clrYellow);
   CreateLabel(PANEL_PREFIX "L2", PANEL_X, PANEL_Y + 40,  "gridPlaced :", clrWhite);
   CreateLabel(PANEL_PREFIX "L3", PANEL_X, PANEL_Y + 60,  "passCounter :", clrYellow);
   CreateLabel(PANEL_PREFIX "L4", PANEL_X, PANEL_Y + 80,  "lotMode :", clrWhite);
   CreateLabel(PANEL_PREFIX "L5", PANEL_X, PANEL_Y + 100,  "anchorBuy :", clrYellow);
   CreateLabel(PANEL_PREFIX "L6", PANEL_X, PANEL_Y + 120,  "anchorSell :", clrWhite);
   CreateLabel(PANEL_PREFIX "L7", PANEL_X, PANEL_Y + 140, "lastHitDirection :", clrYellow);
   CreateLabel(PANEL_PREFIX "L8", PANEL_X, PANEL_Y + 160, "lastHitLot :", clrWhite);
   CreateLabel(PANEL_PREFIX "L9", PANEL_X, PANEL_Y + 180, "lastHitPrice :", clrYellow);
   CreateLabel(PANEL_PREFIX "L10", PANEL_X, PANEL_Y + 200, "lastHitTime :", clrWhite);
   CreateLabel(PANEL_PREFIX "L11", PANEL_X, PANEL_Y + 220, "lastHitTicket :", clrYellow);
   CreateLabel(PANEL_PREFIX "L12", PANEL_X, PANEL_Y + 240, "farthestHitBuy :", clrWhite);
   CreateLabel(PANEL_PREFIX "L13", PANEL_X, PANEL_Y + 260, "farthestHitSell :", clrYellow);
   CreateLabel(PANEL_PREFIX "L14", PANEL_X, PANEL_Y + 280, "currentBlockLot :", clrWhite);
   CreateLabel(PANEL_PREFIX "L15", PANEL_X, PANEL_Y + 300, "basketProfit :", clrYellow);
   CreateLabel(PANEL_PREFIX "L16", PANEL_X, PANEL_Y + 320, "basketBuyProfit :", clrWhite);
   CreateLabel(PANEL_PREFIX "L17", PANEL_X, PANEL_Y + 340, "basketSellProfit :", clrYellow);
   CreateLabel(PANEL_PREFIX "L18", PANEL_X, PANEL_Y + 360, "slApplied :", clrWhite);
   CreateLabel(PANEL_PREFIX "L19", PANEL_X, PANEL_Y + 380, "slLevel :", clrYellow);
   CreateLabel(PANEL_PREFIX "L20", PANEL_X, PANEL_Y + 400, "slWinnerSide :", clrWhite);
   CreateLabel(PANEL_PREFIX "L21", PANEL_X, PANEL_Y + 420, "slWallArmed :", clrYellow);
   CreateLabel(PANEL_PREFIX "L22", PANEL_X, PANEL_Y + 440, "slAllWinnersClosed :", clrWhite);
   CreateLabel(PANEL_PREFIX "L23", PANEL_X, PANEL_Y + 460, "refillNeeded :", clrYellow);
   CreateLabel(PANEL_PREFIX "L24", PANEL_X, PANEL_Y + 480, "cleanupType :", clrWhite);
   CreateLabel(PANEL_PREFIX "L25", PANEL_X, PANEL_Y + 500, "cleanupInProgress :", clrYellow);
   CreateLabel(PANEL_PREFIX "L26", PANEL_X, PANEL_Y + 520, "cleanupStep :", clrWhite);
   CreateLabel(PANEL_PREFIX "L27", PANEL_X, PANEL_Y + 540, "marginWarning :", clrYellow);
   CreateLabel(PANEL_PREFIX "L28", PANEL_X, PANEL_Y + 560, "sessionAllowed :", clrWhite);
   CreateLabel(PANEL_PREFIX "L29", PANEL_X, PANEL_Y + 580, "gapFaultDetected :", clrYellow);
   CreateLabel(PANEL_PREFIX "L30", PANEL_X, PANEL_Y + 600,  "Bricks    :", clrSilver);
      
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

   int valueX = PANEL_X + 300;
                        
   // cycleActive                                
   UpdateLabel(PANEL_PREFIX "V1",
               state.cycleActive ? "YES" : "NO",
               state.cycleActive ? clrOrange : clrMagenta);
   ObjectSetInteger(0, PANEL_PREFIX "V1", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V1", OBJPROP_YDISTANCE, PANEL_Y + 20);

   // Pass counter
   UpdateLabel(PANEL_PREFIX "V2",
               state.gridPlaced ? "YES" : "NO",
               state.gridPlaced ? clrOrange : clrMagenta);
   ObjectSetInteger(0, PANEL_PREFIX "V2", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V2", OBJPROP_YDISTANCE, PANEL_Y + 40);

   // Block lot
   UpdateLabel(PANEL_PREFIX "V3",
               IntegerToString(state.passCounter),
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V3", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V3", OBJPROP_YDISTANCE, PANEL_Y + 60);

   // lotMode
   UpdateLabel(PANEL_PREFIX "V4",
               state.lotMode == LOT_FULL ? "FULL" : "HALF",
               state.lotMode == LOT_FULL ? clrLime : clrOrange);
   ObjectSetInteger(0, PANEL_PREFIX "V4", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V4", OBJPROP_YDISTANCE, PANEL_Y + 80);

   // anchorBuy
   UpdateLabel(PANEL_PREFIX "V5",
               DoubleToString(state.anchorBuy, 2),
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V5", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V5", OBJPROP_YDISTANCE, PANEL_Y + 100);

   // Margin
   UpdateLabel(PANEL_PREFIX "V6",
               DoubleToString(state.anchorSell, 2),
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V6", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V6", OBJPROP_YDISTANCE, PANEL_Y + 120);

   // lastHitDirection
   UpdateLabel(PANEL_PREFIX "V7",
               state.lastHitDirection==ORDER_TYPE_BUY?"BUY":"SELL",
               state.lastHitDirection == ORDER_TYPE_BUY ? clrLime : clrMagenta);
   ObjectSetInteger(0, PANEL_PREFIX "V7", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V7", OBJPROP_YDISTANCE, PANEL_Y + 140);

   // lastHitLot
   UpdateLabel(PANEL_PREFIX "V8",
               DoubleToString(state.lastHitLot, 2),
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V8", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V8", OBJPROP_YDISTANCE, PANEL_Y + 160);
   
   // lastHitPrice
   UpdateLabel(PANEL_PREFIX "V9",
               DoubleToString(state.lastHitPrice, 2),
               clrOrange);
   ObjectSetInteger(0, PANEL_PREFIX "V9", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V9", OBJPROP_YDISTANCE, PANEL_Y + 180);
   
   // lastHitTime
   UpdateLabel(PANEL_PREFIX "V10",
               IntegerToString(state.lastHitTime),
               clrOrange);
   ObjectSetInteger(0, PANEL_PREFIX "V10", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V10", OBJPROP_YDISTANCE, PANEL_Y + 200);
   
   // lastHitTicket
   UpdateLabel(PANEL_PREFIX "V11",
               IntegerToString(state.lastHitTicket),
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V11", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V11", OBJPROP_YDISTANCE, PANEL_Y + 220);
   
   // farthestHitBuy
   UpdateLabel(PANEL_PREFIX "V12",
               DoubleToString(state.farthestHitBuy, 2),
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V12", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V12", OBJPROP_YDISTANCE, PANEL_Y + 240);
   
   // farthestHitSell
   UpdateLabel(PANEL_PREFIX "V13",
               DoubleToString(state.farthestHitSell, 2),
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V13", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V13", OBJPROP_YDISTANCE, PANEL_Y + 260);
   
   // currentBlockLot
   UpdateLabel(PANEL_PREFIX "V14",
               DoubleToString(state.currentBlockLot, 2),
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V14", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V14", OBJPROP_YDISTANCE, PANEL_Y + 280);
   
   // basketProfit
   UpdateLabel(PANEL_PREFIX "V15",
               DoubleToString(state.basketProfit, 2),
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V15", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V15", OBJPROP_YDISTANCE, PANEL_Y + 300);
   
   // basketBuyProfit
   UpdateLabel(PANEL_PREFIX "V16",
               DoubleToString(state.basketBuyProfit, 2),
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V16", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V16", OBJPROP_YDISTANCE, PANEL_Y + 320);
   
   // basketSellProfit
   UpdateLabel(PANEL_PREFIX "V17",
               DoubleToString(state.basketSellProfit, 2),
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V17", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V17", OBJPROP_YDISTANCE, PANEL_Y + 340);
   
   // slAppliedclrOrange
   UpdateLabel(PANEL_PREFIX "V18",
               state.slApplied ? "YES" : "NO",
               state.slApplied ? clrOrange : clrMagenta);
   ObjectSetInteger(0, PANEL_PREFIX "V18", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V18", OBJPROP_YDISTANCE, PANEL_Y + 360);
   
   // slLevel
   UpdateLabel(PANEL_PREFIX "V19",
               DoubleToString(state.slLevel, 2),
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V19", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V19", OBJPROP_YDISTANCE, PANEL_Y + 380);
   
   // slWinnerSide
   UpdateLabel(PANEL_PREFIX "V20",
               state.slWinnerSide == 0 ?"BUY":"SELL",
               state.slWinnerSide == 0 ? clrLime : clrMagenta);
   ObjectSetInteger(0, PANEL_PREFIX "V20", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V20", OBJPROP_YDISTANCE, PANEL_Y + 400);

   UpdateLabel(PANEL_PREFIX "V20",
               state.slWinnerSide == 0 ?"BUY":
               state.slWinnerSide == 1 ?"SELL":"---",
               state.slWinnerSide == 0 ? clrLime :
               state.slWinnerSide == 1 ? clrMagenta : clrSilver
               );
                  
   // slWallArmed
   UpdateLabel(PANEL_PREFIX "V21",
               state.slWallArmed ? "YES" : "NO",
               state.slWallArmed ? clrOrange : clrMagenta);
   ObjectSetInteger(0, PANEL_PREFIX "V21", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V21", OBJPROP_YDISTANCE, PANEL_Y + 420);
   
   // slAllWinnersClosed
   UpdateLabel(PANEL_PREFIX "V22",
               state.slAllWinnersClosed ? "YES" : "NO",
               state.slAllWinnersClosed ? clrOrange : clrMagenta);
   ObjectSetInteger(0, PANEL_PREFIX "V22", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V22", OBJPROP_YDISTANCE, PANEL_Y + 440);
   
   // refillNeeded
   UpdateLabel(PANEL_PREFIX "V23",
               state.refillNeeded ? "YES" : "NO",
               state.refillNeeded ? clrOrange : clrMagenta);
   ObjectSetInteger(0, PANEL_PREFIX "V23", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V23", OBJPROP_YDISTANCE, PANEL_Y + 460);
   
   // cleanupType
   UpdateLabel(PANEL_PREFIX "V24",
               state.cleanupType == 0 ?"CLOSE_ALL":"CLOSE_POSITIONS",
               state.cleanupType == 1 ? clrLime : clrMagenta);
   ObjectSetInteger(0, PANEL_PREFIX "V24", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V24", OBJPROP_YDISTANCE, PANEL_Y + 480);
   
   // cleanupInProgress
   UpdateLabel(PANEL_PREFIX "V25",
               state.cleanupInProgress ? "YES" : "NO",
               state.cleanupInProgress ? clrOrange : clrMagenta);
   ObjectSetInteger(0, PANEL_PREFIX "V25", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V25", OBJPROP_YDISTANCE, PANEL_Y + 500);
   
   // cleanupStep
   UpdateLabel(PANEL_PREFIX "V26",
               IntegerToString(state.cleanupStep), 
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V26", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V26", OBJPROP_YDISTANCE, PANEL_Y + 520);
   
   // marginWarning
   UpdateLabel(PANEL_PREFIX "V27",
               state.marginWarning ? "YES" : "NO",
               state.marginWarning ? clrOrange : clrSilver);
   ObjectSetInteger(0, PANEL_PREFIX "V27", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V27", OBJPROP_YDISTANCE, PANEL_Y + 540);
   
   // sessionAllowed
   UpdateLabel(PANEL_PREFIX "V28",
               state.sessionAllowed ? "YES" : "NO",
               state.sessionAllowed ? clrOrange : clrSilver);
   ObjectSetInteger(0, PANEL_PREFIX "V28", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V28", OBJPROP_YDISTANCE, PANEL_Y + 560);
   
   // gapFaultDetected
   UpdateLabel(PANEL_PREFIX "V29",
               state.gapFaultDetected ? "YES" : "NO",
               state.gapFaultDetected ? clrOrange : clrSilver);
   ObjectSetInteger(0, PANEL_PREFIX "V29", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V29", OBJPROP_YDISTANCE, PANEL_Y + 580);

   // Brick summary (replaces old Style A/B/C label — styles no longer exist as hardcoded engines)
   string bricks = StringFormat("L%s S%s R%s I%s O%s",
                                InpEnableLotIncrease  ? "+" : "-",
                                InpEnableShifting     ? "+" : "-",
                                InpEnableRecentering  ? "+" : "-",
                                InpEnableRefillInside ? "+" : "-",
                                InpEnableRefillOutside? "+" : "-");
   UpdateLabel(PANEL_PREFIX "V30", bricks, clrYellow);
   ObjectSetInteger(0, PANEL_PREFIX "V30", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V30", OBJPROP_YDISTANCE, PANEL_Y + 600);
   

   ChartRedraw();
  }

void UpdateDashboard_orgn(const GridState &state)
  {
   if(!InpShowDashboard) return;

   int valueX = PANEL_X + 200;

   // Brick summary (replaces old Style A/B/C label — styles no longer exist as hardcoded engines)
   string bricks = StringFormat("L%s S%s R%s I%s O%s",
                                InpEnableLotIncrease  ? "+" : "-",
                                InpEnableShifting     ? "+" : "-",
                                InpEnableRecentering  ? "+" : "-",
                                InpEnableRefillInside ? "+" : "-",
                                InpEnableRefillOutside? "+" : "-");
   UpdateLabel(PANEL_PREFIX "V1", bricks, clrYellow);
   ObjectSetInteger(0, PANEL_PREFIX "V1", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V1", OBJPROP_YDISTANCE, PANEL_Y + 20);

   // Pass counter
   UpdateLabel(PANEL_PREFIX "V2",
               IntegerToString(state.passCounter),
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V2", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V2", OBJPROP_YDISTANCE, PANEL_Y + 40);

   // Block lot
   UpdateLabel(PANEL_PREFIX "V3",
               DoubleToString(state.currentBlockLot, 2),
               clrAqua);
   ObjectSetInteger(0, PANEL_PREFIX "V3", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V3", OBJPROP_YDISTANCE, PANEL_Y + 60);

   // Basket P&L
   color pnlColor = (state.basketProfit >= 0) ? clrLime : clrMagenta;
   UpdateLabel(PANEL_PREFIX "V4",
               DoubleToString(state.basketProfit, 2),
               pnlColor);
   ObjectSetInteger(0, PANEL_PREFIX "V4", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V4", OBJPROP_YDISTANCE, PANEL_Y + 80);

   // Session
   color sessionColor = state.sessionAllowed ? clrLime : clrOrange;
   UpdateLabel(PANEL_PREFIX "V5",
               state.sessionAllowed ? "ACTIVE" : "INACTIVE",
               sessionColor);
   ObjectSetInteger(0, PANEL_PREFIX "V5", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V5", OBJPROP_YDISTANCE, PANEL_Y + 100);

   // Margin
   color marginColor = state.marginWarning ? clrMagenta : clrLime;
   UpdateLabel(PANEL_PREFIX "V6",
               state.marginWarning ? "WARNING" : "OK",
               marginColor);
   ObjectSetInteger(0, PANEL_PREFIX "V6", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V6", OBJPROP_YDISTANCE, PANEL_Y + 120);

   // SL Applied
   UpdateLabel(PANEL_PREFIX "V7",
               state.slApplied ? "YES" : "NO",
               state.slApplied ? clrOrange : clrSilver);
   ObjectSetInteger(0, PANEL_PREFIX "V7", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V7", OBJPROP_YDISTANCE, PANEL_Y + 140);

   // Lot mode
   UpdateLabel(PANEL_PREFIX "V8",
               state.lotMode == LOT_FULL ? "FULL" : "HALF",
               state.lotMode == LOT_FULL ? clrLime : clrOrange);
   ObjectSetInteger(0, PANEL_PREFIX "V8", OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, PANEL_PREFIX "V8", OBJPROP_YDISTANCE, PANEL_Y + 160);

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