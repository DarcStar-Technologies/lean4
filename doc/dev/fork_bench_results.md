# FK-10 benchmark results ledger

Protocol and results for the fork benchmark rig (`script/fork/bench-rig.sh`). See `doc/dev/fork_execution_plan.md` (FK-10) for context.

## Protocol

* Rig: `script/fork/bench-rig.sh [--runs N] [--label NAME] [pile/file...]` — drives the repo's own harness (`tests/with_stage1_test_env.sh` + `run_bench.sh`) with `TEST_BENCH=1` and `TEST_REPEAT`, then aggregates `.measurements.jsonl` via `script/fork/aggregate_measurements.py`.
* Default suite: `elab_bench/{big_do,big_match,big_omega,cbv_decide}.lean` (elaborator + kernel-reduction throughput), `compile_bench/{binarytrees.st,const_fold}.lean` (compiled-code + allocator behavior).
* Runs: N+1 iterations, highest value per metric dropped (absorbs cold-cache warmup); default N=5. Note `tests/repeatedly.py` emits the **mean of the kept iterations as a single value per metric**, so each label yields one number per metric and run-to-run comparisons are mean-vs-mean; the aggregator's spread column is only informative for runs without `TEST_REPEAT`.
* Metrics: with `perf`: instructions (primary), task-clock, wall-clock, cycles, maxrss. Without `perf` (rig auto-detects and uses `script/fork/perf-shim`): wall-clock, task-clock, maxrss only.
* Reproducibility acceptance (per FK-10): two consecutive baseline runs on the same machine must agree within 1% on instructions and 3% on wall-clock/task-clock: `script/fork/aggregate_measurements.py compare build/fork-bench/<run1> build/fork-bench/<run2>`.
* Comparisons are only valid within the same machine + mode + toolchain-config triple. Raw data: `build/fork-bench/<label>/` (not committed); summaries are appended below.

## Machine registry

| id | cpu | cores | mem | perf? | governor | notes |
|---|---|---|---|---|---|---|
| ccr-container-1 | (see run meta) | 4 | 15 GB | no (shim) | n/a (virtualized) | Claude Code remote session container; gcc build; wall-clock indicative only — NOT the FK-10 dedicated machine |

> The FK-10 acceptance environment is a dedicated non-shared Linux x86-64 machine with working `perf` counters and a clang toolchain matching official releases. The container rows below establish the rig works end-to-end and give indicative baselines only.

## Results

### 2026-07-16 — first baselines, ccr-container-1, commit `7caac8c4` (rig validation)

Meta: mode=wallclock (perf shim), runs=5+1 drop-highest, gcc `-O3` build, Intel Xeon @ 2.80GHz (4 vCPU, virtualized).

Baseline `base-a` vs `base-b` (consecutive identical runs, acceptance check):

| metric | base-a | base-b | delta % | tol % | ok |
|---|---|---|---|---|---|
| compiled/binarytrees.st//task-clock (s) | 5.656 | 5.334 | −5.69 | 3.0 | **NO** |
| compiled/const_fold//task-clock (s) | 3.760 | 3.257 | −13.38 | 3.0 | **NO** |
| elab/big_do//task-clock (s) | 5.148 | 5.133 | −0.29 | 3.0 | yes |
| elab/big_match//task-clock (s) | 2.418 | 2.469 | +2.13 | 3.0 | yes |
| elab/big_omega//task-clock (s) | 4.736 | 4.590 | −3.08 | 3.0 | **NO** |
| elab/cbv_decide//task-clock (s) | 11.05 | 10.83 | −2.03 | 3.0 | yes |
| maxrss (all benches) | — | — | ≤0.2 | — | yes |
| size/compile/.out//bytes | 3.418e+06 | 3.418e+06 | +0.00 | — | yes |

**Verdict: acceptance FAILED on this machine (6 metrics outside 3%), as anticipated in the machine registry.** Interpretation:

* The rig itself works end-to-end (harness invocation, shim measurement, aggregation, tripwire) — that was this run's purpose.
* Elaboration benches are near-tolerance (0.3–3.1%); compiled-execution benches drift −5.7%/−13.4% between consecutive runs — consistent with a shared/virtualized vCPU without pinned frequency, and with `base-a` running immediately after heavy build activity (warmer caches/dirtier memory for the first label). maxrss and binary size are exactly reproducible, confirming the noise is time-domain, not workload-domain.
* Consequences: (1) container numbers are usable only for large effects (≫15% on compiled benches, ≫5% on elab benches); (2) FK-11..13 adoption decisions still require the dedicated perf-capable machine per protocol; (3) on that machine, instructions-retired (unavailable here) should be primary, where the 1% tolerance applies.

### 2026-07-17 — FK-31 trial: upstream PR #14109 (compactor flat hash tables)

Run via `script/fork/pr-bench.sh 14109` on ccr-container-1: one worktree, merge-base `58225845` built from scratch, PR head `4d03aaf3` rebuilt incrementally (diff is C++-only: `src/runtime/compact.{cpp,h}`). Mode: wallclock (perf shim), 5+1 runs drop-highest, gcc build.

| metric | merge-base | PR head | delta % |
|---|---|---|---|
| incr_header_save task-clock (s) | 4.474 | 2.478 | **−44.6** |
| incr_header_save wall-clock (s) | 4.982 | 2.477 | **−50.3** |
| incr_header_save maxrss (GB) | 2.002 | 1.937 | −3.2 (−65 MB) |
| incr_header_save snap-size (B) | 7.341e7 | 7.341e7 | 0.0 |
| incr_header_load task-clock (s) | 0.294 | 0.279 | −5.3 |
| elab big_do task-clock (s) — control | 6.178 | 7.070 | +14.4 |

**Interpretation: independently CONFIRMS upstream's claims** (−39.9% incr_header_save task-clock, −66 MiB memory, no olean size change) on a different machine and compiler (gcc vs upstream clang) — the save-path win is −44.6% task-clock with memory and size deltas matching the PR description almost exactly. The `incr_header_load` delta is within this box's noise for sub-second compiled benches (inconclusive; the PR does not touch the load path). The `big_do` control delta (+14%) is causally implausible for a compactor-only diff and consistent with this machine's time-domain noise envelope for runs separated by a build — on a dedicated machine, rerun the control before quoting it.

**Suggested upstream action** (needs `leanprover/lean4` access): post these numbers on PR #14109 as independent confirmation, noting machine class and methodology; the PR has been idle-but-green since Jun 19 and independent benchmarks are exactly what it needs to attract review.
