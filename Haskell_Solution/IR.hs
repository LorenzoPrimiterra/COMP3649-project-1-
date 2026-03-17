{-
  IR.hs — Maps to: intermediate.py
  
  Abstract data type for three-address intermediate code.
  
  Defines:
    - Operation : one instruction (dst = src, dst = -src, dst = src1 op src2)
    - IRBlock   : list of operations + live-out variables

  Constructors hidden — all access through exported functions.
-}

module IR
  ( Operation
  , IRBlock
  , mkAssign, mkUnaryNeg, mkBinOp
  , getDst, getSrc1, getSrc2, getOp, isUnaryNeg
  , mkIRBlock, emptyIRBlock, addOperation
  , getOpList, getLiveOut
  , showOperation, showIRBlock
  ) where

-- TODO
