{-
  Test_Target.hs

  Hard-coded test cases for Target.hs.
  Tests AsmInstruction construction and display, TargetCode construction
  and display, and the addInstructions bulk-append function.

  Role in the Pipeline
  --------------------
  Standalone test module — no other pipeline stages required.

  Usage in GHCi
  -------------
    :load Test_Target
    test1
    test2
    putStr test7
    putStr test8
-}

module Test_Target where

import Target


-- ************************************************************
-- AsmInstruction display tests
-- ************************************************************

-- | ADD with an immediate operand.
--   Expected: "ADD #1,R0"
test1 :: String
test1 = showAsmInstruction (mkAsmInstruction "ADD" (Just "#1") (Just "R0"))

-- | MOV from a variable (memory) into a register.
--   Expected: "MOV a,R0"
test2 :: String
test2 = showAsmInstruction (mkAsmInstruction "MOV" (Just "a") (Just "R0"))

-- | SUB between two registers.
--   Expected: "SUB R1,R0"
test3 :: String
test3 = showAsmInstruction (mkAsmInstruction "SUB" (Just "R1") (Just "R0"))

-- | MUL with a negative immediate operand.
--   Expected: "MUL #-1,R0"
test4 :: String
test4 = showAsmInstruction (mkAsmInstruction "MUL" (Just "#-1") (Just "R0"))

-- | DIV between two registers.
--   Expected: "DIV R2,R1"
test5 :: String
test5 = showAsmInstruction (mkAsmInstruction "DIV" (Just "R2") (Just "R1"))


-- ************************************************************
-- TargetCode construction and display tests
-- ************************************************************

-- | Empty target code produces an empty string.
--   Expected: ""
test6 :: String
test6 = showTargetCode emptyTargetCode

-- | Two-instruction program built with addInstructions.
--   Expected: "MOV a,R0\nADD #1,R0\n"
test7 :: String
test7 = showTargetCode
  (addInstructions
    [ mkAsmInstruction "MOV" (Just "a")  (Just "R0")
    , mkAsmInstruction "ADD" (Just "#1") (Just "R0")
    ]
    emptyTargetCode)

-- | Four-instruction program matching the spec example style.
--   Expected:
--     MOV a,R0
--     ADD #1,R0
--     MOV R0,a
--     MUL #4,R0
test8 :: String
test8 = showTargetCode
  (addInstructions
    [ mkAsmInstruction "MOV" (Just "a")  (Just "R0")
    , mkAsmInstruction "ADD" (Just "#1") (Just "R0")
    , mkAsmInstruction "MOV" (Just "R0") (Just "a")
    , mkAsmInstruction "MUL" (Just "#4") (Just "R0")
    ]
    emptyTargetCode)
