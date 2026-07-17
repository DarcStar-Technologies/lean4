# DarcStar fork policy

Operating rules for `DarcStar-Technologies/lean4`, distilled from the audit (`fork_audit_2026-07.md`, §5–6) and execution plan (FK-41). These are the standing rules; the audit holds the rationale.

## Branch model

* **`master` — pure upstream mirror.** Byte-identical to `leanprover/lean4` master, fast-forward-only, updated by the sync workflow. Never commit to it. A non-fast-forward sync failure means someone broke this rule; fix by force-syncing after rescuing any stray commits to a branch.
* **`darcstar` (recommended default branch) — fork additions.** Documentation (`doc/dev/fork_*.md`), tooling (`script/fork/`), workflows (`.github/workflows/darcstar-*.yml`), and currently-carried patches. Kept current by merging `master` in regularly. Scheduled workflows only run from the default branch, so the sync/tripwire automation lives here, not on `master`.

## Divergence rules

1. **Allowed without review**: build *configuration* (CMake cache files, env vars, CI recipes) and additive fork-only files (docs, scripts, workflows under `darcstar-*` names). Nothing that changes what upstream source builds to.
2. **Allowed with ledger entry**: temporary carries of **our own upstream-submitted fixes**, recorded in `doc/dev/fork_patches.md` with an expiry condition. A carry lives only between upstream submission and the first release tag containing the fix; when the upstream twin merges in any form, the fork copy is **deleted, not reconciled**.
3. **Categorically excluded, regardless of benefit**: kernel changes, olean-format changes, elaborator-semantics changes, and cherry-picks of unmerged third-party PRs. Anything `breaks-mathlib`-labeled upstream. (Audit §5 has the rationale: trust, stage0 entanglement, Mathlib-cache compatibility.)

## Toolchains

* Production projects use official elan-distributed toolchains unless FK-01's gate G1 clears a workload for a self-built toolchain.
* Any distributed self-built toolchain is built at a **pinned upstream release tag** with `CHECK_OLEAN_VERSION=ON`, from a config recipe (no source diff).

## Standing cadence (monthly, ~30 min)

1. Carry ledger (`fork_patches.md`): check each entry's upstream PR; delete carries whose expiry condition has been met.
2. Watchlist (`fork_watchlist.md`): triage movement; execute the per-item action if triggered.
3. Toolchain: decide whether to bump the pinned release tag; check the tripwire workflow's recent runs before bumping.
4. Benchmarks: if new upstream perf PRs of interest appeared, queue `script/fork/pr-bench.sh` runs.

## Upstream conduct

We aim to be a good upstream contributor: fixes go to `leanprover/lean4` first; benchmark confirmations get posted on the PRs they test; issue reports include repros and bisections. The fork is a staging ground, not a destination.
