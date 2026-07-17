module

/-!
Regression test for #14000: `IO.Process.output` deadlocked when the provided
input string exceeded the OS pipe buffer (~64KB on Linux), because stdin was
written to completion on the current thread before stdout/stderr were drained.
Passes 1MB through `cat` and checks that it round-trips.
-/

def test : IO Unit := do
  let input := "".pushn 'a' 1000000
  let out ← IO.Process.output { cmd := "cat" } (some input)
  unless out.exitCode == 0 do throw <| .userError s!"cat exited with {out.exitCode}"
  unless out.stdout == input do throw <| .userError "stdout does not round-trip"
  unless out.stderr.isEmpty do throw <| .userError s!"unexpected stderr: {out.stderr}"
  IO.println "ok"

/-- info: ok -/
#guard_msgs in #eval test
