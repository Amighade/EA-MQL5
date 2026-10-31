HedgeGrid_EA_14_02_07_02_w_timeelapes

BASELINE
Uploaded HedgeGrid_EA_14_02_07.zip, plus your confirmed correction:
if(InpRunawayN == 0 || InpRunawaySLArmMode == SL_NONE) return;
No other strategy, trade routing, scheduler intervals or retry rules changed.

BUILD AND ENABLE
Compile HedgeGrid.mq5 in MetaEditor. No old HedgeGrid.ex5 is included.
Set InpEnableTimeGauge=true to enable. Default=false.
InpTimeGaugeMinMs=1.0 shows only functions whose maximum elapsed time in
that window reaches 1 ms. Set 0 to show all called measured functions.
Independent of InpEnableDebugLog and InpEnableHistoryLog.

REPORT
Experts log: [TIME 14_02_07_02], approximately every 10 seconds, plus a final
partial report on deinitialization when enabled. A blocking call can delay
the report; Window shows the actual measured reporting interval.
Calls: calls completed in the window.
Last / Avg / Max / Total: elapsed milliseconds in the window.
MaxAll: maximum elapsed milliseconds since EA initialization.
Nested parent and child durations overlap: do NOT add them together.
Elapsed time includes synchronous broker/network waits, not CPU usage.

MEASURED
32 function scopes cover scheduler, transaction processing, grid build/refill,
opposite-grid updates, aggregate/fill handling, runaway trigger, SL candidate/
arming/trailing/application/snapshot, cleanup, safety stop, margin, dashboard,
history logging, Telegram and state persistence.
OrderSend.Pending/Delete/Close/SL/Other measures each actual synchronous
OrderSend call. HistoryDealSelect measures selection of the incoming deal.
Compare raw API time with its enclosing function to locate the delay.
No per-call prints, history scans, trade requests or chart objects are added.
Counters use fixed arrays; disabled gauges do not read the stopwatch.
The report itself runs after RunScheduler and is not included in its duration.

VALIDATION
All original source files matched after removing instrumentation and reversing
only the confirmed zero-disable correction. Local includes resolve.
Source-adapted C++ replay passed with timing disabled and enabled. Deterministic
gauge checks covered early returns, nesting, reset and retained lifetime maximum.
Native MetaEditor compilation and MT5 runtime validation were unavailable.
