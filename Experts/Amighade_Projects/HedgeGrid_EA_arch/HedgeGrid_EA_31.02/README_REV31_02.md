# HedgeGrid Rev31.02 — Rev22.2 strategy on async infrastructure

Rev31.02 keeps the Rev22.2 strategy and the Rev30.04 asynchronous infrastructure. The async sender allows at most three outstanding requests by default. It waits for their result and broker state before sending more ready work. Adjust the existing `InpCleanupAsyncBatch` input to change that limit; the input name remains unchanged for saved settings.

An incomplete initial grid still enters cycle-wide cleanup. The next grid is built only after reconciliation confirms zero EA-owned positions and zero EA-owned pending orders. Rev31.02 does not change grid geometry, lot rules, SL rules, strategy options, or scheduler tiers.

The supplied terminal journal shows unusually long request completion times, stale-price rejections, and cancel rejections near market. The sender limit prevents flooding later requests while earlier ones remain unresolved, but it cannot reduce broker/network latency.

See `CHANGELOG_REV31_02.md` for the change and `Validation/README.md` for simulation coverage. These checks do not replace MetaEditor compilation or an MT5 demo/tester run.
