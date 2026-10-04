# Simulated-terminal lifecycle validation

These files are not included or compiled by the EA. They adapt the current MQL function bodies to a C++ simulated terminal. Broker operations are deterministic test fixtures; no account is accessed.

From the extracted package directory, with Python 3 and a C++17 compiler:

```sh
python3 Validation/build_harness.py
g++ -std=c++17 -D_GLIBCXX_ASSERTIONS Validation/lifecycle_tests.cpp -o Validation/lifecycle_tests
./Validation/lifecycle_tests
```

The builder recursively consumes all 13 active files from `HedgeGrid.mq5`, keeps the function logic, flattens include guards, removes `input`/property directives and adapts dynamic array declarations to vectors. It creates `Validation/ea_under_test.hpp`. `mt5_mock.hpp` implements the tested subset of terminal API behavior. The tests themselves are grouped in `lifecycle_tests.cpp`; `results.txt` records the final run.

27 scenario groups cover command guards, event permutations, partial entries/closes, identity recovery, late history, replacement races (including partial remainder cancellation), async uncertainty, cleanup, ownership, scheduler limits and initialization constraints.

The final run also used `-fsanitize=undefined -fno-sanitize=enum -Wall -Wextra -Wno-unused-parameter -Wno-sign-compare`. Enum-range checking is disabled because MQL explicitly permits the WRONG_VALUE casts used by the source. Address/leak sanitizer could not complete under this runtime's restricted process access; it is not counted as a pass.

Passing these tests does not establish native MQL compilation, terminal API fidelity beyond the modeled subset, broker timing, restart recovery, long-run throughput or strategy correctness. Native MetaEditor and MT5 lifecycle validation remain required.
