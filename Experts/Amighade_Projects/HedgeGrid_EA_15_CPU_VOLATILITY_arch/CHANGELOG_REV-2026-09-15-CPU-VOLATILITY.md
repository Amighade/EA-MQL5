# REV-2026-09-15-CPU-VOLATILITY

Baseline: REV-2026-09-14-CLOSE-STYLE.

Purpose: reduce CPU spikes that become severe when market tick frequency
increases, while preserving event-driven close/cleanup behavior and keeping
safety-critical trade actions responsive.

## Engines/SLManager.mqh — heavy trail throttling

- Added a cheap early gate before `CalculateSLCandidate()` while the SL wall is
  armed. The heavy candidate calculation no longer runs on every tick.
- New inputs in `Inputs.mqh`: `InpSLTrailMinIntervalMs` (default 50 ms) and
  `InpSLTrailMinMoveTicks` (default 1 tick). A trail recalculation requires
  both the minimum time and minimum price movement, except for the first run
  after arming.
- The throttle does not cover initial SL arming, fill processing, cleanup
  confirmations, or loser-purge confirmations.
- The armed-winner snapshot is checked before entering the expensive candidate
  engine.

## Engines/SLGridFeasibility.mqh — O(1) grid-level calculation

- Replaced the `for(1..n)` stepping loop in `SL_GetGridLevel()` with equivalent
  direct arithmetic. Same level, less repeated work inside auto-search.

## HedgeGrid.mq5 — session cache

- Replaced unconditional per-tick `IsSessionAllowed()` with
  `GetCachedSessionAllowed(g_state)`.
- Session permission is recalculated only when the UTC minute bucket changes.

## HedgeGrid.mq5 — phantom-grid reconciliation

- Removed the standalone per-tick phantom-grid broker scan.
- Moved the same check into the existing ~2 second reconciliation window.

Why: the old check performed both position and order enumeration on every tick.
It is backstop work, so rate-limiting it removes a volatile-market multiplier
without removing the safety net.

## Deliberately unchanged

- No `Sleep()` added to any hot path.
- Confirmation-driven one-by-one close sequencing remains intact.
- `OnTradeTransaction()` remains the driver for close progression.
- No blanket "process every Nth tick" gate was added to fills/order placement.

## Tuning guidance

Defaults are conservative. For additional CPU reduction, increase
`InpSLTrailMinIntervalMs` gradually (for example 75 -> 100 ms) before increasing
`InpSLTrailMinMoveTicks`. Lower settings preserve faster trail response but use
more CPU.
