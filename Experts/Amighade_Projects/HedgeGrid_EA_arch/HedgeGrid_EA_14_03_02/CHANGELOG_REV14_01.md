# Rev14.01

- Starts from Rev13.01 and keeps its strategy modules and order/lot calculations.
- Removed `OnTick()` workload. A single 50 ms timer runs transaction processing, fast work, medium work, and the dashboard at separate intervals.
- `OnTradeTransaction()` now copies relevant broker facts to a queue; the timer handles deals and strategy reactions.
- Runtime trade calls still use synchronous `OrderSend()`.
- Removed retry `Sleep()` calls. Pending placement, close, and SL retries are capped at three per call.
- The initial grid defaults to three buy stops and three sell stops. `GetMaxLevels()` also caps the initial grid at three levels per side. Outside refill defaults to at most three orders per side.
- Cleanup advances one position at a time and does not advance a failed close. It verifies pending orders are gone before completing.
- Dashboard refresh defaults to two seconds.
- Grid checks use the Rev13.01 rules on the 500 ms medium timer; no new-bar gate was added.

## Verification

- Static checks completed for event-handler uniqueness, call-site references, include files, and remaining `Sleep()` calls.
- Native MetaEditor compilation and demo-account testing were not available here.
- The 8 ms scheduler budget is cooperative: it is checked between work units and cannot interrupt an `OrderSend()` or a loop already running inside a strategy engine.
- The 60 second background slot is reserved but has no Rev13.01 maintenance task assigned to it.
