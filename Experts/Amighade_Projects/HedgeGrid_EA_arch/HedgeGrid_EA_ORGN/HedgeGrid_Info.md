# HedgeGrid EA — Master Specification Document

> This document is the single source of truth for the HedgeGrid Expert Advisor.
> It covers strategy rules, cycle flowchart, engine architecture, file structure,
> and input parameters. Update this document whenever a rule changes.

---

## TABLE OF CONTENTS

1. Strategy Overview
2. Core Definitions
3. Strategy Rules (complete)
4. Cycle Flowchart
5. Engine Architecture
6. File Structure
7. Input Parameters
8. Edge Case Handling
9. Closing Styles
10. Dashboard & Logging

---

## 1. STRATEGY OVERVIEW

HedgeGrid is a hedging grid Expert Advisor designed for XAUUSD (Gold).
It places a symmetric grid of BUY STOP and SELL STOP orders around the
current price. As price hits orders, the opposite grid is rebuilt with
doubled lot sizes. The strategy uses pass counters to track direction
switches and applies Stop Loss to profitable positions when a threshold
is reached, followed by full cleanup and cycle restart.

The EA is built as a pluggable framework — each engine has interchangeable
style implementations (Style A, Style B, etc.) selected via a single
master input. New styles can be added without touching other engines.

---

## 2. CORE DEFINITIONS

```
Unit of price       : $1.00 in XAUUSD (e.g. 4030.00 to 4031.00 = 1 unit)
Grid spacing        : $0.50 between each order level
Grid levels         : 20 orders per side (BUY side + SELL side)
Initial gap         : $2.00 total between nearest BUY and nearest SELL order
                      = $1.00 above price (first BUY STOP)
                      = $1.00 below price (first SELL STOP)
Fresh grid          : No open positions, all 40 orders placed (20 each side)
Active cycle        : At least one order has been filled (position open)
Pass counter        : Tracks how many direction switches have occurred
Direction switch    : Price moves from hitting BUY orders to hitting SELL orders
                      or vice versa
Block lot           : The uniform lot size of the rebuilt opposite grid
                      after a doubling event
```

---

## 3. STRATEGY RULES

### 3.1 Initial Grid Setup

```
Trigger         : EA start, or immediately after full cycle cleanup
Condition       : No open positions, session allowed

BUY STOP grid:
  First order   : currentPrice + $1.00
  Each next     : +$0.50
  Lot sizes     : 0.01, 0.02, 0.03 ... 0.20 (20 levels)

SELL STOP grid:
  First order   : currentPrice - $1.00
  Each next     : -$0.50
  Lot sizes     : 0.01, 0.02, 0.03 ... 0.20 (20 levels)

Placement sequence (symmetric, based on current candle direction):
  If bullish candle: SELL 0.01 → BUY 0.01 → SELL 0.02 → BUY 0.02 ...
  If bearish candle: BUY 0.01 → SELL 0.01 → BUY 0.02 → SELL 0.02 ...
```

### 3.2 Pass Counter Logic

```
New grid placed          : counter = 0
1st hit to SELL grid     : counter = 1
  Continue hitting SELL  : counter stays 1
1st hit to BUY grid      : counter = 2
  Continue hitting BUY   : counter stays 2
2nd hit to SELL grid     : counter = 3
  Continue hitting SELL  : counter stays 3
2nd hit to BUY grid      : counter = 4
  ...and so on

Direction switch detected via OnTradeTransaction:
  First fill in new direction = direction switch confirmed

Rule:
  counter < 2  → 1st pass lot update logic applies
  counter >= 2 → 2nd pass lot update logic applies (full replacement)
```

### 3.3 Lot Update Rules

#### 1st Pass (counter < 2):
```
When BUY order is hit:
  newLot = hitLot × 2
  For each pending SELL order:
    If order.lot < newLot → update order lot to newLot
    If order.lot >= newLot → leave unchanged

Example (fresh SELL grid: 0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07...):
  Hit BUY 0.01 → newLot=0.02 → update: 0.01→0.02, rest unchanged
  Hit BUY 0.02 → newLot=0.04 → update: 0.02,0.02,0.03→0.04, rest unchanged
  Hit BUY 0.03 → newLot=0.06 → update: 0.04,0.04,0.04,0.04,0.05→0.06, rest unchanged

Same logic applies when SELL orders are hit (updates BUY grid)
```

