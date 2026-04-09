{-
  Intermediate.hs — Maps to: intermediate.py

  Defines the data structures used to store a program's instructions
  and variables after they have been parsed from the input file.

  Role in the Pipeline
  --------------------
  Receives parsed data from Parser.hs and acts as the shared data structure
  passed through the rest of the pipeline:

    Parser.hs        <- constructs Operation and IntermediateCode values
          |
    Intermediate.hs  <- stores instructions and live-out vars
          |
    Liveness.hs      <- reads oplist to compute live_before / live_after
          |
    Interference.hs  <- reads oplist, live_out, live_before, live_after

  Responsibilities
  ----------------
  - Define Operation, representing one three-address instruction.
  - Define IntermediateCode, representing a full block of Operations.
  - Store the parsed instruction list and live-out variables.
  - Provide constructors and accessors (module hides data constructors).
  - Provide string output that mirrors the original input file format.

  Out of Scope
  ------------
  - Reading or parsing input files (Parser.hs).
  - Computing liveness (Liveness.hs).
  - Building interference graphs or assigning registers (Interference.hs).
  - Generating assembly instructions (Target.hs).

  Key Abstractions
  ----------------
  Operation
      Stores one instruction: its destination, operands, operator,
      and whether it uses a unary minus.

  IntermediateCode
      Holds the full list of instructions and the live-out variables.
-}

module Intermediate
  ( Operation
  , IntermediateCode
  , mkAssign, mkUnaryNeg, mkBinOp
  , getDestination, getOperand1, getOperand2, getOperator, isUnaryNeg
  , mkIntermediateCode, emptyIntermediateCode, addOperation
  , getOpList, getLiveOut
  , showOperation, showIntermediateCode
  ) where


-- ============================================================
-- Operation: one three-address instruction
-- Matches intermediate.py Operation(destination, operand1,
--                                   operand2, operator, unary_neg)
-- ============================================================

data Operation = Op String String (Maybe String) (Maybe String) Bool
  deriving (Show)


-- ------------------------------------------------------------
-- Smart constructors
-- ------------------------------------------------------------

-- | dst = src
mkAssign :: String -> String -> Operation
mkAssign dst src = Op dst src Nothing Nothing False

-- | dst = -src
mkUnaryNeg :: String -> String -> Operation
mkUnaryNeg dst src = Op dst src Nothing Nothing True

-- | dst = src1 op src2
mkBinOp :: String -> String -> String -> String -> Operation
mkBinOp dst src1 op src2 = Op dst src1 (Just op) (Just src2) False


-- ------------------------------------------------------------
-- Accessors
-- ------------------------------------------------------------

getDestination :: Operation -> String
getDestination (Op d _ _ _ _) = d

getOperand1 :: Operation -> String
getOperand1 (Op _ s _ _ _) = s

getOperand2 :: Operation -> Maybe String
getOperand2 (Op _ _ _ s _) = s

getOperator :: Operation -> Maybe String
getOperator (Op _ _ o _ _) = o

isUnaryNeg :: Operation -> Bool
isUnaryNeg (Op _ _ _ _ u) = u


-- ------------------------------------------------------------
-- Display
-- ------------------------------------------------------------

showOperation :: Operation -> String
showOperation (Op dst src1 Nothing  _         False) = dst ++ " = " ++ src1
showOperation (Op dst src1 Nothing  _         True)  = dst ++ " = -" ++ src1
showOperation (Op dst src1 (Just op) (Just src2) _)  =
  dst ++ " = " ++ src1 ++ " " ++ op ++ " " ++ src2
showOperation _ = error "Invalid operation"


-- ============================================================
-- IntermediateCode: matches intermediate.py IntermediateCode(oplist, live_out)
-- ============================================================

data IntermediateCode = IC [Operation] [String]
  deriving (Show)


-- ------------------------------------------------------------
-- Constructors
-- ------------------------------------------------------------

mkIntermediateCode :: [Operation] -> [String] -> IntermediateCode
mkIntermediateCode ops liveOut = IC ops liveOut

emptyIntermediateCode :: IntermediateCode
emptyIntermediateCode = IC [] []

-- | Append a single operation to the end of the block.
addOperation :: Operation -> IntermediateCode -> IntermediateCode
addOperation op (IC ops lv) = IC (ops ++ [op]) lv


-- ------------------------------------------------------------
-- Accessors
-- ------------------------------------------------------------

getOpList :: IntermediateCode -> [Operation]
getOpList (IC ops _) = ops

getLiveOut :: IntermediateCode -> [String]
getLiveOut (IC _ lv) = lv


-- ------------------------------------------------------------
-- Display
-- ------------------------------------------------------------

showIntermediateCode :: IntermediateCode -> String
showIntermediateCode (IC ops liveOut) =
  unlines (map showOperation ops) ++
  "live: " ++ commaJoin liveOut
  where
    commaJoin []     = ""
    commaJoin [x]    = x
    commaJoin (x:xs) = x ++ ", " ++ commaJoin xs


{-
  GHCi test commands:

  ghci Intermediate.hs
  showOperation (mkBinOp "t1" "a" "*" "4")
  showOperation (mkAssign "a" "b")
  showOperation (mkUnaryNeg "x" "y")
  getDestination (mkBinOp "t1" "a" "+" "4")
  isUnaryNeg (mkUnaryNeg "x" "y")
  putStr (showIntermediateCode (mkIntermediateCode
            [mkBinOp "a" "a" "+" "1", mkBinOp "t1" "a" "*" "4"] ["d"]))
-}
