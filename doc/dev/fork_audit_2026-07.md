# Fork audit and improvement plan — DarcStar-Technologies/lean4 (July 2026)

Audit date: 2026-07-16. Fork HEAD: `94b4a6e` (v4.34.0-dev), byte-identical to `leanprover/lean4` master at time of audit.

## 1. Scope and method

This document audits our fork against upstream `leanprover/lean4` and answers: which outstanding upstream issues/PRs are candidates for performance, accuracy, and stability improvements; which of those (plus candidates found by an independent review of the codebase itself) are worth carrying on the fork; and whether carrying fork divergence is worth its maintenance cost at all.

Method: four parallel research passes (upstream open performance issues; upstream open stability/correctness issues; outstanding upstream PRs; independent local codebase review with `file:line` evidence), followed by verification of local claims against source, followed by an adversarial review pass that attacked every candidate on benefit credibility, fork-maintenance cost, obsolescence risk, and cheaper alternatives. All upstream issue/PR states are as of 2026-07-16.

## 2. Fork state (finding: we are a pure mirror)

* `master` is exactly upstream master (`94b4a6e`); `git fetch` of upstream resolves to the same SHA.
* The fork has **zero custom commits, zero issues, zero PRs ever opened, and a single branch**.
* Consequently there is no existing divergence to defend or reconcile; every decision below is a green-field choice about whether to *create* divergence.

## 3. Upstream landscape

### 3.1 Where upstream is investing (last ~4 weeks of merges)

