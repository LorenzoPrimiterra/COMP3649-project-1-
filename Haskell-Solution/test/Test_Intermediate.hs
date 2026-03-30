{-
  Test_Intermediate.hs

  Hard-coded test cases for development and testing.
  Use these in GHCi before the Parser module is ready.

  Usage in GHCi:
    :load Test_Intermediate
    putStr (showIntermediateCode test1)
-}

module Test_Intermediate where

import Intermediate

-- | a = a + 1; t1 = a * 2; b = t1 / 3; live: a, b
test1 :: IntermediateCode
test1 = mkIntermediateCode
  [ mkBinOp  "a"  "a"  "+" "1"
  , mkBinOp  "t1" "a"  "*" "2"
  , mkBinOp  "b"  "t1" "/" "3"
  ]
  ["a", "b"]

-- | r = r + s; live: r  (tests live-on-entry interference)
test2 :: IntermediateCode
test2 = mkIntermediateCode
  [ mkBinOp "r" "r" "+" "s" ]
  ["r"]

-- | x = -x; live: x  (tests unary negation)
test3 :: IntermediateCode
test3 = mkIntermediateCode
  [ mkUnaryNeg "x" "x" ]
  ["x"]

-- | Spec example (7-line)
test4 :: IntermediateCode
test4 = mkIntermediateCode
  [ mkBinOp  "a"  "a"  "+" "1"
  , mkBinOp  "t1" "a"  "*" "4"
  , mkBinOp  "t2" "t1" "+" "1"
  , mkBinOp  "t3" "a"  "*" "3"
  , mkBinOp  "b"  "t2" "-" "t3"
  , mkBinOp  "t4" "b"  "/" "2"
  , mkBinOp  "d"  "c"  "+" "t4"
  ]
  ["d"]

-- | a = 1; b = 2; c = 3; live: a, b, c  (tests needing 3 registers)
test5 :: IntermediateCode
test5 = mkIntermediateCode
  [ mkAssign "a" "1"
  , mkAssign "b" "2"
  , mkAssign "c" "3"
  ]
  ["a", "b", "c"]


-- Save both Intermeidate.hs and Test_Intermedaite.hs, then test:
-- ghci Test_Intermediate.hs


-- Once it loads, try these one by one:
-- putStr (showIntermediateCode test1)
-- putStr (showIntermediateCode test4)
-- showOperation (mkAssign "a" "b")
-- showOperation (mkUnaryNeg "x" "y")
-- getDestination (mkBinOp "t1" "a" "+" "4")
-- isUnaryNeg (mkUnaryNeg "x" "y")
