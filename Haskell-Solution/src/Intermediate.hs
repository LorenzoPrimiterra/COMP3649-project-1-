module Intermediate
  ( Operation
  , IntermediateCode
  , mkAssign, mkUnaryNeg, mkBinOp
  , getDestination, getOperand1, getOperand2, getOperator, isUnaryNeg
  , mkIntermediateCode, emptyIntermediateCode, addOperation
  , getOpList, getLiveOut
  , showOperation, showIntermediateCode
  ) where

-- Operation: one three-address instruction
-- matches intermediate.py Operation(destination, operand1, operand2, operator, unary_neg)
data Operation = Op String String (Maybe String) (Maybe String) Bool
  deriving (Show)

-- dst = src
mkAssign :: String -> String -> Operation
mkAssign dst src = Op dst src Nothing Nothing False

-- dst = -src
mkUnaryNeg :: String -> String -> Operation
mkUnaryNeg dst src = Op dst src Nothing Nothing True

-- dst = src1 op src2
mkBinOp :: String -> String -> String -> String -> Operation
mkBinOp dst src1 op src2 = Op dst src1 (Just op) (Just src2) False

-- Queries 
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

-- Display
showOperation :: Operation -> String
showOperation (Op dst src1 Nothing  _        False) = dst ++ " = " ++ src1
showOperation (Op dst src1 Nothing  _        True)  = dst ++ " = -" ++ src1
showOperation (Op dst src1 (Just op) (Just src2) _) =
  dst ++ " = " ++ src1 ++ " " ++ op ++ " " ++ src2
showOperation _ = error "Invalid operation"

-- IntermediateCode: matches intermediate.py IntermediateCode(oplist, live_out)
data IntermediateCode = IC [Operation] [String]
  deriving (Show)

mkIntermediateCode :: [Operation] -> [String] -> IntermediateCode
mkIntermediateCode ops liveOut = IC ops liveOut

emptyIntermediateCode :: IntermediateCode
emptyIntermediateCode = IC [] []

addOperation :: Operation -> IntermediateCode -> IntermediateCode
addOperation op (IC ops lv) = IC (ops ++ [op]) lv

getOpList :: IntermediateCode -> [Operation]
getOpList (IC ops _) = ops

getLiveOut :: IntermediateCode -> [String]
getLiveOut (IC _ lv) = lv

showIntermediateCode :: IntermediateCode -> String
showIntermediateCode (IC ops liveOut) =
  unlines (map showOperation ops) ++
  "live: " ++ commaJoin liveOut
  where
    commaJoin []     = ""
    commaJoin [x]    = x
    commaJoin (x:xs) = x ++ ", " ++ commaJoin xs


-- Replace everything in your Intermediate.hs with this, save, then test:

-- ghci Intermediate.hs
-- showOperation (mkBinOp "t1" "a" "*" "4")
-- showOperation (mkAssign "a" "b")
-- showOperation (mkUnaryNeg "x" "y")
-- getDestination (mkBinOp "t1" "a" "+" "4")
-- isUnaryNeg (mkUnaryNeg "x" "y")
-- putStr (showIntermediateCode (mkIntermediateCode [mkBinOp "a" "a" "+" "1", mkBinOp "t1" "a" "*" "4"] ["d"]))