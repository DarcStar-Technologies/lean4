module

import Lean.Data.Json

/-!
Regression test for #13987: `Json.parse` used to die with the internal panic
`Nat.pow exponent is too big` on numbers with huge positive exponents instead
of returning a catchable parse error.
-/

def test (s : String) : String :=
  match Lean.Json.parse s with
  | .ok res => toString res
  | .error err => err

-- Used to panic with "INTERNAL PANIC: Nat.pow exponent is too big"
#eval test "3E9999999993"
-- Above the runtime `Nat.pow` panic threshold (2^32)
#eval test "3E4294967297"
-- Just above the parser's exponent bound
#eval test "1e1000001"
-- At the bound: accepted (do not print it, the mantissa has 10^6 digits)
#eval toString (Lean.Json.parse "1e1000000" matches .ok _)
-- Ordinary large exponents still parse and print
#eval test "3E100"
-- Huge *negative* exponents are representable without materializing digits
-- and remain accepted (printing would materialize them, so only check parsing)
#eval toString (Lean.Json.parse "3E-9999999993" matches .ok _)
