# Fork execution plan — DarcStar-Technologies/lean4

Companion to `doc/dev/fork_audit_2026-07.md` (2026-07-16). That document contains the audit, adversarial verdicts, and rationale; this one is the work breakdown. Task IDs are stable references for tracking (`FK-xx`).

## Ground rules (from the audit, non-negotiable)

1. No permanent source divergence from upstream. Allowed divergence classes: build **configuration**, and **temporary carries** of our own upstream-submitted fixes (expiry = first upstream release tag containing the fix).
2. Never diverge on: kernel, olean format, elaborator semantics, `src/include/lean/lean.h` object layout.
3. Every performance claim gets measured on our workloads before adoption; the bar is **≥5% end-to-end** on a representative internal workload.
4. Production projects stay on official elan-distributed toolchains unless a workload passes gate G1 below.

## Workstream 0 — Decision gates

### FK-01: Workload inventory and gate decisions
- **Scope**: Enumerate internal Lean projects. For each: Mathlib dependency (direct or transitive, incl. `lake exe cache` usage), build minutes/week in CI, editor-latency pain reports, memory ceilings.
- **Output**: A one-page memo answering **G1** (any Mathlib-dependent project ⇒ that project is excluded from self-built toolchains) and **G2** (dominant cost: compile throughput / elaboration latency / server memory — this reorders Workstream 1's experiments and Workstream 3's PR benchmarking priorities).
- **Acceptance**: memo committed to internal docs; G1/G2 answered explicitly.
- **Effort**: 0.5–1 day. **Dependencies**: none. **Do this first — everything else keys off it.**

## Workstream 1 — Measured toolchain packaging (config-only)

All experiments run at a **pinned upstream release tag** (use the latest stable, not v4.34.0-dev, so results map to a deployable toolchain). One variable at a time. No source edits.

### FK-10: Benchmark baseline and measurement protocol
- **Scope**: Stand up a repeatable measurement rig on one dedicated (non-shared) Linux x86-64 machine:
  - `tests/bench/build` for per-file stdlib build timing; a fixed subset of `tests/elab_bench` and `tests/compile_bench` via ctest; plus one representative internal project (from FK-01) built with `lake build` under `perf stat`.
  - Protocol: ≥5 runs per configuration, report median + spread; instructions-retired as primary metric (low variance), wall-clock as secondary; fixed CPU governor; record in a results table checked into the fork (e.g. `doc/dev/fork_bench_results.md`).
- **Acceptance**: two consecutive baseline runs of the full rig agree within 1% on instructions and 3% on wall-clock.
- **Effort**: 1–2 days. **Dependencies**: FK-01.

### FK-11: `-march=x86-64-v3` experiment
- **Scope**: Configure with `-DLEAN_EXTRA_CXX_FLAGS=-march=x86-64-v3` (and the equivalent for stage flags via the `STAGE0_`/`STAGE1_` cache-var forwarding), full stage build, run FK-10 rig.
- **Acceptance**: results row recorded; adopt/drop decision against the 5% bar (expected: low single digits — likely a *component* of a winning config rather than a win alone).
- **Effort**: 0.5 day machine-attended. **Dependencies**: FK-10.

### FK-12: ThinLTO experiment
- **Scope**: Enable ThinLTO for the C++ runtime and `leanshared` link (`-flto=thin` via extra flags; verify `lld`/toolchain support in our build image). Watch specifically for: link-time blowup, FFI symbol-visibility breakage (run the full ctest suite, not just benchmarks), debuggability loss.
- **Acceptance**: full test suite green under the LTO build (`make -C build/release test`), results row recorded.
- **Effort**: 1–2 days (symbol issues are the risk). **Dependencies**: FK-10.

### FK-13: PGO experiment
- **Scope**: Two-pass build: instrument (`-fprofile-generate`), run the profile workload (stdlib build + the FK-01 internal project), rebuild with `-fprofile-use`. Automate as a script so it's reproducible at future tags.
- **Acceptance**: full test suite green; results row recorded. This is the experiment with the highest expected payoff (5–15% typical for compiler-shaped workloads) — if it misses the 5% bar, Workstream 1 likely ends at FK-15 with "no self-built toolchain".
- **Effort**: 2–3 days. **Dependencies**: FK-10 (FK-12 result informs whether to stack LTO+PGO).

