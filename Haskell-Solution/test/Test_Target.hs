{-
  Test_Target.hs

  Hard-coded test cases for Target.hs
  Tests AsmInstruction and TargetCode ADTs.

  Usage in GHCi:
    :load Test_Target
    test1
    putStr test8
-}

module Test_Target where

import Target

-- | ADD with immediate
test1 :: String
test1 = showAsmInstruction (mkAsmInstruction "ADD" (Just "#1") (Just "R0"))
-- expected: "ADD #1,R0"

-- | MOV variable to register
test2 :: String
test2 = showAsmInstruction (mkAsmInstruction "MOV" (Just "a") (Just "R0"))
-- expected: "MOV a,R0"

-- | SUB between registers
test3 :: String
test3 = showAsmInstruction (mkAsmInstruction "SUB" (Just "R1") (Just "R0"))
-- expected: "SUB R1,R0"

-- | MUL with negative immediate
test4 :: String
test4 = showAsmInstruction (mkAsmInstruction "MUL" (Just "#-1") (Just "R0"))
-- expected: "MUL #-1,R0"

-- | DIV between registers
test5 :: String
test5 = showAsmInstruction (mkAsmInstruction "DIV" (Just "R2") (Just "R1"))
-- expected: "DIV R2,R1"

-- | Empty target code
test6 :: String
test6 = showTargetCode emptyTargetCode
-- expected: ""

-- | Build a small program: MOV a,R0 then ADD #1,R0
test7 :: String
test7 = showTargetCode
  (addInstructions
    [ mkAsmInstruction "MOV" (Just "a") (Just "R0")
    , mkAsmInstruction "ADD" (Just "#1") (Just "R0")
    ]
    emptyTargetCode)
-- expected: "MOV a,R0\nADD #1,R0\n"

-- | Longer program matching spec example style
test8 :: String
test8 = showTargetCode
  (addInstructions
    [ mkAsmInstruction "MOV" (Just "a") (Just "R0")
    , mkAsmInstruction "ADD" (Just "#1") (Just "R0")
    , mkAsmInstruction "MOV" (Just "R0") (Just "a")
    , mkAsmInstruction "MUL" (Just "#4") (Just "R0")
    ]
    emptyTargetCode)

-- To run: ghci Test_Target.hs
-- Then type test1, test2, etc. to check output
-- Use putStr for multi-line output: putStr test7