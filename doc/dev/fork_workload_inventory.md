# FK-01 — Workload inventory and gate decisions

Status: **open — awaiting owner input on G1/G2** (see questions below). Started 2026-07-16. See `doc/dev/fork_execution_plan.md` (FK-01) for task definition.

## What could be determined from this environment

* The org's GitHub scope visible to this session contains only `DarcStar-Technologies/lean4` (this fork). The session's repository-listing service was unavailable on repeated attempts, so **no automated inventory of other org repositories was possible**; the inventory below must be completed by the owner.
* This fork itself carries no internal Lean projects, lakefiles, or Mathlib references beyond upstream's own.

## Inventory table (to be completed by owner)

| project | repo | uses Mathlib / `lake exe cache`? | build min/week (CI) | editor users | memory-sensitive? |
|---|---|---|---|---|---|
| _(none discoverable from this session)_ | | | | | |

## Gate decisions

* **G1 — Mathlib dependency**: **UNDECIDED.** Until answered, the conservative interpretation applies: production projects stay on official elan toolchains, and Workstream 1 experiments run only against in-repo workloads (stdlib benchmarks), which is what the FK-10 rig does regardless.
* **G2 — dominant cost**: **UNDECIDED.** Until answered, Workstream 1 keeps the default experiment order (march → LTO → PGO → mimalloc) and Workstream 3 keeps the default PR-benchmarking order from the execution plan.

## Questions for the owner

1. Which internal projects/repos use Lean, and do any of them depend on Mathlib (directly or transitively) or on `lake exe cache`? *(Decides whether a self-built tuned toolchain is usable in production at all.)*
2. Where does Lean time/money actually go today: CI build minutes, editor/elaboration latency for engineers, or memory ceilings? *(Reorders the experiment and PR-benchmarking priorities.)*
3. Are there Lean workloads on non-x86-64 hardware (Apple Silicon, ARM servers) or unusual platforms? *(Constrains `-march` and affects the #13113 watchlist item.)*

## Provisional working assumptions (in force until G1/G2 are answered)

1. Treat G1 as "Mathlib dependency present" for anything production-facing (most restrictive).
2. Proceed with FK-10 rig construction and container-indicative baselines (done — see `doc/dev/fork_bench_results.md`).
3. Defer FK-11/12/13 adoption decisions; they need the dedicated benchmark machine anyway.