#### 2nd Pass (counter >= 2):
```
When any order is hit:
  newLot = hitLot × 2
  ALL pending opposite orders → replaced with newLot
  No exceptions

Example:
  Hit BUY 0.06 (counter=2) → ALL SELL orders → 0.12
  Hit SELL 0.12 (counter=3) → ALL BUY orders → 0.24
```

### 3.4 Grid Shift Rules

```
Triggered every time any order is hit (position opened)

Shift constraint (ALWAYS both rules apply, take the more conservative):
  Rule 1: New grid anchor = currentPrice ± $1.00
  Rule 2: New grid anchor must be at least $2.00 from last hit order price
  → Take whichever anchor is further from current price

After anchor calculated:
  Delete ALL existing opposite pending orders
  Rebuild opposite grid from new anchor
  Apply same spacing ($0.50) and same level count (20)
  Apply current block lot size to all new orders
  Use symmetric placement sequence (based on current candle direction)
```

### 3.5 Gap Maintenance

```
Gap between nearest BUY order and nearest SELL order is self-regulating:
  Initial gap = $2.00
  When any order is hit → that side moves $0.50 closer
  → Opposite grid shifts $0.50 to restore $2.00 gap
  → No hysteresis needed, no continuous monitoring needed
  → Gap naturally maintained by hit-based shifting
```

### 3.6 Recentering (Fresh Grid Only)

```
Applies ONLY when: no positions open (fresh grid state)
Disabled once: first order is filled

Formula:
  recenter_threshold = InitialGap / ThresholdFactor  (input)
  x = (InitialGap - recenter_threshold) / 2

Valid zone (no recenter needed):
  firstSellOrder - x < currentPrice < firstSellOrder + x

If price outside valid zone:
  Trigger: every new candle
  Action: delete all orders, rebuild grid around current price
```

### 3.7 SL Trigger Conditions

```
Two independent triggers (either can activate SL):

Trigger 1 — By lot threshold:
  When latest filled position lot >= SLTriggerLot (input)

Trigger 2 — By basket profit:
  When total basket profit turns positive

On trigger:
  Calculate SL level for winning side
  Apply SL to all qualifying positions
  Wait for SL to be hit
  After SL hit → execute cleanup
```

### 3.8 SL Level Calculation

```
Winning side = direction with most profitable open positions

Breakeven calculation:
  totalCost  = sum(entryPrice × lot) for all positions on winning side
  totalLots  = sum(lot) for all positions on winning side
  breakeven  = totalCost / totalLots

SL level:
  SLLevel = MAX(breakeven, lastEntryPrice on winning side)

Constraint:
  SL must never be placed between a position and current price
  (SL always beyond the position relative to price direction)

Apply SL to:
  All open positions on winning side where price has already passed them
  AND price is currently in favor of that position direction
```

---

## 4. CYCLE FLOWCHART

