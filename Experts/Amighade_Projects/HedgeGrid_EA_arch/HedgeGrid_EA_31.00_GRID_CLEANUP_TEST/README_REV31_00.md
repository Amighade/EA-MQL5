# HedgeGrid Rev31.00 — grid cleanup test

This is a copy of the reviewed Rev30.04 async infrastructure with one opt-in integration test. Normal behavior is unchanged while `InpRunGridCleanupTest` is `false`.

When enabled from an empty EA trade book, the test submits three `BUY_STOP` orders above Ask and three `SELL_STOP` orders below Bid. Adjacent levels are spaced by 0.5 in symbol price units. The first level is moved farther out when needed to satisfy the symbol's advertised minimum stop distance. Each order uses the symbol's minimum volume.

When a test order fills, its deal is matched to the position item and the existing `StartCleanup()` path routes CLOSE to every EA-owned live position and DELETE to every EA-owned pending order. If a live test position is adopted by reconciliation before its deal callback is consumed, the fast test check also starts cleanup from that confirmed item. The test reports PASS only after reconciliation and terminal counts confirm zero EA-owned positions and zero EA-owned pending orders. If a placement fails, it starts cleanup and reports FAIL after the broker state is flat.

Leave the test input enabled while waiting for a fill. If price never reaches an order, the test remains pending. Run it in the Strategy Tester or on a demo account. Disable the input after PASS; changing an input restarts the EA.

The test uses `Strategy_Fast()` and `Strategy_OnEntryFill()` in `Engines/StrategyBridge.mqh`, `RequestPlacePending()` / cleanup action routing already in `Utils/AsyncTrade.mqh` and `Engines/CleanupEngine.mqh`, and the new `InpRunGridCleanupTest` switch in `Inputs.mqh`. `OnTradeTransaction()`, reconciliation, and `ProcessPendingActions()` were not given separate test-only send paths.

If price does not reach an order, the test remains pending with the grid live; it has no timer-based expiry. It starts only when the EA trade book is empty and idle. Since its one-shot state resets when the EA is reinitialized, turn the input off after the test or it will run again after a restart.

The C++ harness verifies six planned orders and first-fill routing to one CLOSE plus five DELETE commands. The existing cleanup regressions verify asynchronous confirmation and zero/zero completion. All 28 lifecycle groups, 8 race groups, and 2,000 randomized broker runs pass. This is not a native MetaEditor build or an MT5 broker test; compile and run this EA in the Strategy Tester or demo terminal before relying on broker-specific stop-distance behavior.
