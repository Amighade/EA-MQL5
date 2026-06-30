//+------------------------------------------------------------------+
//| Inputs.mqh                                                        |
//| All input parameters and enums for HedgeGrid EA                  |
//| Single source of truth for all configurable values               |
//+------------------------------------------------------------------+
#ifndef INPUTS_MQH
#define INPUTS_MQH

//+------------------------------------------------------------------+
//| ENUMS                                                             |
//+------------------------------------------------------------------+

enum ENUM_STRATEGY_STYLE
  {
   STYLE_A = 0,  // Ladder sizing + hit-based shifting + asymmetric grid
   STYLE_B = 1,  // Fixed sizing + append shifting + symmetric grid
   STYLE_C = 2,  // Fixed sizing + persistent grid + ABWCL arming + refill on SL hit
  };

enum ENUM_LOT_MODE
  {
   LOT_FULL = 0,  // Full ladder
   LOT_HALF = 1,  // Half ladder (low margin fallback)
  };

enum ENUM_CLEANUP_TYPE
  {
   CLEANUP_EMERGENCY = 0,
   CLEANUP_PROFIT    = 1,
   CLEANUP_RANGE     = 2,
   CLEANUP_SL_HIT    = 3,
  };

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

//--- Strategy
input ENUM_STRATEGY_STYLE InpStrategyStyle = STYLE_A;  // Strategy Style

//--- Grid Settings (all styles)
input double InpInitialGap    = 2.00;  // Gap between nearest BUY and SELL ($)
input double InpGridSpacing   = 0.50;  // Distance between grid levels ($)
input int    InpGridLevels    = 20;    // Orders per side (Style A/B: 20, Style C uses InpInitialGridLevels)

//--- Style C only
input int    InpInitialGridLevels = 50; // Style C: orders per side (initial + refill target)
input int    InpMinGridLevels     = 20; // Style C: refill trigger threshold per side

//--- Sizing (Style A)
input double InpInitialLotStep = 0.01; // Lot increment per level (Style A)
input double InpInitialLotCap  = 0.20; // Max lot in ladder (Style A)

//--- Sizing (Style B and C)
input double InpFixedLot       = 0.01; // Fixed lot size (Style B and C)

//--- SL Trigger
input bool   InpSLTriggerByLot    = true;  // Trigger SL when block lot reaches threshold
input double InpSLTriggerLot      = 0.24;  // Block lot threshold
input bool   InpSLTriggerByProfit = true;  // Trigger SL when basket profit positive

//--- Closing
input double InpRangeCloseLot  = 0.24;    // Lot threshold for In-Range Close

//--- Margin
input double InpMinAllowedMargin = 1000.0; // Minimum free margin to allow grid ($)

//--- Recentering (Style A/B only, ignored by Style C)
input bool   InpEnableRecentering = true;  // Enable grid recentering on fresh grid
input double InpThresholdFactor   = 3.0;   // Recenter zone divisor

//--- Time Filter
input bool   UseTimeFilter   = false; // Enable session time filter
input bool   EnableLondon    = true;  // Allow trading: London session
input bool   EnableNewYork   = true;  // Allow trading: New York session
input bool   EnableAsia      = false; // Allow trading: Asia session
input string ExtraWindow1    = "";    // Extra window 1: HH:MM-HH:MM (GMT)
input string ExtraWindow2    = "";    // Extra window 2: HH:MM-HH:MM (GMT)

//--- Magic Number (0 = auto from symbol + timeframe)
input int    InpMagicNumber  = 0;     // Magic number (0 = auto-generate)

//--- Dashboard
input bool   InpShowDashboard     = true;  // Show dashboard panel

//--- Timer
input int    InpTimerIntervalSec  = 1;     // Dashboard refresh interval (seconds)

//--- Logging
input bool   InpEnableDebugLog    = true;  // Debug logging to Experts tab
input bool   InpEnableHistoryLog  = true;  // History logging to CSV file
input string InpHistoryLogFile    = "HedgeGrid_History.csv"; // CSV filename

#endif
