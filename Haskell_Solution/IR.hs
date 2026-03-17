{-
  IR.hs — Maps to: intermediate.py
  
  Abstract data type for three-address intermediate code.
  
  Defines:
    - Operation : one instruction (dst = src, dst = -src, dst = src1 op src2)
    - IRBlock   : list of operations + live-out variables

  Constructors hidden — all access through exported functions.
-}

{-module IR
  ( Operation
  , IRBlock
  , mkAssign, mkUnaryNeg, mkBinOp
  , getDst, getSrc1, getSrc2, getOp, isUnaryNeg
  , mkIRBlock, emptyIRBlock, addOperation
  , getOpList, getLiveOut
  , showOperation, showIRBlock
  ) where

-- TODO
-}
module ThreeAddress
(
    Instruction,
    InstructionSeq,
    makeAssign,
    makeBinOp,
    makeConst,
    emptySeq,
    addInstruction
)
where

type Variable = String

data Instruction
    = Assign Variable Variable
    | BinOp Variable String Variable Variable
    | Const Variable Int
    deriving (Show)

data InstructionSeq =
    InstructionSeq [Instruction] [Variable]
    deriving (Show)

makeAssign :: Variable -> Variable -> Instruction
makeAssign = Assign

makeBinOp :: Variable -> String -> Variable -> Variable -> Instruction
makeBinOp = BinOp

makeConst :: Variable -> Int -> Instruction
makeConst = Const

emptySeq :: InstructionSeq
emptySeq = InstructionSeq [] []

addInstruction :: Instruction -> InstructionSeq -> InstructionSeq
addInstruction i (InstructionSeq xs live) =
    InstructionSeq (xs ++ [i]) live