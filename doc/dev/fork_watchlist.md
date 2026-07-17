# FK-32 upstream watchlist

Issues/PRs in `leanprover/lean4` we track, each with the action to take when it moves. Reviewed monthly per `fork_policy.md`. Subscribe via GitHub notifications on each item. Baseline state as of 2026-07-17.

## Our carried patches' upstream twins (from `fork_patches.md`)

| item | action when it moves |
|---|---|
| #13987 (Json.parse panic) | our fix awaits submission; if someone else fixes it first, delete our carry |
| #14000 (IO.Process.output deadlock) | same |
| TryThis indent + sharecommon guard (no upstream issue) | same, once submitted |

## PRs we benchmarked or plan to benchmark (FK-31)

| item | state at baseline | action |
|---|---|---|
| #14109 compactor flat hash tables | draft, green, idle since Jun 19; **we confirmed −44.6% incr_header_save** | post our numbers (needs upstream access); when merged: note the win arrives at next release |
| #14086 JSON string fast path | ready, awaiting review; benchmark in progress | record results; post if signal |
| #14185 server thread-per-message fix | ready, awaiting mhuisi | benchmark if a server-latency workload materializes (G2); post results |
| #14327 stuck-TC memoization | draft, mathlib green | benchmark on TC-heavy internal workload once identified |
| #8883 defEq cache fix (closes #10414) | open, ~3.8% Mathlib build win claimed | effect below our container noise floor — benchmark only on the dedicated machine (FK-10 registry) |

## Regressions and crashes that may affect us

| item | action |
|---|---|
| #14329 LNSym 30× memory regression (4.29→4.30) | if any internal workload OOMs after a toolchain bump past 4.29: bisect nightlies with our rig, post findings |
| #6753 server leaks 1–2 GB per reprocess | if editors hit memory ceilings: attach heap profiles to the issue |
| #14315 codegen miscompile segfault (`Option.attach`) | before bumping toolchain: check status; if unfixed, smoke-test our compiled binaries |
| #13113 48-bit pointer packing (5-level paging / ARM MTE) | only if we deploy on such hardware; then treat as blocking and escalate upstream |

## Structural work that forces planning

| item | action |
|---|---|
| #14362 olean prefix trees (ABI break, breaks-mathlib) | when it merges: expect olean-format change; do not bump the pinned toolchain until Mathlib cache catches up (if G1 applies) |
| #13103 separate codegen (ABI break) | same; also revisit FK-15's LTO/PGO numbers after it lands — codegen changes invalidate old measurements |
| #12102 / #13063 universe-normalization & TC-loop (P-high elaborator issues) | no action; re-check quarterly whether upstream landed fixes worth a toolchain bump |
