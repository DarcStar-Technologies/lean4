#!/usr/bin/env bash
# FK-30 upstream-PR benchmark harness (DarcStar fork; see doc/dev/fork_execution_plan.md).
#
# Given an upstream leanprover/lean4 PR number: fetch its head, build a
# throwaway worktree at the PR's merge-base, benchmark it with the FK-10 rig,
# then check out the PR head in the same worktree, rebuild incrementally, and
# benchmark again. Emits a base-vs-head comparison. Using one worktree keeps
# the comparison same-config/same-machine and makes the second build
# incremental (minutes for C++-only PRs).
#
# Usage: script/fork/pr-bench.sh PR_NUMBER [--runs N] [--jobs N] [BENCH...]
#   BENCH is pile/file (default: the FK-10 rig default suite)
# Worktree: <repo>/../fork-pr-<N> (kept for reruns; remove with
#   `git worktree remove ../fork-pr-<N> --force` when done)

set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/../.." && pwd)"
UPSTREAM_URL="https://github.com/leanprover/lean4.git"

PR="${1:?usage: pr-bench.sh PR_NUMBER [--runs N] [--jobs N] [BENCH...]}"
shift
RUNS=5
JOBS="$(nproc)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs) RUNS="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    *) break ;;
  esac
done
BENCHES=("$@")

WT="$(dirname "$ROOT")/fork-pr-$PR"

echo "=== fetching PR #$PR from upstream" >&2
git -C "$ROOT" fetch --force "$UPSTREAM_URL" \
  "pull/$PR/head:refs/fork-bench/pr-$PR" \
  "master:refs/fork-bench/upstream-master" >&2
PR_SHA="$(git -C "$ROOT" rev-parse "refs/fork-bench/pr-$PR^{commit}")"
BASE_SHA="$(git -C "$ROOT" merge-base "$PR_SHA" refs/fork-bench/upstream-master)"
echo "PR head:    $PR_SHA" >&2
echo "merge-base: $BASE_SHA" >&2
echo "diffstat:" >&2
git -C "$ROOT" diff --stat "$BASE_SHA" "$PR_SHA" | tail -5 >&2

if [[ ! -d "$WT" ]]; then
  git -C "$ROOT" worktree add --detach "$WT" "$BASE_SHA" >&2
else
  git -C "$WT" checkout --detach "$BASE_SHA" >&2
fi

build() {
  (cd "$WT" \
    && cmake --preset release >> "$WT/build.log" 2>&1 \
    && { # the proxy blocks the leantar release download; seed it from the main build
         if [[ -x "$ROOT/build/release/bin/leantar" && ! -x "$WT/build/release/bin/leantar" ]]; then
           lt_dir="$(ls -d "$ROOT"/build/release/leantar/leantar-* 2>/dev/null | head -1)"
           if [[ -n "$lt_dir" ]]; then
             mkdir -p "$WT/build/release/leantar/$(basename "$lt_dir")"
             cp "$lt_dir/leantar" "$WT/build/release/leantar/$(basename "$lt_dir")/leantar"
             rm -f "$WT/build/release/leantar.tar.gz"
           fi
         fi
       } \
    && make -j"$JOBS" -C build/release >> "$WT/build.log" 2>&1)
}

echo "=== building merge-base toolchain in $WT (log: $WT/build.log)" >&2
build
echo "=== benchmarking merge-base" >&2
"$SELF_DIR/bench-rig.sh" --root "$WT" --runs "$RUNS" --label "pr$PR-base" "${BENCHES[@]}"

echo "=== checking out PR head and rebuilding incrementally" >&2
git -C "$WT" checkout --detach "$PR_SHA" >&2
build
echo "=== benchmarking PR head" >&2
"$SELF_DIR/bench-rig.sh" --root "$WT" --runs "$RUNS" --label "pr$PR-head" "${BENCHES[@]}"

echo >&2
echo "=== comparison: merge-base -> PR head" >&2
"$SELF_DIR/aggregate_measurements.py" compare \
  "$WT/build/fork-bench/pr$PR-base" "$WT/build/fork-bench/pr$PR-head" || true
echo >&2
echo "note: 'compare' tolerances are the reproducibility tripwire, not a perf verdict;" >&2
echo "on this class of machine treat only large deltas as signal (see fork_bench_results.md)." >&2
