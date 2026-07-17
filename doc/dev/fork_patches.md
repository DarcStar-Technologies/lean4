# Fork patch carry ledger

Policy (from `doc/dev/fork_execution_plan.md`, FK-24): this fork carries **only our own upstream-submitted fixes**, and only between upstream submission and the first upstream release tag containing the fix. When the upstream twin merges (in any form), the fork copy is **deleted, not reconciled**. Kernel, olean-format, and elaborator-semantics patches are categorically refused. Every entry must have an expiry condition.

| patch (fork commit) | what | upstream issue / PR | submitted | expiry condition | status |
|---|---|---|---|---|---|
| `5c932b24` | `Json.parse`: reject positive exponents > 10^6 instead of panicking (`src/Lean/Data/Json/Parser.lean` + `tests/elab/13987.lean`) | leanprover/lean4#13987 / PR not yet opened | — | delete when upstream ships a fix for #13987 | verified on fork (build + JSON test suite green); awaiting upstream PR submission |
| `c56b7184` | `IO.Process.output`: write stdin from a dedicated task to fix pipe-buffer deadlock on >64KB input (`src/Init/System/IO.lean` + `tests/elab/14000.lean`) | leanprover/lean4#14000 / PR not yet opened | — | delete when upstream ships a fix for #14000 | verified on fork: repro (1MB through `cat`) went from 15s-timeout hang to 1.5s pass; regression test + 45 process/JSON/async tests green (2 socket-test failures are container-IPv6 environmental, unrelated) |
| `87143253` + `1bd18359` | TryThis: align wrapped suggestion lines with the replaced range's start column (`src/Lean/Meta/TryThis.lean` + `tests/elab/trythis_line_start_indent.lean`) | fixes the `processEdit` FIXME (no upstream issue) / PR not yet opened | — | delete when upstream ships an equivalent fix | verified: pre-fix output wrapped below the replacement column (unparseable in `by tac` at line start), post-fix aligns at column; full suite 3980/3983 with zero suggestion-output churn (3 failures environmental: 2 × container lacks IPv6, 1 × running as root bypasses the permission-denied case) |
| `e9bd7e62` | sharecommon visitor: stack-overflow guard per its TODO plan; `get_available_stack_size` lazy thread-info init (`src/runtime/sharecommon.{h,cpp}`, `src/runtime/stackinfo.cpp`) | implements the `sharecommon.cpp` TODO (no upstream issue) / PR not yet opened | — | delete when upstream ships an equivalent guard | verified: full stage build (every stdlib decl passes through `add_theorem`'s share step with the guard active) + full test suite 3980/3983 (same 3 environmental failures) |

Notes:

* Upstream PR submission for #13987 must be done from an account/session with access to `leanprover/lean4`; this session is scoped to the fork only. The commit message on `5c932b24` is written to upstream conventions and can be cherry-picked onto an upstream-master branch as-is.
