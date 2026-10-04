# Rev31.01 — initial-grid retry fix

Rev31.01 keeps the Rev22.2 strategy and Rev30.04 async trade path from Rev31.00. It fixes initial grid recovery and adds a distinguishing runtime version.

## Fix

- The initial grid verifier now also checks `GRID_BUILDING`, after outstanding initial PLACE requests have resolved. Previously it checked only `GRID_READY` and `GRID_ACTIVE`, so a partial grid could remain while the cycle still reported BUILDING.
- A missing initial order routes the cycle through existing cleanup: close any positions and delete live pending orders.
- A rejected cancel is retried through the existing async request path. A new full grid is built only after broker reconciliation confirms zero EA positions and zero pending orders.
- The source and startup log identify this package as Rev31.01. The Experts log should show `[REV31.01] started` after the new source is compiled and attached.

## Validation

27 lifecycle groups, 8 race groups, 4 strategy groups and 2,000 broker stress trials passed in the translated C++ harness. The partial-grid strategy scenario includes an invalid placement, a rejected cancel, retry, live confirmation, full cleanup and rebuild. Native MetaEditor compilation and MT5 demo/tester execution remain unverified.
