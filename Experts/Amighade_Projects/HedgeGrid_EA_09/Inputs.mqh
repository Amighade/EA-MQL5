//+------------------------------------------------------------------+
//| Inputs.mqh                                                        |
//| All input parameters and enums for HedgeGrid EA                  |
//| Single source of truth for all configurable values               |
//|                                                                    |
//| ARCHITECTURE NOTE (v4.00 "Brick" rewrite):                       |
//| Style A/B/C no longer exist as hardcoded engines. Instead, every  |
//| behavior is an independent toggle ("brick"). A "style" is just    |
//| a saved combination of these toggles, chosen by the user.         |
//| Combo presets (auto-select bricks from a named style) are a      |
//| planned phase-2 feature and are NOT implemented here.             |
//+------------------------------------------------------------------+
#ifndef INPUTS_MQH
#define INPUTS_MQH

//+------------------------------------------------------------------+
//| ENUMS                                                             |
//+------------------------------------------------------------------+

//--- Initial grid lot sizing (how lots are set when a grid is first built)
enum ENUM_INITIAL_SIZING
  {
   SIZING_FIXED  = 0,  // Fixed lot for every level (InpFixedLot)
   SIZING_LADDER = 1,  // Increasing ladder per level (InpInitialLotStep, capped at InpInitialLotCap)
   SIZING_EXP = 2,  // Increasing ladder per level exponentially (InpInitialLotStep, capped at InpInitialLotCap)
  };

//--- Brick 1: lot increase on opposite-side hit
enum ENUM_LOT_INCREASE_MODE
  {
   LOT_INC_A = 0,  // Implemented: pass-counter driven (1st pass partial-update, 2nd+ pass full replace)
   LOT_INC_B = 1,  // STUB — reserved for future logic, currently no-op
   LOT_INC_C = 2,  // STUB — reserved for future logic, currently no-op
  };

//--- Brick 2: shifting anchor
enum ENUM_SHIFT_ANCHOR
  {
   SHIFT_LAST_HIT     = 0,  // Shift to align with the last hit level
   SHIFT_FARTHEST_HIT = 1,  // Shift to align with the farthest hit level
   SHIFT_PRICE        = 2,  // Shift to align with current price
  };

//--- Brick 6: SL grid-snap mode
enum ENUM_SL_MODE
  {
   SL_LAST_HIT_GRID = 0,  // SL = last hit's own grid line (clamped safe if needed)
   SL_N_BACK_GRID   = 1,  // SL = N grid-steps back from last hit (clamped safe, depth-capped)
  };

//--- Brick 7: cleanup type after SL hit / safety stop
enum ENUM_CLEANUP_MODE
  {
   CLEANUP_CLOSE_ALL       = 0,  // Close all positions AND delete all pending orders
   CLEANUP_CLOSE_POSITIONS = 1,  // Close positions only, leave pending orders in place
  };

enum ENUM_LOT_MODE
  {
   LOT_FULL = 0,  // Full ladder/count
   LOT_HALF = 1,  // Half ladder/count (low margin fallback)
  };

enum ENUM_REFILL_STYLE { REFILL_THRESHOLD = 0, REFILL_FOLLOW_PRICE = 1 };
  
double InpCommissionPerLot = 0.0;
//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

//--- Grid Settings (core, always active)
input double InpInitialGap    = 2.00;  // Gap between nearest BUY and SELL ($)
input double InpGridSpacing   = 0.50;  // Distance between grid levels ($)

//--- Grid level counts (consolidated — replaces old InpGridLevels)
input int    InpInitialGridLevels = 20; // Orders per side placed on a fresh grid build
input int    InpMinGridLevels     = 10; // Refill-outside trigger: refill when count drops below this
input int    InpMaxGridLevels     = 30; // Refill-outside target: refill up to this count

//--- Initial sizing (how lots are set when the grid is first built or refilled)
input ENUM_INITIAL_SIZING InpInitialSizing = SIZING_FIXED; // Initial lot sizing mode
input double InpInitialLotStep = 0.01; // Ladder: lot increment per level
input double InpInitialLotCap  = 0.20; // Ladder: max lot
input double InpFixedLot       = 0.01; // Fixed: lot size for every level (also used by refill)

