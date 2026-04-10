module Test_CodeGen (spec) where

import Test.Hspec
import CodeGen
import Intermediate
import Target
import Liveness (computeLiveness)
import qualified Data.Map as Map
import qualified Data.Set as Set

--Helper for our test cases.
runCodeGen :: [Operation] -> [String] -> [(String, Int)] -> String
runCodeGen ops liveOutList asgList =
  let code       = mkIntermediateCode ops liveOutList
      liveOutSet = Set.fromList liveOutList
      (lb, _la)  = computeLiveness ops liveOutSet
      asg        = Map.fromList asgList
  in showTargetCode (generateTarget lb code asg)

spec :: Spec
spec = describe "CodeGen" $ do

  it "Test 1: generates correct code for a simple assignment" $ do
    let ops = [ mkAssign "m" "8", mkAssign "n" "m" ]
    let liveOut = ["n"]
    let assigns = [("m", 0), ("n", 0)]
    
    runCodeGen ops liveOut assigns `shouldBe` unlines 
      [ "MOV #8,R0"
      , "MOV R0,n"
      ]

  it "Test 2: generates correct code for arithmetic " $ do
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
  it "Test 3: handles unary negation" $ do
    let ir = mkIntermediateCode [ mkUnaryNeg "x" "x" ] ["x"]
    showIntermediateCode ir  `shouldBe` "x = -x\nlive: x" {-This looks butt ugly, but
                                                            its just the following string:
                                                            x = -x
                                                            live: x
                                                              -}
  it "Test 4: manages complex 7-line blocks" $ do
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