```
┌─────────────────────────────────┐
│         EA START / RESTART      │
│  Check margin → Check session   │
│  Build initial grid             │
│  counter = 0                    │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│         FRESH GRID STATE        │
│  Monitor: recentering needed?   │
│  If price outside valid zone    │
│  → rebuild grid around price    │
└────────────────┬────────────────┘
                 │ First order filled
                 ▼
┌─────────────────────────────────┐
│        ORDER FILLED EVENT       │
│  (OnTradeTransaction)           │
│  Detect: direction, lot, price  │
│  Update: pass counter           │
└────────────────┬────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
┌──────────────┐  ┌──────────────┐
│  1st PASS    │  │  2nd PASS    │
│  counter < 2 │  │ counter >= 2 │
│              │  │              │
│ Update SELL  │  │ Replace ALL  │
│ orders where │  │ opposite     │
│ lot < newLot │  │ orders with  │
│ to newLot    │  │ newLot       │
└──────┬───────┘  └──────┬───────┘
        └────────┬────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│         SHIFT OPPOSITE GRID     │
│  Calculate new anchor           │
│  MAX($1 from price, $2 from     │
│  last hit order)                │
│  Delete old opposite orders     │
│  Rebuild at new anchor          │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│       CHECK SL TRIGGERS         │
│  Trigger 1: blockLot >= input   │
│  Trigger 2: basketProfit > 0    │
└────────────────┬────────────────┘
                 │
        ┌────────┴────────┐
        │ triggered        │ not triggered
        ▼                 ▼
┌──────────────┐  ┌──────────────┐
│  APPLY SL    │  │  CONTINUE    │
│  Calculate   │  │  Wait for    │
│  SL level    │  │  next order  │
│  Apply to    │  │  fill        │
│  qualifying  │  └──────────────┘
│  positions   │
└──────┬───────┘
       │ SL hit
       ▼
┌─────────────────────────────────┐
│         CLEANUP & RESET         │
│  Close remaining positions      │
│  (confirmation based sequence)  │
│  Delete all pending orders      │
│  Reset all state variables      │
│  counter = 0                    │
└────────────────┬────────────────┘
                 │
                 ▼
         Back to EA START
```

---

## 5. ENGINE ARCHITECTURE

### Design Principles
```
- Function-based multi-file (not class-based)
- Each engine owns its own functions, touches nothing outside its scope
- All shared state lives in GridState.mqh
- No engine calls another engine directly
- All inter-engine communication goes through HedgeGrid.mq5 (coordinator)
- Pluggable engines: single StrategyStyle input drives all related engines
```

### Pluggable Engine Selector
```
Input: StrategyStyle (enum)
  STYLE_A → GridBuilder_A + SizingEngine_A + ShiftingEngine_A
  STYLE_B → GridBuilder_B + SizingEngine_B + ShiftingEngine_B

One selector links all related engines — no mixing of incompatible styles
Each engine file contains all style implementations + one master function
Master function reads StrategyStyle and calls correct implementation
```

### Engine Interfaces

#### E1 — GridBuilder
```
Purpose : Build complete BUY/SELL grid from scratch
Pluggable: Yes

Master function:
  BuildGrid(price, lotMode)
    → calls BuildGrid_A() or BuildGrid_B() based on StrategyStyle

Input  : currentPrice, lotMode (FULL | HALF)
Output : 40 pending orders placed (20 BUY + 20 SELL)
         Updates GridState: gridPlaced, firstBuyPrice, firstSellPrice
```

#### E2 — OrderMonitor
```
Purpose : Detect filled orders, track direction and counter
Pluggable: No

Functions:
  OnOrderFilled(ticket)
  IsDirectionSwitch() → bool
  GetHitDirection()   → BUY | SELL
  GetHitLot()         → double
  GetHitPrice()       → double

Input  : OnTradeTransaction event data, current GridState
Output : Updates GridState: passCounter, lastHitLot, lastHitPrice,
                            lastHitDirection, lastHitTime
```

#### E3 — GridUpdater
```
Purpose : Update opposite grid lot sizes after a hit
Pluggable: No (lot update rules are fixed by strategy)

Functions:
  UpdateOppositeGrid(hitDirection, hitLot, passCounter)
  GetNewLot(hitLot) → double

Input  : hitDirection, hitLot, passCounter, current pending orders
Output : Modified opposite pending orders (lot sizes updated)
         Updates GridState: currentBlockLot
```

#### E4 — SizingEngine
```
Purpose : Calculate lot size for each grid level
Pluggable: Yes

Master function:
  GetLot(level, lotMode) → double
    → calls GetLot_A() or GetLot_B() based on StrategyStyle

Style A : Ladder (0.01 × level, capped at 0.20)
Style B : Fixed lot from input (all levels same size)

Input  : level (1-20), lotMode (FULL | HALF)
Output : lot size for that level
```

