{-
  Test_Liveness.hs

  Hard-coded test cases for Liveness.hs
  Tests isVar, defs, uses, and computeLiveness.

  Usage in GHCi:
    :load Test_Liveness
    test1
    test5
-}

module Test_Liveness where

import Liveness
import Intermediate
import Data.Set (Set)
import qualified Data.Set as Set

-- ************************************************************
-- isVar tests
-- ************************************************************

-- | Single lowercase letter is a variable
test1 :: Bool
test1 = isVar "a"
-- expected: True

-- | 't' alone is NOT a variable
test2 :: Bool
test2 = isVar "t"
-- expected: False

-- | Temporary variable t1
test3 :: Bool
test3 = isVar "t1"
-- expected: True

-- | Integer literal is not a variable
test4 :: Bool
test4 = isVar "10"
-- expected: False

-- | Multi-letter name is not a variable
test5 :: Bool
test5 = isVar "aa"
-- expected: False

-- ************************************************************
-- defs and uses tests
-- ************************************************************

-- | defs of a = a + 1 should be {a}
test6 :: Set String
test6 = defs (mkBinOp "a" "a" "+" "1")
-- expected: fromList ["a"]

-- | uses of a = a + 1 should be {a} (1 is a constant, ignored)
test7 :: Set String
test7 = uses (mkBinOp "a" "a" "+" "1")
-- expected: fromList ["a"]

-- | uses of t1 = a * 2 should be {a} (2 is a constant)
test8 :: Set String
test8 = uses (mkBinOp "t1" "a" "*" "2")
-- expected: fromList ["a"]

-- | uses of b = t2 - t3 should be {t2, t3}
test9 :: Set String
test9 = uses (mkBinOp "b" "t2" "-" "t3")
-- expected: fromList ["t2","t3"]

-- | uses of a = 10 (simple assign from constant) should be {}
test10 :: Set String
test10 = uses (mkAssign "a" "10")
-- expected: fromList []

-- ************************************************************
-- computeLiveness tests
-- ************************************************************

-- | test.txt: a = a + 1; t1 = a * 2; b = t1 / 3; live: a, b
--   Walking backwards:
--     after instr 3: {a, b}  before instr 3: {a, t1}
--     after instr 2: {a, t1} before instr 2: {a}
--     after instr 1: {a}     before instr 1: {a}
test11 :: LiveSets
test11 = computeLiveness
  [ mkBinOp "a"  "a"  "+" "1"
  , mkBinOp "t1" "a"  "*" "2"
  , mkBinOp "b"  "t1" "/" "3"
  ]
  (Set.fromList ["a", "b"])
-- expected: ( [fromList ["a"], fromList ["a"], fromList ["a","t1"]]
--           , [fromList ["a"], fromList ["a","t1"], fromList ["a","b"]] )

-- | test_livein.txt: r = r + s; live: r
--   Both r and s must be live before the instruction
test12 :: LiveSets
test12 = computeLiveness
  [ mkBinOp "r" "r" "+" "s" ]
  (Set.fromList ["r"])
-- expected: ( [fromList ["r","s"]]
--           , [fromList ["r"]] )

-- | Single assignment from constant: a = 1; live: a
--   a is not live before (it's just being defined)
test13 :: LiveSets
test13 = computeLiveness
  [ mkAssign "a" "1" ]
  (Set.fromList ["a"])
-- expected: ( [fromList []]
--           , [fromList ["a"]] )


-- To run: ghci Test_Liveness.hs
-- Then type test1, test2, etc. to check output