* **Elaborator performance**: WHNF caching at sub-default transparency (#14323), `backward.isDefEq.respectTransparency.types` default-on (#13895), incremental `set_option` (#14397), **mimalloc 3 upgrade** (#7786, merged Jul 15).
* **Import/build pipeline** (Kha): olean constant prefix trees (#14362, draft, import wall-clock −14.4%), separate codegen (#13103, draft, breaks-mathlib), lazy IR loading (#14145).
* **`grind`/`cutsat`/`SymM`** correctness (near-daily churn — highest-conflict area for any fork patch).
* **`vcgen`/`mvcgen`** verification tooling; core-hygiene linter infrastructure.

### 3.2 Top open performance issues

| Issue | Summary | Signal |
|---|---|---|
| [#12102](https://github.com/leanprover/lean4/issues/12102) | Universe normalization too late → ~600× heartbeat blowup in defeq | P-high, 15 👍, no assignee |
| [#10414](https://github.com/leanprover/lean4/issues/10414) | Exponential unification slowness (transient isDefEq cache reset too often) | **Fix in flight: PR #8883** (~3.8% Mathlib build win) |
| [#13063](https://github.com/leanprover/lean4/issues/13063) | Typeclass-inference loop at different depths (hangs) | P-high, from Mathlib Riemannian geometry |
| [#14329](https://github.com/leanprover/lean4/issues/14329) | LNSym tactic elaboration: 30× memory regression after v4.29 (40+ GB) | fresh (Jul 8), untriaged |
| [#9077](https://github.com/leanprover/lean4/issues/9077) | Instance synthesis sees through type synonyms | P-high, 15 👍 |
| [#5610](https://github.com/leanprover/lean4/issues/5610) | `instantiateMVars` scales non-linearly with proof size | P-medium; related to #14329 workload |
| [#12983](https://github.com/leanprover/lean4/issues/12983) | Exponential isDefEq on nested `List.map` (uncached whnfCore) | P-medium, touched Jul 16 |
| [#6753](https://github.com/leanprover/lean4/issues/6753) | Server leaks 1–2 GB per reprocess of a large definition | P-medium, unresolved |

Longer-standing upvoted items: #2867 (DiscrTree vs `OfNat` literals), #2666 (`@[flat]` structures RFC), #8279 (`class abbrev` reimplementation RFC), #2325 (automatic instance priorities). The dominant cluster is **unification/defeq/typeclass synthesis**, all driven by Mathlib-scale workloads, and the only one with confirmed active upstream work is #10414.

### 3.3 Top open stability/correctness issues

| Issue | Summary | Class |
|---|---|---|
| [#7463](https://github.com/leanprover/lean4/issues/7463) | `@[csimp]` smuggles axioms past `native_decide` tracking | soundness (assigned upstream) |
| [#12746](https://github.com/leanprover/lean4/issues/12746) | Kernel truncates `proj_idx` `size_t`→`unsigned` | kernel correctness |
| [#14315](https://github.com/leanprover/lean4/issues/14315) | New codegen miscompile → segfault (`Option.attach`) | miscompile, fresh |
| [#14148](https://github.com/leanprover/lean4/issues/14148) | `lean_alloc_ctor` segfault for 1025–4095-byte constructors under mimalloc | crash, deterministic repro |
| [#14000](https://github.com/leanprover/lean4/issues/14000) | `IO.Process.output` pipe deadlock on large stdin | hang, deterministic |
| [#13113](https://github.com/leanprover/lean4/issues/13113) | 48-bit pointer packing breaks on 5-level paging / ARM MTE | platform crash |
| [#8930](https://github.com/leanprover/lean4/issues/8930) | Constructor-tag size limit fails large generated inductives | P-high, assigned |
| [#10613](https://github.com/leanprover/lean4/issues/10613) | `MapDeclarationExtension.insert` panic (module system + grind) | P-high panic |
| [#11795](https://github.com/leanprover/lean4/issues/11795) | RC insertion destroys tail recursion → stack overflow | codegen |
| [#13987](https://github.com/leanprover/lean4/issues/13987) | `Json.parse` panics on huge exponents | trivial-fix panic |

### 3.4 Outstanding upstream PRs relevant to perf/stability

Green-CI but idle (adoption temptations): #14109 (compactor flat hash tables, −40% task-clock on olean save), #14185 (server: stop spawning a thread per worker output message, up to −58% on server benchmarks), #14327 (memoize stuck TC queries, −0.53% Mathlib instructions, some modules −25–34%), #14086 (JSON string fast path), #14032 (parallel import pre-read). Correctness fixes awaiting review: #14204 (detect olean flush failures — prevents silently truncated oleans on disk-full), #14423 (thread-safe `strerror`), #14391 (`replay` on kernel env), #14033 (qsort worst-case n·log n). Large ABI-breaking upstream-driven work to track only: #14362, #13103.

## 4. Independent local review (verified against source)

Candidates found from the codebase's own evidence, all claims spot-checked:

* **No LTO/PGO/`-march` anywhere**: release C++ flags are plain `-O3` (`src/CMakeLists.txt:284`); the only `-flto` in the tree is Emscripten-specific. `STAGE0_`/`STAGE1_` cache-var forwarding exists, so flags can be injected per-stage without patching.
* **mimalloc 3 runs on stock defaults**: zero `mi_option_set` calls in `src/`; tuning is unexplored (upgrade merged one day before HEAD).
* **`CHECK_OLEAN_VERSION` is OFF by default** (`src/CMakeLists.txt:115`).
* Per-small-allocation `m_cs_sz` store kept only for `leangz` compatibility (`src/include/lean/lean.h:411`, explicit `HACK` comment).
* `sharecommon_quick_fn::visit` has no stack-overflow guard; the TODO includes its own implementation plan (`src/runtime/sharecommon.cpp:409`).
* Kernel `ReducePowMaxExp` hard-coded at 2^24 with `TODO: make it configurable` (`src/kernel/type_checker.cpp:588`).
* Speculative-but-real elaborator debt: isDefEq cache representation (`src/Lean/Meta/Basic.lean:405`), simp `SimpTheorem`/`mkCongrSimp?` caching TODOs (`Meta/Tactic/Simp/Rewrite.lean:451`, `Types.lean:809`), `SynthInstance.isNewAnswer` imprecise dedup (`Meta/SynthInstance.lean:449`), `HaveTelescope` quadratic step (`Meta/HaveTelescope.lean:233`), LCNF `ResetReuse` documented O(n²) (`Compiler/LCNF/ResetReuse.lean:199`), server request blocking on lazy info trees (`Server/Snapshots.lean:45`).
* Validation infra a fork can use as-is: `tests/elab_bench`, `tests/compile_bench`, `tests/bench` (temci speedcenter + `tests/bench/build` per-file stdlib timing), `doc/dev/perf.md` profiling workflow.

## 5. Adversarial review — verdicts

Every candidate was attacked on: benefit credibility, rebase cost against near-daily upstream churn, stage0-bootstrap entanglement, olean-ABI/Mathlib-cache impact, obsolescence by in-flight upstream work, and cheaper alternatives. Structural constraints that decided most verdicts:

1. **stage0 bootstrapping**: changes to `lean.h`, object layout, or compiler-visible behavior require `update-stage0` discipline and make cherry-picks non-commutative with upstream history.
2. **The Mathlib-cache constraint**: Lake traces key on the toolchain. A forked toolchain gets zero `lake exe cache` hits → multi-hour full Mathlib rebuilds on every bump. If any internal project depends on Mathlib, this one cost exceeds the sum of every performance benefit surveyed.
3. **Kernel trust**: a company shipping proofs checked by a privately patched kernel has damaged its assurance story even when the patch is correct. Kernel/olean-format/elaborator-semantics divergence is categorically excluded.

| Candidate | Verdict | Reason (compressed) |
|---|---|---|
| LTO/PGO/`-march=v3` toolchain build | **ADOPT (config-only)** | Only candidate with plausibly material win (5–15% typical for PGO); zero source diff; must be measured first; `-march` limits distributability |
| mimalloc tuning | **ADOPT (env vars)** | `MIMALLOC_*` experiments need no fork; upstream will take a winning `mi_option_set` one-liner |
| `CHECK_OLEAN_VERSION=ON` | Conditional | Only meaningful if we distribute self-built toolchains |
| Remove `m_cs_sz` store (lean.h) | **KILL** | Breaks `leangz` (Mathlib cache/Reservoir tooling); stage0-entangled ABI-adjacent header; benefit unmeasurable |
| Kernel `ReducePowMaxExp` config | **KILL on fork** | Kernel divergence; portability trap; no evidence the 2^24 cap is hit |
| `isNewAnswer` normalization | **KILL** | Changes instance-selection semantics globally; needs Mathlib-scale CI only upstream has |
| simp caching TODOs | Upstream-first | Correctness-sensitive caching; the validation apparatus (speedcenter + Mathlib CI) lives upstream |
| sharecommon stack guard | Upstream-first (low) | No reported crash; fine drive-by upstream PR |
| TryThis FIXME | Upstream | Cosmetic; no reason to fork-carry |
| Cherry-pick #14109/#14185/#14327/#14086/#14032 | **TRACK + help land** | Unmerged PR = you own unreviewed bugs + guaranteed conflict at merge; olean/threading/TC-behavior risk zones; all will arrive via `elan update` |
| Cherry-pick #14204 (olean flush) | TRACK; only defensible tiny pick if we ever see truncated oleans | Near-zero conflict surface, real correctness fix |
| Cherry-pick #13898 (uv_spawn) | **KILL** | Known behavioral break in a draft |
| Fix #13987 / #14000 / #14148 | **Upstream-first**; temporary carry only if the bug blocks us today | Deterministic, scoped, enumerated fix options — ideal first contributions |
| Fix #12746 (kernel proj_idx) | Upstream only | Kernel; never fork-carry |
| #6753 / #14329 investigations | Contribute profiles/bisection upstream | No fix exists to carry |
| #12102 / #13063 / #10414 | TRACK (#10414 has PR #8883) | Research-grade; competing copies are negative-value |

**Headline result: zero source patches survived adversarial scrutiny as permanent fork divergence.** Every surviving item is build configuration, an env var, an upstream contribution, or a temporary carry with an expiry. This is structural, not incidental: upstream merges near-daily, is responsive to well-formed PRs, and the highest-value perf work is already in flight by the owners of those subsystems.

## 6. Recommendation and plan

### Verdict on "is the efficiency worth the fork cost?"

**Not in the form of carried source patches — with one narrow exception.** The credible wins that don't arrive on their own via `elan update` are (a) a PGO/LTO/`-march`-tuned self-built toolchain and (b) mimalloc tuning — both are toolchain *packaging*, not source divergence. If our workload is Mathlib-free and compiler-throughput-bound, (a) is defensible and potentially worth 5–15%. If we depend on Mathlib, the broken `lake exe cache` story alone outweighs everything surveyed. The fork's rational identity is **staging ground and contribution vehicle**: a place to test upstream PRs/nightlies against internal workloads and to prepare upstream PRs — that path captures most of the same efficiency at a fraction of the cost, and it compounds (landed upstream fixes are maintained by upstream forever).

### Phase 0 — decision gates (before any work)

* **G1**: Do internal projects depend on Mathlib (or its cloud cache)? If yes, rule out distributing self-built toolchains for those projects; config work applies only to Mathlib-free workloads/CI.
* **G2**: Identify the dominant internal cost: compile throughput (CI builds), elaboration latency (editors), or server memory. This orders Phases 1–3.

### Phase 1 — measured toolchain packaging (config-only; ~1–2 weeks; no divergence)

1. Baseline with existing infra: `tests/bench/build` (per-file stdlib timing), `tests/elab_bench`, `tests/compile_bench`, plus one representative internal project.
2. Experiment matrix, one variable at a time: `-march=x86-64-v3`; ThinLTO on runtime/leanshared (watch link time and FFI symbol visibility); PGO (profile = stdlib + internal build); `MIMALLOC_*` env tuning (purge delay, arena reserve, eager commit).
3. Adoption bar: ≥5% end-to-end on an internal workload, else drop. Winners become a documented build recipe (cmake cache file + CI job) at **pinned upstream release tags** — zero source diff. Report mimalloc findings upstream (#7786 follow-up).

### Phase 2 — upstream contribution track (ongoing; 2–4 scoped items)

Ordered first contributions (all deterministic, scoped, currently unowned upstream):

1. **#13987** `Json.parse` panic — trivial; also DoS-relevant for anything parsing untrusted JSON.
2. **#14000** `IO.Process.output` pipe deadlock — fix approach already sketched in the issue (dedicated stdin-writer task).
3. **#14148** `lean_alloc_ctor` mimalloc crash — reproduce first; fix options enumerated in issue.
4. Drive-bys: TryThis placement FIXME; sharecommon stack guard.

Carry policy for our own fixes: a patch may live on the fork **only between upstream submission and the first release tag containing it**, recorded in `doc/dev/fork_patches.md` (patch, upstream PR link, expiry). When the upstream twin merges in modified form, the fork copy is deleted, not reconciled.

### Phase 3 — upstream PR test-and-boost program (fork as staging; ongoing)

* Build throwaway toolchains from upstream PR branches #14109, #14185, #14327, #14086, #14032 (and #8883 for #10414); benchmark against internal workloads; post results on the PRs. Independent benchmark confirmation is exactly what idle-but-green PRs need to land, and it is the cheapest legitimate way to accelerate the ~everything-we-want that is already in upstream's pipeline.
* Watchlist (affects-us triage, subscribe): #14329 (memory regression — bisect + report if it reproduces on our workloads), #6753 (attach heap profiles), #12102, #13063, #9077, #14315, #13113 (only if we deploy on 5-level-paging/MTE hardware), #14362/#13103 (ABI-breaking pipeline work — plan toolchain bumps around them).

### Phase 4 — governance (half a day, then standing)

* Automated mirror sync of `master` from upstream (daily), plus CI that builds the toolchain and runs `tests/elab_bench` on our representative workload at each sync — this is the regression tripwire that would have caught #14329-class regressions before a version bump.
* Fork policy doc encoding the exclusions: **never** diverge on kernel, olean format, or elaborator semantics; unmerged-PR cherry-picks require an explicit exception review; every carried patch has an expiry.

### Explicitly rejected (do not revisit without new evidence)

Removing the `m_cs_sz` store; kernel `ReducePowMaxExp`/`proj_idx` fork patches; `isNewAnswer` normalization; fork-private simp caching; cherry-picking #13898 (uv_spawn) or any `breaks-mathlib`-labeled draft (#14362, #13103, #14369, #14351 in current state).