#### E5 — ShiftingEngine
```
Purpose : Delete and rebuild opposite grid at new anchor
Pluggable: Yes

Master function:
  ShiftGrid(hitDirection, currentPrice, lastHitPrice)
    → calls ShiftGrid_A() or ShiftGrid_B() based on StrategyStyle

Style A : Shift based on hit + 2$ rule (current strategy)
Style B : Append new order at grid distance (no full rebuild)

Input  : hitDirection, currentPrice, lastHitPrice, currentBlockLot
Output : Old opposite orders deleted, new grid placed at new anchor
         Updates GridState: anchorBuy, anchorSell
```

#### E6 — SLManager
```
Purpose : Monitor SL triggers, calculate and apply SL levels
Pluggable: No

Functions:
  CheckSLTrigger()              → bool
  CalculateSLLevel(direction)   → double
  ApplySLToPositions(direction, slLevel)

Input  : GridState (currentBlockLot, basketProfit), open positions
Output : SL applied to qualifying positions
         Updates GridState: slApplied, slLevel
```

#### E7 — CleanupReset
```
Purpose : Close all positions/orders and reset cycle
Pluggable: No

Functions:
  ExecuteCleanup(cleanupType)
  CloseNextPosition()       // confirmation-based, called per OnTradeTransaction
  DeleteAllOrders()
  ResetState()

CleanupType:
  EMERGENCY   → close all immediately regardless of sequence
  PROFIT      → SL-based, confirmation sequence
  RANGE       → SL-based, confirmation sequence
  SL_HIT      → after SL fires, close remaining, confirmation sequence

Input  : cleanupType, open positions, pending orders
Output : All positions closed, all orders deleted, GridState reset
         Triggers GridBuilder after reset complete
```

#### E8 — StatePersistence
```
Purpose : Save and restore GridState via GlobalVariables
Pluggable: No

Functions:
  SaveState()
  LoadState()
  ClearState()

Note    : EA restarts fresh (LoadState not used on restart)
          StatePersistence used for mid-session reconnects only

Key format: "HG_" + _Symbol + "_" + IntegerToString(_Period) + "_" + keyName
```

#### E9 — Recentering
```
Purpose : Keep fresh grid centered around current price
Pluggable: No (only active during fresh grid state)

Functions:
  CheckRecenterNeeded(currentPrice) → bool
  RecenterGrid(currentPrice)

Formula:
  recenter_threshold = InitialGap / ThresholdFactor
  x = (InitialGap - recenter_threshold) / 2
  valid zone: firstSellOrder - x < price < firstSellOrder + x

Input  : currentPrice, GridState (anchorSell, noPositionsOpen)
Output : Rebuilt grid if price outside valid zone
         Updates GridState: anchorBuy, anchorSell
```

#### E10 — MarginCheck
```
Purpose : Validate margin before grid placement
Pluggable: No

Functions:
  CheckMargin()                     → OK | HALF_LADDER | BLOCK
  GetRequiredMargin(lotMode)        → double
  TriggerMarginAlarm(message)

Input  : MinAllowedMargin (input), current free margin
Output : lotMode recommendation (FULL | HALF)
         Alarm if margin insufficient
         Blocks EA if margin below minimum threshold
```

---

## 6. FILE STRUCTURE

