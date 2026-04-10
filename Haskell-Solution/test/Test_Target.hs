{-
  Test_Target.hs
  Automated test cases for Target.hs
  Tests AsmInstruction and TargetCode ADTs.

  Usage in GHCi:
    stack test
-}

module Test_Target (spec) where

import Test.Hspec
import Target

spec :: Spec
spec = do

  -- ************************************************************
  -- AsmInstruction tests
  -- ************************************************************
  describe "Testing showAsmInstruction" $ do

    it "Test 1: ADD with immediate" $
      showAsmInstruction (mkAsmInstruction "ADD" (Just "#1") (Just "R0"))
        `shouldBe` "ADD #1,R0"

    it "Test 2: MOV variable to register" $
      showAsmInstruction (mkAsmInstruction "MOV" (Just "a") (Just "R0"))
        `shouldBe` "MOV a,R0"

    it "Test 3: SUB between registers" $
      showAsmInstruction (mkAsmInstruction "SUB" (Just "R1") (Just "R0"))
        `shouldBe` "SUB R1,R0"

    it "Test 5: MUL with negative immediate" $
      showAsmInstruction (mkAsmInstruction "MUL" (Just "#-1") (Just "R0"))
        `shouldBe` "MUL #-1,R0"

    it "Test 6: DIV between registers" $
      showAsmInstruction (mkAsmInstruction "DIV" (Just "R2") (Just "R1"))
        `shouldBe` "DIV R2,R1"


  -- ************************************************************
  -- TargetCode tests
  -- ************************************************************
  describe "Testing showTargetCode" $ do

    it "Test 7: empty target code is empty string" $
      showTargetCode emptyTargetCode
        `shouldBe` ""

    it "Test 8: small program: MOV then ADD" $
      showTargetCode
        (addInstructions
          [ mkAsmInstruction "MOV" (Just "a") (Just "R0")
          , mkAsmInstruction "ADD" (Just "#1") (Just "R0")
          ]
          emptyTargetCode)
      `shouldBe`
        "MOV a,R0\nADD #1,R0\n"

    it "Test 9: longer program sequence" $
      showTargetCode
        (addInstructions
          [ mkAsmInstruction "MOV" (Just "a") (Just "R0")
          , mkAsmInstruction "ADD" (Just "#1") (Just "R0")
          , mkAsmInstruction "MOV" (Just "R0") (Just "a")
          , mkAsmInstruction "MUL" (Just "#4") (Just "R0")
          ]
          emptyTargetCode)
      `shouldBe`
        (unlines
          [ "MOV a,R0"
          , "ADD #1,R0"
          , "MOV R0,a"
          , "MUL #4,R0"
          ])