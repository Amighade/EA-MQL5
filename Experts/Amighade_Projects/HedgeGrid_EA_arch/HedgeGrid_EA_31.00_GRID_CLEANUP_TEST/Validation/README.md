# Two-way simulated-terminal validation

These files are not included by the EA. No account is accessed. The builder adapts the current MQL function bodies to C++; the tests execute those bodies against a modeled terminal and broker.

From the extracted package directory, with Python 3 and a C++17 compiler:

```sh
python3 Validation/build_harness.py
g++ -std=c++17 -O1 -D_GLIBCXX_ASSERTIONS Validation/lifecycle_tests.cpp -o Validation/lifecycle_tests
./Validation/lifecycle_tests
g++ -std=c++17 -O1 -D_GLIBCXX_ASSERTIONS Validation/race_tests.cpp -o Validation/race_tests
./Validation/race_tests
g++ -std=c++17 -O1 -D_GLIBCXX_ASSERTIONS Validation/broker_stress.cpp -o Validation/broker_stress
./Validation/broker_stress 1 2000
```

The final builds also used `-fsanitize=undefined -fno-sanitize=enum -Wall -Wextra -Wno-unused-parameter -Wno-sign-compare`, with no diagnostics. Enum-range instrumentation is disabled because MQL permits the intentional WRONG_VALUE casts. Address/leak sanitizer is not claimed as verified.

- `build_harness.py` recursively consumes all 13 active files, removes include guards/property/input syntax, and adapts dynamic arrays to vectors. It generates `ea_under_test.hpp`; this duplicate generated source is intentionally omitted from the ZIP.
- `mt5_mock.hpp` models the terminal API subset used by the EA.
- `lifecycle_tests.cpp` contains 27 original regression groups, updated for exact identity and history-based confirmation.
- `race_tests.cpp` contains 8 readable focused regression groups for the simulation findings and missing-evidence behavior.
- `broker_stress.cpp` maintains independent server orders/positions, delayed terminal views, history and callback queues. The arguments are first seed and number of trials. Failures print the seed, recent trace and item book.
- `results.txt` records the final results for the supplied active source.

See `../SIMULATION_REV30_04.md` for assumptions, counts, corrections and limits. Passing these checks is not native MQL5 compilation or real MT5 execution. The mock cannot establish API fidelity beyond its modeled subset, real account timing, restart recovery or strategy correctness.
