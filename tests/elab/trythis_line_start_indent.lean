module

import Lean.Meta.Tactic.TryThis
public meta import Lean.Meta.TryThis
public meta import Lean.Elab.Command

/-!
Test for `Suggestion.processEdit` indentation: wrapped suggestion lines must be
indented relative to the start column of the replaced range, not the enclosing
line's indentation. Previously, replacing `tac` in `by tac` at the beginning of
a line produced continuation lines indented less than `tac`'s column, which did
not re-parse as part of the same tactic block.
-/

open Lean Meta Tactic TryThis in
run_meta show CoreM Unit from do
  withOptions (format.inputWidth.set · 30) do
  withReader (fun ctx => { ctx with fileMap := FileMap.ofString "by tac\nexact 0" }) do
    let stx ← `(tactic| (skip; skip; skip; skip; skip; skip))
    let s : Suggestion := { suggestion := stx }
    -- `tac` occupies bytes 3..6 on a line that starts with `by`
    let edit ← s.processEdit ⟨⟨3⟩, ⟨6⟩⟩
    logInfo edit.newText
