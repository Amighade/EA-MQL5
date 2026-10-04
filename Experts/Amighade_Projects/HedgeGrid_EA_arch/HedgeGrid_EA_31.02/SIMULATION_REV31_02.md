# Rev31.02 bounded-request validation

## Change exercised

`ProcessPendingActions()` now caps in-flight async requests at the existing `InpCleanupAsyncBatch` value (default 3) for all actions. A request remains in flight through WAIT_RESULT and WAIT_CONFIRM; the next ready action is sent only after reconciliation confirms the prior broker state or a definitive failure resolves it.

## Results

- 27 lifecycle scenario groups passed.
- 8 broker-event race groups passed.
- 4 strategy scenario groups passed, including the three-request placement cap and initial-grid partial cleanup/rebuild.
- 2,000 randomized broker timelines passed.
- Translated C++ harness only. Native MetaEditor compile and MT5 demo/tester run were not available.

The user's journal shows exceptionally long broker completion times and price-sensitive invalid/cancel rejections. This validation confirms request pacing and the existing recovery logic in the model. It does not establish how quickly a live broker will process requests.
