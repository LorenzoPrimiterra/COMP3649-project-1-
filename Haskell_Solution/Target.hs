{-
  Target.hs — Maps to: target.py

  Abstract data type for target assembly instructions.

  Defines:
    - AsmInstr   : one assembly instruction (e.g. ADD #1,R0)
    - TargetCode : full sequence of assembly instructions

  Constructors hidden.
-}

module Target
  ( AsmInstr
  , TargetCode
  , mkAsmInstr
  , emptyTarget, addInstr, addInstrs
  , getInstrs
  , showAsmInstr, showTargetCode
  ) where

-- TODO
