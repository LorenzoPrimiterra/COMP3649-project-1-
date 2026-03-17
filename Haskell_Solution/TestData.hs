{-
  TestData.hs

  Hard-coded test cases for development and testing.
  Use these in GHCi before the Parser module is ready.

  Usage in GHCi:
    :load TestData
    showIRBlock test1
-}

module TestData where

import IR

-- | a = a + 1; t1 = a * 2; b = t1 / 3; live: a, b
test1 :: IRBlock
test1 = mkIRBlock
  [ mkBinOp  "a"  "a"  "+" "1"
  , mkBinOp  "t1" "a"  "*" "2"
  , mkBinOp  "b"  "t1" "/" "3"
  ]
  ["a", "b"]

-- | r = r + s; live: r  (tests live-on-entry interference)
test2 :: IRBlock
test2 = mkIRBlock
  [ mkBinOp "r" "r" "+" "s" ]
  ["r"]

-- | x = -x; live: x  (tests unary negation)
test3 :: IRBlock
test3 = mkIRBlock
  [ mkUnaryNeg "x" "x" ]
  ["x"]

-- | Spec example (7-line)
-- a = a + 1; t1 = a * 4; t2 = t1 + 1; t3 = a * 3;
-- b = t2 - t3; t4 = b / 2; d = c + t4; live: d
test4 :: IRBlock
test4 = mkIRBlock
  [ mkBinOp  "a"  "a"  "+" "1"
  , mkBinOp  "t1" "a"  "*" "4"
  , mkBinOp  "t2" "t1" "+" "1"
  , mkBinOp  "t3" "a"  "*" "3"
  , mkBinOp  "b"  "t2" "-" "t3"
  , mkBinOp  "t4" "b"  "/" "2"
  , mkBinOp  "d"  "c"  "+" "t4"
  ]
  ["d"]

-- | a = 1; b = 2; c = 3; live: a, b, c  (tests allocation failure with <3 regs)
test5 :: IRBlock
test5 = mkIRBlock
  [ mkAssign "a" "1"
  , mkAssign "b" "2"
  , mkAssign "c" "3"
  ]
  ["a", "b", "c"]
