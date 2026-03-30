{-
  Target.hs — Maps to: target.py

  Abstract data type for target assembly instructions.

  Defines:
    - AsmInstr   : one assembly instruction (e.g. ADD #1,R0)
    - TargetCode : full sequence of assembly instructions

  Constructors hidden.
-}

module Target
  ( AsmInstruction
  , TargetCode
  , mkAsmInstruction
  , getOpcode, getSrc, getDst
  , emptyTargetCode, addInstruction, addInstructions
  , getInstructions
  , showAsmInstruction, showTargetCode
  ) where

-- ============================================================
-- AsmInstruction: one assembly instruction
-- ============================================================

{-
  Internal representation:
    Asm opcode (Maybe src) (Maybe dst)

  Supported forms:
    opcode              e.g. NOP
    opcode src          e.g. PUSH R0
    opcode src,dst      e.g. ADD #1,R0   MOV R1,a
-}
data AsmInstruction = Asm String (Maybe String) (Maybe String)
  deriving (Show)

-- | Constructor for all instruction forms
mkAsmInstruction :: String -> Maybe String -> Maybe String -> AsmInstruction
mkAsmInstruction = Asm

-- Queries
getOpcode :: AsmInstruction -> String
getOpcode (Asm o _ _) = o

getSrc :: AsmInstruction -> Maybe String
getSrc (Asm _ s _) = s

getDst :: AsmInstruction -> Maybe String
getDst (Asm _ _ d) = d

-- Display
showAsmInstruction :: AsmInstruction -> String
showAsmInstruction (Asm op Nothing  Nothing)  = op
showAsmInstruction (Asm op (Just s) Nothing)  = op ++ " " ++ s
showAsmInstruction (Asm op (Just s) (Just d)) = op ++ " " ++ s ++ "," ++ d

-- ============================================================
-- TargetCode: full sequence of assembly instructions
-- ============================================================

data TargetCode = TCode [AsmInstruction]
  deriving (Show)

-- | Create an empty target code sequence
emptyTargetCode :: TargetCode
emptyTargetCode = TCode []

-- | Append a single instruction to the end
addInstruction :: AsmInstruction -> TargetCode -> TargetCode
addInstruction i (TCode is) = TCode (is ++ [i])

-- | Append a list of instructions to the end
addInstructions :: [AsmInstruction] -> TargetCode -> TargetCode
addInstructions new (TCode is) = TCode (is ++ new)

-- | Get the list of instructions
getInstructions :: TargetCode -> [AsmInstruction]
getInstructions (TCode is) = is

-- | Format the full target code for output to .s file
showTargetCode :: TargetCode -> String
showTargetCode (TCode is) = unlines (map showAsmInstruction is)


-- Test in GHCi:

-- > :load Target
-- > showAsmInstruction (mkAsmInstruction "ADD" (Just "#1") (Just "R0"))
-- "ADD #1,R0"
-- > let t = addInstruction (mkAsmInstruction "ADD" (Just "#1") (Just "R0")) (addInstruction (mkAsmInstruction "MOV" (Just "a") (Just "R0")) emptyTargetCode)
-- > putStr (showTargetCode t)
-- MOV a,R0
-- ADD #1,R0
