{-
  Test_Intermediate.hs

  Hard-coded test cases for Intermediate.hs.
  Covers Operation construction, accessor functions, and the
  showIntermediateCode display function.

  Role in the Pipeline
  --------------------
  Standalone test module — no other pipeline stages required.
  Useful for verifying Intermediate.hs in GHCi before Parser.hs is ready.

  Usage in GHCi
  -------------
    :load Test_Intermediate
    putStr (showIntermediateCode test1)
    putStr (showIntermediateCode test4)
    showOperation (mkAssign "a" "b")
    showOperation (mkUnaryNeg "x" "y")
    getDestination (mkBinOp "t1" "a" "+" "4")
    isUnaryNeg (mkUnaryNeg "x" "y")
-}

module Test_Intermediate where

import Intermediate


-- ************************************************************
-- Test cases
-- ************************************************************

-- | Binary operations with integer literals; two live-out variables.
--   Input equivalent:
--     a  = a + 1
--     t1 = a * 2
--     b  = t1 / 3
--     live: a, b
test1 :: IntermediateCode
test1 = mkIntermediateCode
  [ mkBinOp  "a"  "a"  "+" "1"
  , mkBinOp  "t1" "a"  "*" "2"
  , mkBinOp  "b"  "t1" "/" "3"
  ]
  ["a", "b"]


-- | Binary operation with two variable operands; tests live-on-entry interference.
--   Input equivalent:
--     r = r + s
--     live: r
test2 :: IntermediateCode
test2 = mkIntermediateCode
  [ mkBinOp "r" "r" "+" "s" ]
  ["r"]


-- | Unary negation with the same variable as source and destination.
--   Input equivalent:
--     x = -x
--     live: x
test3 :: IntermediateCode
test3 = mkIntermediateCode
  [ mkUnaryNeg "x" "x" ]
  ["x"]


-- | Seven-instruction block from the project specification example.
--   Input equivalent:
--     a  = a + 1
--     t1 = a * 4
--     t2 = t1 + 1
--     t3 = a * 3
--     b  = t2 - t3
--     t4 = b / 2
--     d  = c + t4
--     live: d
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


-- | Three independent assignments; all three variables live on exit.
--   Requires at least 3 registers.
--   Input equivalent:
--     a = 1
--     b = 2
--     c = 3
--     live: a, b, c
test5 :: IntermediateCode
test5 = mkIntermediateCode
  [ mkAssign "a" "1"
  , mkAssign "b" "2"
  , mkAssign "c" "3"
  ]
  ["a", "b", "c"]
