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
   LOT_INC_NONE = 0,  // No Increasing
   LOT_INC_A = 1,  // Lot increase on opposite-side hit * 2
   LOT_INC_B = 2,  // Lot increase on opposite-side hit + 2
   LOT_INC_C = 3,  // STUB — reserved for future logic, currently no-op
  };

//--- Brick 2: shifting anchor
enum ENUM_SHIFT_ANCHOR
  {
   SHIFT_NONE           = 0,  // No Shift 
   SHIFT_LAST_HIT       = 1,  // Shift to align with the last hit level
   SHIFT_FARTHEST_HIT   = 2,  // Shift to align with the farthest hit level
   SHIFT_PRICE          = 3,  // Shift to align with current price
  };

//--- Brick 6: SL grid-snap mode
enum ENUM_SL_MODE
  {
   SL_NONE           = 0,  // No SL
   SL_P_LEVEL        = 1,  // SL = FIRST POSITIVE LEVEL (no grid)
   SL_NO_GRID        = 2,  // SL = NEAREST GRID (no net check) 
   SL_LAST_HIT_GRID  = 3,  // SL = AUTO SEARCH (nearest-first valid wins)
   SL_N_BACK_GRID    = 4,  // SL = AUTO SEARCH (farthest-first valid wins)
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

enum ENUM_INSIDE_MAINTENANCE_STYLE 
   { 
   MAINTENANCE_NONE = 0, 
   MAINTENANCE_THRESHOLD = 1, 
   MAINTENANCE_FOLLOW_PRICE = 2 
   };
enum ENUM_INSIDE_STRATEGY_STYLE    
   { 
   STRATEGY_NONE = 0, 
   STRATEGY_REVISIT = 1, 
   STRATEGY_PASS_REFILL = 2 
   };
enum ENUM_OUTSIDE_REFILL_STYLE 
   { 
   OUTSIDE_NONE = 0, 
   OUTSIDE_FIXED = 1, 
   OUTSIDE_LAST_LOT = 2, 
   OUTSIDE_LADDER = 3, 
   OUTSIDE_EXP = 4 
   };

enum ENUM_REVISIT_LOT_STYLE
{
   REVISIT_FIXED     = 0,   // always InpFixedLot, ignores visit count
   REVISIT_LINEAR    = 1,   // baseLot x (visits+1)
   REVISIT_STEP      = 2,   // baseLot x (1 + InpRevisitLotStep x visits)
   REVISIT_FIBONACCI = 3    // baseLot x fib(visits+1)
};

enum ENUM_RUNAWAY_TRIGGER
{
   RUNAWAY_TRIGGER_NONE        = 0,
   RUNAWAY_TRIGGER_CONSECUTIVE = 1,
   RUNAWAY_TRIGGER_GRID_DEPTH  = 2,
   RUNAWAY_TRIGGER_PASSCOUNTER = 3
};

enum ENUM_RUNAWAY_ACTION
{
   RUNAWAY_ACTION_ADD_SL   = 0,   
   RUNAWAY_ACTION_CLOSE_ALL = 1   
};

//double InpCommissionPerLot = 0.0;
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
input double InpPassRefillLotAdd = 0.0;   // Pass refill: amount added to a level's original lot on each reversal

//--- BRICK 1: Lot increase on opposite-side hit -----------------------
input ENUM_LOT_INCREASE_MODE InpLotIncreaseMode = LOT_INC_NONE; // Lot increase on opposite-side hit

//--- BRICK 2: Shifting on gap ------------------------------------------
input ENUM_SHIFT_ANCHOR InpShiftAnchor = SHIFT_NONE; // Anchor used if shifting enabled

//--- BRICK 3: Recentering ----------------------------------------------
input bool   InpEnableRecentering  = false;    // Recenter grid when fresh and off-center?
input double InpThresholdFactor    = 3.0;      // Recenter zone divisor (gap / factor = trigger threshold)

//--- BRICK 4: Refill inside gap -----------------------------------------
input ENUM_INSIDE_MAINTENANCE_STYLE InpInsideMaintenanceStyle = MAINTENANCE_NONE;
input ENUM_INSIDE_STRATEGY_STYLE    InpInsideStrategyStyle    = STRATEGY_NONE;
input ENUM_REVISIT_LOT_STYLE InpRevisitLotStyle = REVISIT_LINEAR;  // Revisit style: lot growth formula
input double                 InpRevisitLotStep  = 0.5;             // Revisit style: growth rate, used by REVISIT_STEP only
input double                 InpRevisitLotMax   = 0.20;            // Revisit style: hard lot cap, applied to every formula
//--- BRICK 5: Refill outside range --------------------------------------
input ENUM_OUTSIDE_REFILL_STYLE InpOutsideRefillStyle = OUTSIDE_NONE;   // Refill outside levels when count drops below InpMinGridLevels?

//--- BRICK 6: SL (breakeven-lock) ---------------------------------------
input ENUM_SL_MODE InpSLArmMode   = SL_NONE;      // SL mode used when first arming
input ENUM_SL_MODE InpSLTrailMode = SL_NONE;      // SL mode used when trailing an already-armed SL

input int    InpSLNBack            = 1;        // SL_N_BACK_GRID only: steps back from last hit (1 = last hit's own level)

//--- BRICK 7: Cleanup type after SL hit / safety stop --------------------
input ENUM_CLEANUP_MODE InpCleanupMode = CLEANUP_CLOSE_ALL; // What "cleanup" means when triggered

input ENUM_RUNAWAY_TRIGGER InpRunawayTrigger = RUNAWAY_TRIGGER_NONE;
input ENUM_RUNAWAY_ACTION  InpRunawayAction  = RUNAWAY_ACTION_ADD_SL;
input int                  InpRunawayN       = 5;

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
input double InpCommissionPerLot = 0.0;  // Commission per lot round-turn ($)
// gold 6

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
