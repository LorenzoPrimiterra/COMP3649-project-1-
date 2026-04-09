{-
  Parser.hs — Maps to: parser.py

  Reads a string of intermediate code and turns each line into
  structured Haskell values that the rest of the program can work with.

  Role in the Pipeline
  --------------------
  First stage after Main.hs reads the file:

    Main.hs          <- reads the file contents as a String
          |
    Parser.hs        <- validates each line, builds the instruction list
          |
    Intermediate.hs  <- receives the Operation list and live-out variables

  Responsibilities
  ----------------
  - Tokenize each instruction line, handling compact and spaced formats.
  - Validate that destinations are legal variable names.
  - Validate that operands are legal variables or integer literals.
  - Parse the final 'live:' line into a list of variable names.
  - Raise errors (via Haskell's error) on any invalid input.
  - Return a populated IntermediateCode value.

  Out of Scope
  ------------
  - Opening or closing files (Main.hs).
  - Performing liveness analysis (Liveness.hs).
  - Building interference graphs or assigning registers (Interference.hs).
  - Generating assembly instructions (CodeGen.hs).

  Key Abstractions
  ----------------
  readIR(contents)
      Top-level function. Parses a full file string and returns an
      IntermediateCode value.

  parseInstruction(line)
      Parses a single instruction line into a Maybe Operation.

  tokenizeLine(line)
      Breaks a raw line of text into a clean list of tokens.

  parseLiveLine(line, ops)
      Parses the final 'live:' line and validates the variable names.
-}

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


-- ************************************************************
-- tokenizeLine — matches tokenize_line(line) in parser.py
-- ************************************************************
-- | Break a raw instruction line into tokens.
--
--   Takes a raw line like "a=b+c" or "a = b + c" and returns
--   ["a", "=", "b", "+", "c"].
--
--   Rules:
--     - Whitespace is skipped.
--     - Operators and '=' are each returned as single-character tokens.
--     - Identifiers and integer literals are collected character by character.

tokenizeLine :: String -> [String]
tokenizeLine [] = []
tokenizeLine (c:cx)
  | isSpace c = tokenizeLine cx
  | c `elem` "=+-*/" = [c] : tokenizeLine cx
  | isAlpha c || isDigit c =
      let (rest, leftover) = span (\x -> isAlpha x || isDigit x) cx
      in (c : rest) : tokenizeLine leftover
  | otherwise = error "Parse error: invalid character."


-- ************************************************************
-- isValidOperand — matches is_valid_operand(s) in parser.py
-- ************************************************************
-- | Check whether a token is a valid operand.
--
--   An operand is valid if it is a known variable (isVar)
--   or an unsigned integer literal (all digit characters).

isValidOperand :: String -> Bool
isValidOperand x
  | isVar x || all isDigit x = True
  | otherwise                 = False


-- ************************************************************
-- parseInstruction — matches read3AddrInstruction(line) in parser.py
-- ************************************************************
-- | Parse a single three-address instruction line.
--
--   Supported forms:
--     dst = src
--     dst = - src
--     dst = src1 op src2
--
--   Returns Nothing for blank lines, Just op on success,
--   or calls error on malformed input.

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
         if isVar dst && isValidOperand src1 && isValidOperand src2
            && op `elem` ["+", "-", "*", "/"]
           then Just (mkBinOp dst src1 op src2)
           else error "Parse error: Invalid format: dst = src1 op src2"

       _ -> error "Parse error: Invalid instruction size."


-- ************************************************************
-- parseLiveLine — matches parse_live_line(line, ops) in parser.py
-- ************************************************************
-- | Parse the final 'live:' line of the input file.
--
--   Input format:
--     live: v1, v2, v3
--
--   Requirements:
--     - Must start with 'live:'.
--     - Variables must be comma-separated.
--     - Variables must follow the project naming rules (checked via isVar).
--     - Variables listed must have appeared earlier in the code.

parseLiveLine :: String -> [Operation] -> [String]
parseLiveLine line ops =
  if take 5 line /= "live:"
    then error "Parse error: final line must start with 'live:'"
    else
      let pieces  = splitOnCommas (drop 5 line)
          trimmed = map (dropWhile isSpace) pieces
          vars    = filter (not . null) trimmed
      in checkVars vars ops


-- ************************************************************
-- checkVars — helper for parseLiveLine
-- ************************************************************
-- | Validate each live variable name and verify it appears in the code.

checkVars :: [String] -> [Operation] -> [String]
checkVars []     _   = []
checkVars (v:vs) ops
  | not (isVar v)       = error ("Parse error: invalid variable '" ++ v ++ "'")
  | not (appearsIn v ops) = error ("Parse error: variable '" ++ v ++ "' not found in code")
  | otherwise             = v : checkVars vs ops


-- ************************************************************
-- appearsIn — helper for checkVars
-- ************************************************************
-- | Return True if variable v appears as a destination or operand
--   in any of the given operations.

appearsIn :: String -> [Operation] -> Bool
appearsIn v ops =
  any (\op -> v == getDestination op
           || v == getOperand1 op
           || getOperand2 op == Just v) ops


-- ************************************************************
-- splitOnCommas — helper for parseLiveLine
-- ************************************************************
-- | Split a string on comma characters.

splitOnCommas :: String -> [String]
splitOnCommas [] = []
splitOnCommas s  =
  let (piece, rest) = span (/= ',') s
  in piece : splitOnCommas (drop 1 rest)


-- ************************************************************
-- readIR — matches readIntermediateCode(f) in parser.py
-- ************************************************************
-- | Parse an entire intermediate-code file (given as a String).
--
--   File structure:
--     - Zero or more three-address instruction lines.
--     - One final non-empty line of the form: 'live: ...'
--
--   Returns an IntermediateCode value containing the parsed
--   operations and live-out variables.

readIR :: String -> IntermediateCode
readIR contents =
  let allLines   = lines contents
      nonEmpty   = filter (not . null) allLines
      instrLines = init nonEmpty
      liveLine   = last nonEmpty
      ops        = mapMaybe parseInstruction instrLines
      liveVars   = parseLiveLine liveLine ops
  in mkIntermediateCode ops liveVars
