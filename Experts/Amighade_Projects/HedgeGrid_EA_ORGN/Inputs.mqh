//+------------------------------------------------------------------+
//| Inputs.mqh                                                        |
//| All input parameters and enums for HedgeGrid EA                  |
//| Single source of truth for all configurable values               |
//+------------------------------------------------------------------+
#pragma once

//+------------------------------------------------------------------+
//| ENUMS                                                             |
//+------------------------------------------------------------------+

// Master strategy style selector
// Drives ALL pluggable engines simultaneously
// STYLE_A = current strategy (ladder lots, hit+2$ shift, asymmetric grid)
// STYLE_B = fixed lot, append-only shift, symmetric grid
enum ENUM_STRATEGY_STYLE
  {
   STYLE_A = 0,  // Ladder sizing + hit-based shifting + asymmetric grid
   STYLE_B = 1,  // Fixed sizing + append shifting + symmetric grid
  };

// Lot mode — set by MarginCheck engine
// FULL     = full 20-level ladder
// HALF     = half 10-level ladder (triggered by low margin)
enum ENUM_LOT_MODE
  {
   LOT_FULL = 0,  // Full ladder (20 levels, 0.01→0.20)
   LOT_HALF = 1,  // Half ladder (10 levels, 0.01→0.10)
  };

// Action to take when trading session ends mid-cycle
enum ENUM_SESSION_ACTION
  {
   SESSION_STOP_NEW_CYCLES = 0,  // Finish current cycle, no new grid after
   SESSION_CLOSE_ALL       = 1,  // Close everything when session ends
  };

// Cleanup type — passed to CleanupReset engine
enum ENUM_CLEANUP_TYPE
  {
   CLEANUP_EMERGENCY = 0,  // Immediate close all, no sequence
   CLEANUP_PROFIT    = 1,  // SL-based, after profit trigger
   CLEANUP_RANGE     = 2,  // SL-based, after lot threshold trigger
   CLEANUP_SL_HIT    = 3,  // After SL fires, close remaining
  };

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

//--- Strategy Selection
input ENUM_STRATEGY_STYLE  InpStrategyStyle     = STYLE_A;      // Strategy Style (drives all pluggable engines)

//--- Grid Settings
input double  InpInitialGap          = 2.00;   // Initial gap between nearest BUY and SELL ($)
input double  InpGridSpacing         = 0.50;   // Distance between grid levels ($)
input int     InpGridLevels          = 20;     // Number of orders per side

//--- Sizing Settings (Style A — Ladder)
input double  InpInitialLotStep      = 0.01;   // Lot increment per level (Style A)
input double  InpInitialLotCap       = 0.20;   // Max lot in initial ladder (Style A)

//--- Sizing Settings (Style B — Fixed)
input double  InpFixedLot            = 0.01;   // Fixed lot size for all levels (Style B)

//--- SL Trigger Settings
input bool    InpSLTriggerByLot      = true;   // Enable lot-based SL trigger
input double  InpSLTriggerLot        = 0.24;   // Lot threshold to trigger SL
input bool    InpSLTriggerByProfit   = true;   // Enable profit-based SL trigger

//--- Closing Settings
input double  InpRangeCloseLot       = 0.24;   // Lot threshold for In-Range Close

//--- Margin Settings
input double  InpMinAllowedMargin    = 1000.0; // Minimum free margin to allow grid placement ($)

//--- Recentering Settings
input bool    InpEnableRecentering   = true;   // Enable grid recentering (fresh grid only)
input double  InpThresholdFactor     = 3.0;    // Recenter threshold divisor (higher = tighter zone)

//--- Session Settings
input bool    InpUseLondonSession    = true;   // Trade during London session (08:00-17:00 GMT)
input bool    InpUseNewYorkSession   = true;   // Trade during New York session (13:00-22:00 GMT)
input bool    InpUseTokyoSession     = false;  // Trade during Tokyo session (00:00-09:00 GMT)
input bool    InpUseCustomWindow1    = false;  // Enable custom trading window 1
input string  InpCustomWindow1Start  = "08:00"; // Custom window 1 start time (HH:MM)
input string  InpCustomWindow1End    = "12:00"; // Custom window 1 end time (HH:MM)
input bool    InpUseCustomWindow2    = false;  // Enable custom trading window 2
input string  InpCustomWindow2Start  = "14:00"; // Custom window 2 start time (HH:MM)
input string  InpCustomWindow2End    = "18:00"; // Custom window 2 end time (HH:MM)
input ENUM_SESSION_ACTION InpOutsideSessionAction = SESSION_STOP_NEW_CYCLES; // Action when session ends

//--- Magic Number
// If 0: auto-generated from symbol + timeframe hash
// If >0: use this exact number (user responsible for uniqueness across instances)
input int     InpMagicNumber         = 0;      // Magic number (0 = auto-generate)

//--- Timer Settings
input int     InpTimerIntervalSec    = 1;      // Dashboard/margin refresh interval (seconds)

//--- Dashboard Settings
input bool    InpShowDashboard       = true;   // Show dashboard panel on chart

//--- Logging Settings
input bool    InpEnableDebugLog      = true;   // Enable debug logging to Experts tab
input bool    InpEnableHistoryLog    = true;   // Enable history logging to CSV file
input string  InpHistoryLogFile      = "HedgeGrid_History.csv"; // CSV log filename
