#!/usr/bin/env bash
# FK-10 benchmark rig (DarcStar fork; see doc/dev/fork_execution_plan.md).
#
# Thin orchestrator over the repo's own bench harness: runs a fixed subset of
# tests/elab_bench and tests/compile_bench through with_stage1_test_env.sh /
# run_bench.sh with TEST_BENCH=1 and TEST_REPEAT, then aggregates the
# .measurements.jsonl output. On machines without perf(1), a shim on PATH
# lets tests/measure.py record wall-clock and task-clock only (hardware
# counters report 0 and are dropped by the aggregator).
#
# Usage: script/fork/bench-rig.sh [--runs N] [--label NAME] [BENCH...]
#   BENCH is pile/file, e.g. elab_bench/big_do.lean
# Results: markdown summary appended to doc/dev/fork_bench_results.md is left
# to the operator; raw output lands in build/fork-bench/<label>/.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNS=5
LABEL="$(date +%Y%m%d-%H%M%S)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs) RUNS="$2"; shift 2 ;;
    --label) LABEL="$2"; shift 2 ;;
    *) break ;;
  esac
done

BENCHES=("$@")
if [[ ${#BENCHES[@]} -eq 0 ]]; then
  BENCHES=(
    # elaborator throughput
    elab_bench/big_do.lean
    elab_bench/big_match.lean
    elab_bench/big_omega.lean
    # kernel/defeq reduction
    elab_bench/cbv_decide.lean
    # compiled-code + allocator behavior
    compile_bench/binarytrees.st.lean
    compile_bench/const_fold.lean
  )
fi

ENV_WRAPPER="$ROOT/tests/with_stage1_test_env.sh"
if [[ ! -x "$ENV_WRAPPER" ]]; then
  echo "error: $ENV_WRAPPER not found or not executable." >&2
  echo "Build the toolchain first: make -j\$(nproc) -C build/release" >&2
  exit 1
fi

# tests/measure.py requires python >= 3.12; front a python3 shim if the default is older
if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)' 2>/dev/null; then
  for cand in python3.13 python3.12; do
    if command -v "$cand" >/dev/null; then
      PYSHIM="$(mktemp -d)"
      ln -sf "$(command -v "$cand")" "$PYSHIM/python3"
      export PATH="$PYSHIM:$PATH"
      echo "note: default python3 < 3.12; using $cand for the harness" >&2
      break
    fi
  done
fi

MODE=perf
if ! perf stat -e instructions -o /dev/null true 2>/dev/null; then
  MODE=wallclock
  export PATH="$ROOT/script/fork/perf-shim:$PATH"
  echo "note: perf unavailable; wall-clock/task-clock only (instructions/cycles dropped)" >&2
fi

OUT_DIR="$ROOT/build/fork-bench/$LABEL"
mkdir -p "$OUT_DIR"

{
  echo "label: $LABEL"
  echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "commit: $(git -C "$ROOT" rev-parse --short HEAD)$(git -C "$ROOT" diff --quiet || echo -dirty)"
  echo "mode: $MODE"
  echo "runs: $RUNS (drop highest 1)"
  echo "nproc: $(nproc)"
  echo "cpu: $(sed -n 's/^model name.*: //p' /proc/cpuinfo | head -1)"
  echo "governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo n/a)"
  echo "mem_gb: $(free -g | awk '/^Mem:/{print $2}')"
  echo "compiler: $(sed -n 's/^CMAKE_CXX_COMPILER:[^=]*=//p' "$ROOT/build/release/CMakeCache.txt" 2>/dev/null | head -1)"
} > "$OUT_DIR/meta.txt"
cat "$OUT_DIR/meta.txt" >&2

for bench in "${BENCHES[@]}"; do
  pile="${bench%%/*}"
  file="${bench#*/}"
  echo "=== $bench (x$((RUNS + 1)))" >&2
  rm -f "$ROOT/tests/$pile/$file.measurements.jsonl"
  # One extra run with the highest value per metric dropped: absorbs cold-cache warmup.
  TEST_BENCH=1 TEST_REPEAT=$((RUNS + 1)) TEST_REPEAT_DROP_HIGHEST=1 \
    "$ENV_WRAPPER" "$ROOT/tests/$pile/run_bench.sh" "$file" >&2
  mkdir -p "$OUT_DIR/$pile"
  cp "$ROOT/tests/$pile/$file.measurements.jsonl" "$OUT_DIR/$pile/"
done

echo >&2
echo "=== summary ($OUT_DIR)" >&2
"$ROOT/script/fork/aggregate_measurements.py" summarize \
  $(find "$OUT_DIR" -name '*.measurements.jsonl' | sort)

echo >&2
echo "Reproducibility check against a previous run:" >&2
echo "  script/fork/aggregate_measurements.py compare build/fork-bench/<old> $OUT_DIR" >&2
