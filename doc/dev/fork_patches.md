# Fork patch carry ledger

Policy (from `doc/dev/fork_execution_plan.md`, FK-24): this fork carries **only our own upstream-submitted fixes**, and only between upstream submission and the first upstream release tag containing the fix. When the upstream twin merges (in any form), the fork copy is **deleted, not reconciled**. Kernel, olean-format, and elaborator-semantics patches are categorically refused. Every entry must have an expiry condition.

| patch (fork commit) | what | upstream issue / PR | submitted | expiry condition | status |
|---|---|---|---|---|---|
| `5c932b24` | `Json.parse`: reject positive exponents > 10^6 instead of panicking (`src/Lean/Data/Json/Parser.lean` + `tests/elab/13987.lean`) | leanprover/lean4#13987 / PR not yet opened | — | delete when upstream ships a fix for #13987 | verified on fork (build + JSON test suite green); awaiting upstream PR submission |
| `c56b7184` | `IO.Process.output`: write stdin from a dedicated task to fix pipe-buffer deadlock on >64KB input (`src/Init/System/IO.lean` + `tests/elab/14000.lean`) | leanprover/lean4#14000 / PR not yet opened | — | delete when upstream ships a fix for #14000 | verified on fork: repro (1MB through `cat`) went from 15s-timeout hang to 1.5s pass; regression test + 45 process/JSON/async tests green (2 socket-test failures are container-IPv6 environmental, unrelated) |

Notes:

* Upstream PR submission for #13987 must be done from an account/session with access to `leanprover/lean4`; this session is scoped to the fork only. The commit message on `5c932b24` is written to upstream conventions and can be cherry-picked onto an upstream-master branch as-is.