### FK-14: mimalloc 3 tuning experiment
- **Scope**: Pure env-var sweep, no build changes: `MIMALLOC_PURGE_DELAY`, `MIMALLOC_ARENA_EAGER_COMMIT`, `MIMALLOC_ALLOW_LARGE_OS_PAGES`/huge-page options, over the FK-10 rig. Applies to *official* toolchains too — this is the one experiment whose winners deploy with zero build infrastructure (set env vars in CI/editor).
- **Acceptance**: results table; any ≥2% reproducible win written up and posted upstream as a #7786 follow-up (upstream will take a `mi_option_set` one-liner; then we get it permanently for free).
- **Effort**: 1 day. **Dependencies**: FK-10. **Can run in parallel with FK-11–13.**

### FK-15: Adoption decision and build recipe
- **Scope**: If any combination clears the 5% bar on a G1-eligible (Mathlib-free) workload: produce `cmake/darcstar-toolchain.cmake` cache file + a CI job that builds and archives the tuned toolchain at each pinned tag, with `CHECK_OLEAN_VERSION=ON` (mandatory for any distributed self-built toolchain — see audit) — still zero source diff. If nothing clears the bar: record that and close Workstream 1; revisit only at major upstream changes (e.g. when #13103 separate codegen lands).
- **Acceptance**: either a working CI-built tuned toolchain consumed by at least one internal project, or a documented "not worth it" result.
- **Effort**: 1–2 days. **Dependencies**: FK-11–14.

## Workstream 2 — Upstream contribution track

Order below is the recommended order (easiest → hardest). For each: develop on a fork branch off upstream master, PR to `leanprover/lean4` following `doc/dev/commit_convention.md`, engage review. **Temporary carry** onto our toolchain only if the bug demonstrably blocks an internal project today.

### FK-20: Fix upstream #13987 — `Json.parse` panic on huge exponents
- **Scope**: Reproduce (`Lean.Json.parse "3E9999999993"` panics via `Nat.pow` exponent guard). Fix in the JSON number path: bound the exponent before computing the power (return a parse error or saturate per JSON-spec discussion in the issue — follow whichever the issue thread converged on). Add `tests/lean/run` test with the repro. Note this is also a robustness issue for anything parsing untrusted JSON (the language server parses client input as JSON).
- **Acceptance**: upstream PR opened, CI green, repro test included.
- **Effort**: 0.5–1 day.

### FK-21: Fix upstream #14000 — `IO.Process.output` pipe deadlock
- **Scope**: Reproduce with a >196KB stdin child. Implement the fix sketched in the issue: write stdin from a dedicated task while concurrently draining stdout/stderr, so neither pipe can fill and deadlock. Add a test with a large-input child process (mind Windows/macOS pipe-buffer differences; keep the test size comfortably above Linux's 64KB default).
- **Acceptance**: upstream PR opened, CI green on all three OSes, deterministic repro test included.
- **Effort**: 1–2 days.

### FK-22: Fix upstream #14148 — `lean_alloc_ctor` crash for 1025–4095-byte constructors under mimalloc
- **Scope**: Reproduce with the test code from the issue (constructor in the 1025–4095-byte range under the mimalloc build). Implement the preferred fix from the issue's enumerated options (routing over-`MI_SMALL_SIZE_MAX` sizes off the small-alloc fast path in the ctor-alloc path). This touches `src/runtime`/`lean.h` territory, so expect an `update-stage0` cycle — follow `doc/dev/` bootstrap docs, never hand-edit `stage0/`.
- **Acceptance**: upstream PR opened with repro test; local full test suite green.
- **Effort**: 1–3 days (stage0 cycle is the variable). **Note**: fresh mimalloc-3-related crash — check the issue for an upstream fix already in flight before starting.

### FK-23: Drive-by upstream PRs (batch)
- **Scope**: Two small quality PRs to build reviewer relationship: `TryThis` suggestion misplacement (`src/Lean/Meta/TryThis.lean:238` FIXME, line-start `by` case) and the `sharecommon_quick_fn::visit` stack guard (`src/runtime/sharecommon.cpp:409` — implementation plan is in the comment).
- **Acceptance**: PRs opened; no expectation of fast merge.
- **Effort**: 1 day combined. **Priority**: lowest in workstream; fill-in work.

### FK-24: Carry ledger and policy file
- **Scope**: Add `doc/dev/fork_patches.md` to the fork: table of {patch, upstream PR, submitted date, expiry condition, status}. Policy text: carry only own-submitted fixes; delete (never reconcile) when the upstream twin merges; kernel/olean/elaborator-semantics patches categorically refused.
- **Acceptance**: file exists before the first carry happens; referenced from the fork's README or CONTRIBUTING notes.
- **Effort**: 0.5 day. **Dependencies**: none (do alongside FK-20).

## Workstream 3 — Upstream PR test-and-boost program

### FK-30: PR toolchain harness
- **Scope**: Script: given an upstream PR ref, fetch, build a throwaway stage-1 toolchain, run the FK-10 rig against it, emit a comparison table vs the merge-base build. (Where upstream speedcenter numbers exist, ours add the *internal workload* dimension they lack.)
- **Acceptance**: harness runs end-to-end on one PR.
- **Effort**: 1–2 days. **Dependencies**: FK-10.

### FK-31: Benchmark-and-comment pass over idle upstream perf PRs
- **Scope**: Run the harness over, in priority order by G2: #14185 (server threading — if editor latency dominates), #14109 (compactor/olean save — if CI throughput dominates), #14327 (stuck-TC memoization), #14086 (JSON fast path), #14032 (import pre-read; benchmark cold-cache explicitly), #8883 (isDefEq cache fix for #10414 — biggest expected elaboration win). Post results as PR comments — independent confirmation on real workloads is what idle-but-green PRs need to get reviewer attention.
- **Acceptance**: results posted on ≥3 PRs; internal notes on which merged-future-release matters to us.
- **Effort**: 0.5–1 day per PR, machine-attended. **Dependencies**: FK-30.

### FK-32: Watchlist
- **Scope**: Subscribe (GitHub notifications) to: #14329 (memory regression — if it reproduces on our workloads, bisect nightlies and post findings), #6753 (attach heap profiles if we hit it), #12102, #13063, #9077, #14315, #13113 (only if deploying on 5-level-paging/MTE hardware), #14362 + #13103 (ABI-breaking pipeline work — plan toolchain-bump timing around their landings). Fold a monthly re-triage of this list into FK-41's cadence.
- **Acceptance**: watchlist documented with per-item "what we do if it moves".
- **Effort**: 0.5 day setup.

## Workstream 4 — Governance and automation

### FK-40: Mirror sync + regression tripwire CI
- **Scope**: Scheduled job (daily): fast-forward fork `master` from upstream master (fail loudly on non-FF — that means we accidentally diverged). Weekly (or per upstream nightly tag): build the toolchain and run the FK-10 elab/build subset on the representative internal workload; alert on >5% regression vs rolling baseline. This is the tripwire that catches #14329-class regressions *before* an internal toolchain bump.
- **Acceptance**: one week of green scheduled runs; a synthetic regression (injected slow flag) demonstrably alerts.
- **Effort**: 1–2 days. **Dependencies**: FK-10.

### FK-41: Fork policy doc + standing cadence
- **Scope**: Commit the policy (ground rules above + FK-24 carry policy) as `doc/dev/fork_policy.md`. Standing cadence: monthly 30-minute review — carry-ledger expiries, watchlist triage, upstream-release toolchain-bump decision.
- **Acceptance**: doc committed; first monthly review scheduled.
- **Effort**: 0.5 day.

## Sequencing

```
Week 1:  FK-01 → FK-10 (rig) ─┬─ FK-24 (ledger)
Week 2:  FK-11, FK-14 (parallel) ── FK-20 (Json fix)
Week 3:  FK-12 → FK-13 (PGO) ────── FK-21 (pipe deadlock)
Week 4:  FK-15 (adopt/drop) ─────── FK-22 (alloc_ctor) → FK-30 (harness)
Week 5:  FK-31 (PR benchmarking) ── FK-40 (sync + tripwire)
Week 6:  FK-32, FK-41 (watchlist, policy, cadence) ── FK-23 (drive-bys, fill-in)
```

Total: ~15–20 focused person-days over ~6 calendar weeks, parallelizable to ~4 weeks with two people (one on Workstream 1/3 benchmarking, one on Workstream 2 fixes).

## Kill criteria / exits

- FK-13 (PGO) misses the 5% bar ⇒ close Workstream 1 as "official toolchains + mimalloc env vars only"; the standing cost drops to FK-40/41 automation (~zero marginal effort).
- An upstream fix lands for any FK-2x target before we start ⇒ delete the task, add the issue to FK-32 watchlist for the release that ships it.
- If FK-01 finds *all* workloads Mathlib-dependent ⇒ Workstream 1 reduces to FK-14 (env vars only); Workstreams 2–4 unaffected.

## What we deliberately are not doing

Cherry-picking unmerged upstream PRs (except the FK-24 policy's own-fix carries); any kernel/olean/elaborator-semantics patch; removing the `m_cs_sz` allocator store; `ReducePowMaxExp` configurability on the fork; `isNewAnswer` normalization; fork-private simp caching; adopting #13898 (uv_spawn) or any `breaks-mathlib` draft. Rationale for each is in the audit's §5–6.