//--- BRICK 1: Lot increase on opposite-side hit -----------------------
input bool   InpEnableLotIncrease  = false;    // Increase lot sizing on opposite-side hit? (No = lots never change)
input ENUM_LOT_INCREASE_MODE InpLotIncreaseMode = LOT_INC_A; // Sub-option if enabled (only A is implemented)

//--- BRICK 2: Shifting on gap ------------------------------------------
input bool   InpEnableShifting     = false;    // Shift grid when a gap appears after a hit?
input ENUM_SHIFT_ANCHOR InpShiftAnchor = SHIFT_LAST_HIT; // Anchor used if shifting enabled

//--- BRICK 3: Recentering ----------------------------------------------
input bool   InpEnableRecentering  = false;    // Recenter grid when fresh and off-center?
input double InpThresholdFactor    = 3.0;      // Recenter zone divisor (gap / factor = trigger threshold)

//--- BRICK 4: Refill inside gap -----------------------------------------
input bool   InpEnableRefillInside  = false;   // Refill inside the gap (between nearest BUY/SELL) when empty?
input ENUM_REFILL_STYLE InpRefillStyle = REFILL_THRESHOLD;                                                // NOTE: keep InpEnableShifting = false when this is on.

//--- BRICK 5: Refill outside range --------------------------------------
input bool   InpEnableRefillOutside = false;   // Refill outside levels when count drops below InpMinGridLevels?
                                                // NOTE: keep InpEnableShifting = false when this is on.
                                                // NOTE: keep InpEnableLotIncrease = false when either refill brick is on.

//--- BRICK 6: SL (breakeven-lock) ---------------------------------------
input bool   InpEnableSL           = false;    // Add SL to winning side once armed?
input ENUM_SL_MODE InpSLMode       = SL_LAST_HIT_GRID; // SL placement mode if enabled
input int    InpSLNBack            = 1;        // SL_N_BACK_GRID only: steps back from last hit (1 = last hit's own level)

//--- BRICK 7: Cleanup type after SL hit / safety stop --------------------
input ENUM_CLEANUP_MODE InpCleanupMode = CLEANUP_CLOSE_ALL; // What "cleanup" means when triggered

//--- Margin
input double InpMinAllowedMargin = 1000.0; // Minimum free margin to allow grid ($)

//--- Time Filter
input bool   UseTimeFilter   = false; // Enable session time filter
input bool   EnableLondon    = true;  // Allow trading: London session
input bool   EnableNewYork   = true;  // Allow trading: New York session
input bool   EnableAsia      = false; // Allow trading: Asia session
input string ExtraWindow1    = "";    // Extra window 1: HH:MM-HH:MM (GMT)
input string ExtraWindow2    = "";    // Extra window 2: HH:MM-HH:MM (GMT)

//--- Commission (used in SL / net PnL safety calculation)
//input double InpCommissionPerLot = 6.0;  // Commission per lot round-turn ($)

//--- Magic Number (0 = auto from symbol + timeframe)
input int    InpMagicNumber  = 0;     // Magic number (0 = auto-generate)

//--- Broker fault tolerance (Bug 4/6: safety-net retry policy)
input int    InpSafetyRetryAttempts = 3;    // Attempts before a failed trade call triggers the safety stop
input int    InpSafetyRetryDelayMs  = 200;  // Delay between retry attempts (ms)

//--- Telegram alerting (safety-net notifications)
input bool   InpEnableTelegramAlerts = true; // Send Telegram alert on safety-stop trigger

//--- Dashboard
input bool   InpShowDashboard     = true;  // Show dashboard panel

//--- Timer
input int    InpTimerIntervalSec  = 1;     // Dashboard refresh interval (seconds)

//--- Logging
input bool   InpEnableDebugLog    = true;  // Debug logging to Experts tab
input bool   InpEnableHistoryLog  = true;  // History logging to CSV file
input string InpHistoryLogFile    = "HedgeGrid_History.csv"; // CSV filename

#endif