```
MQL5/Experts/HedgeGrid_EA/
│
├── HedgeGrid.mq5                // Coordinator: OnInit/OnTick/OnTradeTransaction
│                                // Calls engines in correct sequence
│                                // Never contains trading logic directly
│
├── Inputs.mqh                   // ALL input parameters and enums
│                                // Single source for all configurable values
│
├── Models/
│   └── GridState.mqh            // Central state struct shared across all engines
│                                // All engines read/write through this struct
│
├── Engines/
│   ├── GridBuilder.mqh          // E1: Build initial grid (pluggable)
│   ├── SizingEngine.mqh         // E4: Lot size per level (pluggable)
│   ├── ShiftingEngine.mqh       // E5: Shift opposite grid (pluggable)
│   ├── OrderMonitor.mqh         // E2: Detect fills, update counter
│   ├── GridUpdater.mqh          // E3: Update opposite grid lots
│   ├── SLManager.mqh            // E6: SL trigger and application
│   ├── CleanupReset.mqh         // E7: Close all, reset cycle
│   ├── StatePersistence.mqh     // E8: GlobalVariable save/load
│   ├── Recentering.mqh          // E9: Fresh grid recentering
│   └── MarginCheck.mqh          // E10: Margin validation
│
├── Utils/
│   ├── TradeUtils.mqh           // Order place/delete/modify wrappers
│   ├── MathUtils.mqh            // Breakeven, lot rounding, gap calculations
│   ├── SessionFilter.mqh        // London/NY/Tokyo + 2 custom windows
│   ├── DebugLogger.mqh          // Experts tab logging (debug)
│   └── HistoryLogger.mqh        // CSV file logging (history/survey)
│
├── Dashboard/
│   └── ChartPanel.mqh           // Visual panel + emergency close button
│
└── HedgeGrid_Info.md            // This document
```

---

## 7. INPUT PARAMETERS

### Strategy Selection
```
StrategyStyle        // STYLE_A | STYLE_B — drives all pluggable engines
```

### Grid Settings
```
InitialGap           // Total gap between nearest BUY and SELL (default: 2.00)
GridSpacing          // Distance between levels (default: 0.50)
GridLevels           // Orders per side (default: 20)
```

### Sizing Settings (Style A)
```
InitialLotStep       // Lot increment per level (default: 0.01)
InitialLotCap        // Max lot in initial ladder (default: 0.20)
```

### Sizing Settings (Style B)
```
FixedLot             // Fixed lot size for all levels
```

### SL Trigger Settings
```
SLTriggerByLot       // true/false — enable lot-based trigger
SLTriggerLot         // Lot threshold (default: 0.24)
SLTriggerByProfit    // true/false — enable profit-based trigger
```

### Closing Settings
```
RangeCloseLot        // Lot threshold for In-Range Close trigger
```

### Margin Settings
```
MinAllowedMargin     // Minimum free margin to allow grid placement
```

### Recentering Settings
```
EnableRecentering    // true/false
ThresholdFactor      // Divisor for recenter threshold (default: 3.0)
```

### Session Settings
```
UseLondonSession     // true/false (08:00-17:00 GMT)
UseNewYorkSession    // true/false (13:00-22:00 GMT)
UseTokyoSession      // true/false (00:00-09:00 GMT)
UseCustomWindow1     // true/false
CustomWindow1_Start  // Time string "HH:MM"
CustomWindow1_End    // Time string "HH:MM"
UseCustomWindow2     // true/false
CustomWindow2_Start  // Time string "HH:MM"
CustomWindow2_End    // Time string "HH:MM"
OutsideSessionAction // STOP_NEW_CYCLES | CLOSE_ALL
```

### Magic Number
```
MagicNumber          // 0 = auto-generate from symbol+timeframe hash
                     // >0 = use this number (user responsibility for uniqueness)
```

### Dashboard
```
ShowDashboard        // true/false
```

### Logging
```
EnableDebugLog       // true/false — Experts tab output
EnableHistoryLog     // true/false — CSV file output
HistoryLogFile       // filename for CSV log
```

---

## 8. EDGE CASE HANDLING

### Gap/Skip Detection (Broker Fault)
```
Condition : Price passes an order level without execution
            (order still pending but price has moved beyond it)
Action    : Emergency close triggered automatically
            Fault logged to Experts tab AND CSV file
            Details: time, price, order ticket, expected fill price
Note      : This is a broker server issue — log for broker report
```

### Market Gap on Open
```
Condition : Price gaps over multiple grid levels at market open
Action    : If grid placed → continue (orders execute at next available price)
            If no grid → place fresh grid around current price
```

### Margin Insufficient
```
Checked   : OnInit + before every grid placement
Condition : Free margin < MinAllowedMargin input
Action    : Switch to half ladder (0.01→0.10, 10 levels)
            Trigger alarm (Experts tab + sound)
            Stay on half ladder for entire remaining cycle
            Reset to full ladder only on next cycle restart
            If margin critically low → block EA, require user intervention
```

