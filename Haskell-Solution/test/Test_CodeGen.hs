{-
  Test_CodeGen.hs

  Hard-coded test cases for CodeGen.hs
  Each test matches a Python input file — same IR, same assignments,
  same expected assembly output.

  Usage in GHCi:
    :load Test_CodeGen
    putStr test1
    putStr test6
-}
{-
module Test_CodeGen where

import CodeGen
import Intermediate
import Target
import Liveness (computeLiveness)
import qualified Data.Map as Map
import qualified Data.Set as Set


-- helper: given ops, live-out vars, and assignments, return assembly string
runCodeGen :: [Operation] -> [String] -> [(String, Int)] -> String
runCodeGen ops liveOutList asgList =
  let code       = mkIntermediateCode ops liveOutList
      liveOutSet = Set.fromList liveOutList
      (lb, _la)  = computeLiveness ops liveOutSet
      asg        = Map.fromList asgList
  in showTargetCode (generateTarget lb code asg)


-- | test.txt: a = a + 1; t1 = a * 2; b = t1 / 3; live: a, b
--   Python assigns: a->R0, t1->R1, b->R1
--   expected:
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


-- | test_livein.txt: r = r + s; live: r
--   Python assigns: r->R0, s->R1
--   expected:
--     MOV r,R0
--     MOV s,R1
--     ADD R1,R0
--     MOV R0,r
test2 :: String
test2 = runCodeGen
  [ mkBinOp "r" "r" "+" "s" ]
  ["r"]
  [("r", 0), ("s", 1)]


-- | cg_copy.txt: m = 8; n = m; live: n
--   Python assigns: m->R0, n->R0
--   expected:
--     MOV #8,R0
--     MOV R0,n
test3 :: String
test3 = runCodeGen
  [ mkAssign "m" "8"
  , mkAssign "n" "m"
  ]
  ["n"]
  [("m", 0), ("n", 0)]


-- | cg_neg_livein.txt: x = -x; live: x
--   Python assigns: x->R0
--   expected:
--     MOV x,R0
--     MUL #-1,R0
--     MOV R0,x
test4 :: String
test4 = runCodeGen
  [ mkUnaryNeg "x" "x" ]
  ["x"]
  [("x", 0)]


-- | cg_sub.txt: p = 10; q = p - 4; live: q
--   Python assigns: p->R0, q->R0
--   expected:
--     MOV #10,R0
--     SUB #4,R0
--     MOV R0,q
test5 :: String
test5 = runCodeGen
  [ mkAssign "p" "10"
  , mkBinOp "q" "p" "-" "4"
  ]
  ["q"]
  [("p", 0), ("q", 0)]


-- | cg_div_store.txt: k = 18; t1 = k / 6; z = t1; live: z
--   Python assigns: k->R0, t1->R0, z->R0
--   expected:
--     MOV #18,R0
--     DIV #6,R0
--     MOV R0,z
test6 :: String
test6 = runCodeGen
  [ mkAssign "k" "18"
  , mkBinOp "t1" "k" "/" "6"
  , mkAssign "z" "t1"
  ]
  ["z"]
  [("k", 0), ("t1", 0), ("z", 0)]


-- | cg_mul_chain.txt: u = 3; v = u * 5; w = v; live: w
--   Python assigns: u->R0, v->R0, w->R0
--   expected:
--     MOV #3,R0
--     MUL #5,R0
--     MOV R0,w
test7 :: String
test7 = runCodeGen
  [ mkAssign "u" "3"
  , mkBinOp "v" "u" "*" "5"
  , mkAssign "w" "v"
  ]
  ["w"]
  [("u", 0), ("v", 0), ("w", 0)]


-- | cg_two_liveins.txt: r = r + s; live: r
--   (same as test2 / test_livein.txt)
--   Python assigns: r->R0, s->R1
--   expected:
--     MOV r,R0
--     MOV s,R1
--     ADD R1,R0
--     MOV R0,r
test8 :: String
test8 = runCodeGen
  [ mkBinOp "r" "r" "+" "s" ]
  ["r"]
  [("r", 0), ("s", 1)]


-- To run: ghci Test_CodeGen.hs
-- Then: putStr test1, putStr test2, etc.
-}
module Test_CodeGen (spec) where

import Test.Hspec
import CodeGen
import Intermediate
import Target
import Liveness (computeLiveness)
import qualified Data.Map as Map
import qualified Data.Set as Set

-- This helper MUST be outside the spec block and defined like this:
runCodeGen :: [Operation] -> [String] -> [(String, Int)] -> String
runCodeGen ops liveOutList asgList =
  let code       = mkIntermediateCode ops liveOutList
      liveOutSet = Set.fromList liveOutList
      -- computeLiveness returns ([Set String], [Set String])
      (lb, _la)  = computeLiveness ops liveOutSet
      asg        = Map.fromList asgList
  in showTargetCode (generateTarget lb code asg)

spec :: Spec
spec = describe "CodeGen" $ do

  it "generates correct code for a simple assignment (test1)" $ do
    let ops = [ mkAssign "m" "8", mkAssign "n" "m" ]
    let liveOut = ["n"]
    let assigns = [("m", 0), ("n", 0)]
    
    runCodeGen ops liveOut assigns `shouldBe` unlines 
      [ "MOV #8,R0"
      , "MOV R0,n"
      ]

  it "generates correct code for arithmetic (test2)" $ do
    let ops = [ mkBinOp "a" "a" "+" "1"
              , mkBinOp "t1" "a" "*" "2"
              , mkBinOp "b" "t1" "/" "3"
              ]
    let result = runCodeGen ops ["a", "b"] [("a", 0), ("t1", 1), ("b", 1)]
    result `shouldBe` unlines
      [ "MOV a,R0"
      , "ADD #1,R0"
      , "MOV R0,R1"
      , "MUL #2,R1"
      , "DIV #3,R1"
      , "MOV R0,a"
      , "MOV R1,b"
      ]
  it "handles unary negation (test3)" $ do
    let ir = mkIntermediateCode [ mkUnaryNeg "x" "x" ] ["x"]
    showIntermediateCode ir  `shouldBe` "x = -x\nlive: x" {-This looks butt ugly, but
                                                            its just the following string:
                                                            x = -x
                                                            live: x
                                                              -}
  it "manages complex 7-line blocks (test4)" $ do
    let ir = mkIntermediateCode
            [ mkBinOp "a" "a" "+" "1"
            , mkBinOp "t1" "a" "*" "4"
            , mkBinOp "t2" "t1" "+" "1"
            , mkBinOp "t3" "a" "*" "3"
            , mkBinOp "b" "t2" "-" "t3"
            , mkBinOp "t4" "b" "/" "2"
            , mkBinOp "d" "c" "+" "t4"
            ]
            ["d"]
    let output = showIntermediateCode ir
    output `shouldContain` "b = t2 - t3"
    output `shouldContain` "live: d"