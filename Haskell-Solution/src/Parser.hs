module Parser
  ( readIR
  ) where

import Data.Char (isAlpha, isDigit, isLower, isSpace)
import Intermediate
  ( Operation, IntermediateCode
    , mkAssign, mkUnaryNeg, mkBinOp
  , mkIntermediateCode
  , getDestination, getOperand1, getOperand2
  )
import Liveness (isVar)
import Data.Maybe (mapMaybe)

-- ===========================================================================================================


-- What it does: Takes a raw line like "a=b+c" or "a = b + c" and returns ["a","=","b","+","c"]. 

tokenizeLine :: String -> [String]
tokenizeLine [] = []

tokenizeLine (c:cx) 
      | isSpace c = tokenizeLine cx 
      | c `elem` "=+-*/" = [c] : tokenizeLine cx
      | isAlpha c || isDigit c  = let (rest, leftover) = span (\x -> isAlpha x || isDigit x) cx
                    in  (c : rest) : tokenizeLine leftover
      | otherwise = error "Parse error: invalid character."

-- ===========================================================================================================

isValidOperand :: String -> Bool
isValidOperand x
      | isVar x || all isDigit x = True
      | otherwise = False

-- ===========================================================================================================

parseInstruction :: String -> Maybe Operation
parseInstruction line =
  let tokens = tokenizeLine line
  in case tokens of
       [] -> Nothing

       [dst, "=", src] ->
         if isVar dst && isValidOperand src
         then Just (mkAssign dst src)
         else error "Parse error: Invalid format: dst = src"

       [dst, "=", "-", src] ->
         if isVar dst && isValidOperand src
         then Just (mkUnaryNeg dst src)
         else error "Parse error: Invalid format: dst = - src"

       [dst, "=", src1, op, src2] ->
         if isVar dst && isValidOperand src1 && isValidOperand src2 && op `elem` ["+", "-", "*", "/"]
         then Just (mkBinOp dst src1 op src2)
         else error "Parse error: Invalid format: dst = src1 op src2"
        
       _ -> error "Parse error: Invalid instruction size."

-- ===========================================================================================================

parseLiveLine :: String -> [Operation] -> [String]
parseLiveLine line ops =
  if take 5 line /= "live:"
  then error "Parse error: final line must start with 'live:'"
  else
    let pieces = splitOnCommas (drop 5 line)
        trimmed = map (dropWhile isSpace) pieces
        vars = filter (not . null) trimmed
    in checkVars vars ops

-- =============================================================================================================

checkVars :: [String] -> [Operation] -> [String]
checkVars [] _ = []
checkVars (v:vs) ops
  | not (isVar v) = error ("Parse error: invalid variable '" ++ v ++ "'")
  | not (appearsIn v ops) = error ("Parse error: variable '" ++ v ++ "' not found in code")
  | otherwise = v : checkVars vs ops

-- ==============================================================================================================

appearsIn :: String -> [Operation] -> Bool
appearsIn v ops = any (\op -> v == getDestination op || v == getOperand1 op || getOperand2 op == Just v) ops

-- =============================================================================================================

splitOnCommas :: String -> [String]
splitOnCommas [] = []
splitOnCommas s =
  let (piece, rest) = span (/= ',') s
  in piece : splitOnCommas (drop 1 rest)
      
-- =============================================================================================================

readIR :: String -> IntermediateCode
readIR contents =
  let allLines = lines contents
      nonEmpty = filter (not . null) allLines
      instrLines = init nonEmpty
      liveLine = last nonEmpty
      ops = mapMaybe parseInstruction instrLines
      liveVars = parseLiveLine liveLine ops
  in mkIntermediateCode ops liveVars