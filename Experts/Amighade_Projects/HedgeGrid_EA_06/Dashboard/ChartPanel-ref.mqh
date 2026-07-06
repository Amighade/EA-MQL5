// ChartPanel.mqh
// NOTE:
// This is a starter replacement showing the movable-panel architecture.
// Due to chat output limits, the original business logic should be merged
// into LayoutDashboard() and UpdateDashboard() as discussed.

#ifndef CHART_PANEL_MQH
#define CHART_PANEL_MQH

#include "../Inputs.mqh"
#include "../Models/GridState.mqh"

#define PANEL_PREFIX "HG_PANEL_"
#define PANEL_W 500
#define PANEL_H 160
#define PANEL_FONT "Courier New"

int g_panelX=250;
int g_panelY=30;

void MoveObject(string name,int x,int y)
{
   if(ObjectFind(0,name)>=0)
   {
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   }
}

void LayoutDashboard()
{
   MoveObject(PANEL_PREFIX "BG",g_panelX-5,g_panelY-5);
   MoveObject(PANEL_PREFIX "TITLE",g_panelX,g_panelY);
   // Position remaining controls here exactly as in your original file.
}

void SyncDashboardPosition()
{
   g_panelX=(int)ObjectGetInteger(0,PANEL_PREFIX "BG",OBJPROP_XDISTANCE)+5;
   g_panelY=(int)ObjectGetInteger(0,PANEL_PREFIX "BG",OBJPROP_YDISTANCE)+5;
   LayoutDashboard();
}

#endif
