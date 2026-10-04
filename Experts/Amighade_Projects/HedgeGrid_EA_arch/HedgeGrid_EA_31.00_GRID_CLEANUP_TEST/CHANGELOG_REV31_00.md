# Rev31.00 — grid cleanup integration test

- Added a default-off test that places three pending stops on each side of the current market, spaced by 0.5 price units.
- A first fill starts the existing cycle-wide cleanup: close all EA-owned positions and delete all EA-owned pending orders.
- A reconciled test position also starts cleanup if its deal callback has not yet been consumed.
- Rejected test placements start cleanup so accepted test orders are not left behind.
- Added test-only logging and a regression scenario for grid construction and fill-triggered cleanup routing.
- No production grid, lot progression, SL, shifting, or recentering strategy was added.
