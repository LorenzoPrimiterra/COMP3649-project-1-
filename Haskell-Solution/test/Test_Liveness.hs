module Test_Liveness (spec) where

import Test.Hspec
import Liveness
import Intermediate
import qualified Data.Set as Set

spec :: Spec
spec = do

  -- ************************************************************
  -- isVar tests
  -- ************************************************************
  describe "Testing isVar" $ do

    it "Test 1: accepts single lowercase variable" $
      isVar "a" `shouldBe` True

    it "Test 2:rejects 't' alone" $
      isVar "t" `shouldBe` False

    it "Test 3: accepts temporary variable t1" $
      isVar "t1" `shouldBe` True

    it "Test 4: rejects integer literal" $
      isVar "10" `shouldBe` False

    it "Test 5: rejects multi-letter variable" $
      isVar "aa" `shouldBe` False


  -- ************************************************************
  -- defs and uses tests
  -- ************************************************************
  describe "Testing defs" $ do

    it "Test 6: defs of a = a + 1 is {a}" $
      defs (mkBinOp "a" "a" "+" "1")
        `shouldBe` Set.fromList ["a"]


  describe "Tesing uses" $ do

    it "Test 7: uses of a = a + 1 is {a}" $
      uses (mkBinOp "a" "a" "+" "1")
        `shouldBe` Set.fromList ["a"]

    it "Test 8: uses of t1 = a * 2 is {a}" $
      uses (mkBinOp "t1" "a" "*" "2")
        `shouldBe` Set.fromList ["a"]

    it "Test 9: uses of b = t2 - t3 is {t2, t3}" $
      uses (mkBinOp "b" "t2" "-" "t3")
        `shouldBe` Set.fromList ["t2","t3"]

    it "Test 10: uses of a = 10 is empty" $
      uses (mkAssign "a" "10")
        `shouldBe` Set.empty


  -- ************************************************************
  -- computeLiveness tests
  -- ************************************************************
  describe "Testing computeLiveness" $ do

    it "Test 11: multi-instruction liveness" $
      computeLiveness
        [ mkBinOp "a"  "a"  "+" "1"
        , mkBinOp "t1" "a"  "*" "2"
        , mkBinOp "b"  "t1" "/" "3"
        ]
        (Set.fromList ["a","b"])
      `shouldBe`
        ( [ Set.fromList ["a"]
          , Set.fromList ["a"]
          , Set.fromList ["a","t1"]
          ]
        , [ Set.fromList ["a"]
          , Set.fromList ["a","t1"]
          , Set.fromList ["a","b"]
          ]
        )

    it "Test 12: live-in variables propagate" $
      computeLiveness
        [ mkBinOp "r" "r" "+" "s" ]
        (Set.fromList ["r"])
      `shouldBe`
        ( [ Set.fromList ["r","s"] ]
        , [ Set.fromList ["r"] ]
        )

    it "Test 13: assignment from constant" $
      computeLiveness
        [ mkAssign "a" "1" ]
        (Set.fromList ["a"])
      `shouldBe`
        ( [ Set.empty ]
        , [ Set.fromList ["a"] ]
        )