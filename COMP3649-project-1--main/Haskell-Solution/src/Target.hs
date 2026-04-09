{-
  Target.hs — Maps to: target.py

  Defines data structures for storing and displaying
  target assembly instructions after code generation.

  Role in the Pipeline
  --------------------
  Sits at the end of the pipeline as the final output stage:

    Interference.hs  <- provides register assignments
          |
    Target.hs        <- stores and formats the generated assembly instructions
          |
    output           <- assembly code ready to be written to a .s file

  Responsibilities
  ----------------
  - Define AsmInstruction, representing a single assembly instruction.
  - Define TargetCode, representing a full sequence of assembly instructions.
  - Provide string output that formats instructions in correct assembly syntax.
  - Hide data constructors; provide a clean smart-constructor interface.

  Out of Scope
  ------------
  - Parsing input files (Parser.hs).
  - Computing liveness (Liveness.hs).
  - Building interference graphs or assigning registers (Interference.hs).
  - Translating three-address instructions (CodeGen.hs).

  Key Abstractions
  ----------------
  AsmInstruction
      One assembly instruction: opcode, optional src, optional dst.

  TargetCode
      Full sequence of assembly instructions for a basic block.
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


-- | Constructor for all instruction forms.
mkAsmInstruction :: String -> Maybe String -> Maybe String -> AsmInstruction
mkAsmInstruction = Asm


-- ------------------------------------------------------------
-- Accessors
-- ------------------------------------------------------------

getOpcode :: AsmInstruction -> String
getOpcode (Asm o _ _) = o

getSrc :: AsmInstruction -> Maybe String
getSrc (Asm _ s _) = s

getDst :: AsmInstruction -> Maybe String
getDst (Asm _ _ d) = d


-- ------------------------------------------------------------
-- Display
-- ------------------------------------------------------------

showAsmInstruction :: AsmInstruction -> String
showAsmInstruction (Asm op Nothing  Nothing)  = op
showAsmInstruction (Asm op (Just s) Nothing)  = op ++ " " ++ s
showAsmInstruction (Asm op (Just s) (Just d)) = op ++ " " ++ s ++ "," ++ d
showAsmInstruction (Asm op Nothing  (Just _)) = op  -- dst without src: show opcode only


-- ============================================================
-- TargetCode: full sequence of assembly instructions
-- ============================================================

data TargetCode = TCode [AsmInstruction]
  deriving (Show)


-- | Create an empty target code sequence.
emptyTargetCode :: TargetCode
emptyTargetCode = TCode []

-- | Append a single instruction to the end of the sequence.
addInstruction :: AsmInstruction -> TargetCode -> TargetCode
addInstruction i (TCode is) = TCode (is ++ [i])

-- | Append a list of instructions to the end of the sequence.
addInstructions :: [AsmInstruction] -> TargetCode -> TargetCode
addInstructions new (TCode is) = TCode (is ++ new)

-- | Return the list of instructions.
getInstructions :: TargetCode -> [AsmInstruction]
getInstructions (TCode is) = is

-- | Format the full target code for output to a .s file.
showTargetCode :: TargetCode -> String
showTargetCode (TCode is) = unlines (map showAsmInstruction is)


{-
  GHCi test commands:

  :load Target
  showAsmInstruction (mkAsmInstruction "ADD" (Just "#1") (Just "R0"))
  -- "ADD #1,R0"

  let t = addInstructions
            [ mkAsmInstruction "MOV" (Just "a") (Just "R0")
            , mkAsmInstruction "ADD" (Just "#1") (Just "R0")
            ] emptyTargetCode
  putStr (showTargetCode t)
  -- MOV a,R0
  -- ADD #1,R0
-}
