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

-- constructor for creating an instruction
mkAsmInstruction :: String -> Maybe String -> Maybe String -> AsmInstruction
mkAsmInstruction opcode src dst = Asm opcode src dst

-- accessor functions
getOpcode :: AsmInstruction -> String
getOpcode (Asm o _ _) = o

getSrc :: AsmInstruction -> Maybe String
getSrc (Asm _ s _) = s

getDst :: AsmInstruction -> Maybe String
getDst (Asm _ _ d) = d

-- format a single instruction as a string
-- covers all four combinations of Maybe src / Maybe dst
showAsmInstruction :: AsmInstruction -> String
showAsmInstruction (Asm op Nothing  Nothing)  = op
showAsmInstruction (Asm op (Just s) Nothing)  = op ++ " " ++ s
showAsmInstruction (Asm op Nothing  (Just d)) = op ++ " " ++ d
showAsmInstruction (Asm op (Just s) (Just d)) = op ++ " " ++ s ++ "," ++ d


-- ============================================================
-- TargetCode: full sequence of assembly instructions
-- ============================================================

data TargetCode = TCode [AsmInstruction]
  deriving (Show)

emptyTargetCode :: TargetCode
emptyTargetCode = TCode []

-- add one instruction to the end
addInstruction :: AsmInstruction -> TargetCode -> TargetCode
addInstruction instr (TCode instrs) = TCode (instrs ++ [instr])

-- add a list of instructions to the end
addInstructions :: [AsmInstruction] -> TargetCode -> TargetCode
addInstructions newInstrs (TCode instrs) = TCode (instrs ++ newInstrs)

getInstructions :: TargetCode -> [AsmInstruction]
getInstructions (TCode instrs) = instrs

-- format the full target code for writing to .s file
showTargetCode :: TargetCode -> String
showTargetCode (TCode instrs) = unlines (map showAsmInstruction instrs)