{-
  Test_CodeGen.hs

  Hard-coded test cases for CodeGen.hs.
  Each test matches a Python input file — same IR, same register
  assignments, same expected assembly output.

  Role in the Pipeline
  --------------------
  Depends on CodeGen.hs, Intermediate.hs, Target.hs, and Liveness.hs.
  Liveness is computed from the IR rather than hard-coded, matching
  exactly what the full pipeline would produce.

  Usage in GHCi
  -------------
    :load Test_CodeGen
    putStr test1
    putStr test6
-}

module Test_CodeGen where

import CodeGen
import Intermediate
import Target
import Liveness (computeLiveness)
import qualified Data.Map as Map
import qualified Data.Set as Set


-- ************************************************************
-- Helper
-- ************************************************************

-- | Run the full code-generation pipeline for a given block.
--   Computes liveness from the IR, then calls generateTarget.
--
--   Parameters:
--     ops        = list of three-address operations
--     liveOutList = variable names live on exit
--     asgList    = variable-to-register assignment pairs
--
--   Returns the formatted assembly string.
runCodeGen :: [Operation] -> [String] -> [(String, Int)] -> String
runCodeGen ops liveOutList asgList =
  let code       = mkIntermediateCode ops liveOutList
      liveOutSet = Set.fromList liveOutList
      (lb, _la)  = computeLiveness ops liveOutSet
      asg        = Map.fromList asgList
  in showTargetCode (generateTarget lb code asg)


-- ************************************************************
-- Test cases
-- ************************************************************

-- | Binary ops with integer literals; a and b live on exit; t1 shares R1 with b.
--   Input equivalent:
--     a  = a + 1
--     t1 = a * 2
--     b  = t1 / 3
--     live: a, b
--   Assignments: a->R0, t1->R1, b->R1
--
--   Expected:
--     MOV a,R0
--     ADD #1,R0
--     MOV R0,R1
--     MUL #2,R1
--     DIV #3,R1
--     MOV R0,a
--     MOV R1,b
test1 :: String
test1 = runCodeGen
  [ mkBinOp "a"  "a"  "+" "1"
  , mkBinOp "t1" "a"  "*" "2"
  , mkBinOp "b"  "t1" "/" "3"
  ]
  ["a", "b"]
  [("a", 0), ("t1", 1), ("b", 1)]


-- | Binary op with two variable operands; both live on entry.
--   Input equivalent:
--     r = r + s
--     live: r
--   Assignments: r->R0, s->R1
--
--   Expected:
--     MOV r,R0
--     MOV s,R1
--     ADD R1,R0
--     MOV R0,r
test2 :: String
test2 = runCodeGen
  [ mkBinOp "r" "r" "+" "s" ]
  ["r"]
  [("r", 0), ("s", 1)]


-- | Copy chain with same-register assignment; the second MOV is elided.
--   Input equivalent:
--     m = 8
--     n = m
--     live: n
--   Assignments: m->R0, n->R0
--
--   Expected:
--     MOV #8,R0
--     MOV R0,n
test3 :: String
test3 = runCodeGen
  [ mkAssign "m" "8"
  , mkAssign "n" "m"
  ]
  ["n"]
  [("m", 0), ("n", 0)]


-- | Unary negation with the variable live on entry and exit.
--   Input equivalent:
--     x = -x
--     live: x
--   Assignments: x->R0
--
--   Expected:
--     MOV x,R0
--     MUL #-1,R0
--     MOV R0,x
test4 :: String
test4 = runCodeGen
  [ mkUnaryNeg "x" "x" ]
  ["x"]
  [("x", 0)]


-- | Subtraction with an integer literal; p and q share a register.
--   Input equivalent:
--     p = 10
--     q = p - 4
--     live: q
--   Assignments: p->R0, q->R0
--
--   Expected:
--     MOV #10,R0
--     SUB #4,R0
--     MOV R0,q
test5 :: String
test5 = runCodeGen
  [ mkAssign "p" "10"
  , mkBinOp  "q" "p" "-" "4"
  ]
  ["q"]
  [("p", 0), ("q", 0)]


-- | Division then copy; all three variables share R0.
--   Input equivalent:
--     k  = 18
--     t1 = k / 6
--     z  = t1
--     live: z
--   Assignments: k->R0, t1->R0, z->R0
--
--   Expected:
--     MOV #18,R0
--     DIV #6,R0
--     MOV R0,z
test6 :: String
test6 = runCodeGen
  [ mkAssign "k"  "18"
  , mkBinOp  "t1" "k"  "/" "6"
  , mkAssign "z"  "t1"
  ]
  ["z"]
  [("k", 0), ("t1", 0), ("z", 0)]


-- | Multiply chain; all three variables share R0.
--   Input equivalent:
--     u = 3
--     v = u * 5
--     w = v
--     live: w
--   Assignments: u->R0, v->R0, w->R0
--
--   Expected:
--     MOV #3,R0
--     MUL #5,R0
--     MOV R0,w
test7 :: String
test7 = runCodeGen
  [ mkAssign "u" "3"
  , mkBinOp  "v" "u" "*" "5"
  , mkAssign "w" "v"
  ]
  ["w"]
  [("u", 0), ("v", 0), ("w", 0)]


-- | Two live-on-entry variables; same IR and assignments as test2.
--   Input equivalent:
--     r = r + s
--     live: r
--   Assignments: r->R0, s->R1
--
--   Expected:
--     MOV r,R0
--     MOV s,R1
--     ADD R1,R0
--     MOV R0,r
test8 :: String
test8 = runCodeGen
  [ mkBinOp "r" "r" "+" "s" ]
  ["r"]
  [("r", 0), ("s", 1)]