### EA Restart Mid-Cycle
```
Action    : Always start fresh
            Cancel all existing orders
            Close all existing positions
            Rebuild grid around current price
            counter = 0
```

### Rapid Direction Switches
```
Condition : Price hits BUY → SELL → BUY in quick succession
Action    : Counter increments normally (0→1→2)
            counter >= 2 triggers full grid replacement
            This is acceptable and by design
```

---

## 9. CLOSING STYLES

### Style 1 — Emergency Close (Manual)
```
Trigger   : Dashboard button press
Action    : Close ALL positions and orders immediately
            No sequence, no conditions
            Confirmation-based: send → confirm → send next
Use case  : Manual intervention, critical situations
```

### Style 2 — In-Profit Close (SL Based)
```
Trigger   : Basket profit turns positive
Action    : Calculate SL level for winning side
            Apply SL to all qualifying profitable positions
            Wait for SL hit
            After SL hit → close remaining via confirmation sequence
```

### Style 3 — In-Range Close (Lot Threshold Based)
```
Trigger   : Latest filled position lot >= RangeCloseLot input
Action    : Same as In-Profit Close (SL logic + confirmation sequence)
            Differs only in trigger condition
```

### Confirmation-Based Close Sequence
```
Send close command → wait for OnTradeTransaction confirmation
→ send next close command → wait → repeat until all closed

Position close order (profit/loss alternating):
  biggest positive → biggest negative → next biggest positive → ...

Order delete sequence (symmetric by candle direction):
  If bullish candle: closest BUY → closest SELL → next BUY → next SELL...
  If bearish candle: closest SELL → closest BUY → next SELL → next BUY...
```

---

## 10. DASHBOARD & LOGGING

### Dashboard Display
```
- Pass counter (current value)
- Current block lot size
- Basket profit/loss (total)
- Session status (active/inactive + which session)
- Margin status (OK | WARNING | CRITICAL)
- Strategy style (A | B)
- Emergency Close button
```

### Debug Logger (Experts Tab)
```
Events logged:
  - Grid built (anchor price, lot mode)
  - Order filled (ticket, direction, lot, price)
  - Counter updated (old → new)
  - Grid shifted (old anchor → new anchor)
  - Lot updated (which orders, old lot → new lot)
  - SL triggered (trigger type, SL level)
  - Cleanup started (cleanup type)
  - Cleanup complete
  - Margin warning
  - Gap/fault detected
  - Session change
```

### History Logger (CSV File)
```
Template columns (to be populated):
  DateTime, EventType, Symbol, Timeframe, Price,
  Direction, Lot, PassCounter, BlockLot, BasketProfit,
  SessionActive, MarginFree, Notes

File: defined by HistoryLogFile input
Format: CSV, one row per event
Purpose: Post-session analysis and strategy survey
```

---

---

## 11. EVENT HANDLERS

### OnInit
```
- Validate inputs
- Check margin
- Generate/set magic number
- Initialize GridState
- Check session
- Build initial grid
- Initialize dashboard
- Initialize loggers
```

### OnTick
```
- Check recentering (fresh grid only, every new candle)
- Update dashboard display
- Check session status
- Feed basket profit to GridState for SL trigger monitoring
```

### OnTradeTransaction
```
- Detect order fills (position opens)
- Update pass counter
- Trigger GridUpdater
- Trigger ShiftingEngine
- Trigger SLManager check
- Handle confirmation-based close sequence
- Detect gap/skip faults
```

### OnTimer
```
- Dashboard refresh at fixed interval (avoid tick-level refresh cost)
- Margin check at fixed interval
```

### OnDeinit
```
- Save state to GlobalVariables
- Clean up dashboard objects
- Close log files
```

### OnChartEvent
```
- Detect emergency close button press on dashboard
```

---

*Document version: 1.1*
*Status: Strategy specification complete — ready for coding*
