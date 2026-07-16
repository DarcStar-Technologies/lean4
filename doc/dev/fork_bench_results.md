# FK-10 benchmark results ledger

Protocol and results for the fork benchmark rig (`script/fork/bench-rig.sh`). See `doc/dev/fork_execution_plan.md` (FK-10) for context.

## Protocol

* Rig: `script/fork/bench-rig.sh [--runs N] [--label NAME] [pile/file...]` — drives the repo's own harness (`tests/with_stage1_test_env.sh` + `run_bench.sh`) with `TEST_BENCH=1` and `TEST_REPEAT`, then aggregates `.measurements.jsonl` via `script/fork/aggregate_measurements.py`.
* Default suite: `elab_bench/{big_do,big_match,big_omega,cbv_decide}.lean` (elaborator + kernel-reduction throughput), `compile_bench/{binarytrees.st,const_fold}.lean` (compiled-code + allocator behavior).
* Runs: N+1 iterations, highest value per metric dropped (absorbs cold-cache warmup); default N=5. Report median; spread = (max−min)/median.
* Metrics: with `perf`: instructions (primary), task-clock, wall-clock, cycles, maxrss. Without `perf` (rig auto-detects and uses `script/fork/perf-shim`): wall-clock, task-clock, maxrss only.
* Reproducibility acceptance (per FK-10): two consecutive baseline runs on the same machine must agree within 1% on instructions and 3% on wall-clock/task-clock: `script/fork/aggregate_measurements.py compare build/fork-bench/<run1> build/fork-bench/<run2>`.
* Comparisons are only valid within the same machine + mode + toolchain-config triple. Raw data: `build/fork-bench/<label>/` (not committed); summaries are appended below.

## Machine registry

| id | cpu | cores | mem | perf? | governor | notes |
|---|---|---|---|---|---|---|
| ccr-container-1 | (see run meta) | 4 | 15 GB | no (shim) | n/a (virtualized) | Claude Code remote session container; gcc build; wall-clock indicative only — NOT the FK-10 dedicated machine |

> The FK-10 acceptance environment is a dedicated non-shared Linux x86-64 machine with working `perf` counters and a clang toolchain matching official releases. The container rows below establish the rig works end-to-end and give indicative baselines only.

## Results

<!-- Append per-run summaries here: run meta block followed by the summarize table. -->
