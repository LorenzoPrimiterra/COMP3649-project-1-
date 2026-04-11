{-
Name: Parser.hs
===============

Pipeline:
===========
The Parser.hs module handles the first stage of the pipeline, turning raw
intermediate-code text into structured Haskell values:


    (1)  main.hs          <-  validates args, opens file, sequences all stages
    
    (2)  Parser.hs        <- parses input into an IntermediateCode object
    
    (3)   Liveness.hs      <- annotates each instruction with live_before/live_after
     
    (4)  Interference.hs  <- builds interference graph, performs register allocation
    
    (5)  stdout           <- prints interference table and register assignments

Responsibilities:
=====================
-  Tokenizes each raw instruction line into a list of string tokens
- Validates that operands are either variable names or integer literals
-  Parses each instruction line into an Operation (assign, unary neg, or binary op)
- Parses the final 'live:' line into a list of live-out variable names
- Validates that every live-out variable appears somewhere in the instruction list
- Assembles all parsed data into a single IntermediateCode object via readIR

Associated Dependencies:
==============================
(1) Data.Char        <- isAlpha, isDigit, isLower, isSpace for character-level checks
(2) Data.Maybe       <- mapMaybe to skip blank/empty instruction lines
(3) Intermediate.hs  <-   Operation, IntermediateCode types; smart constructors
                        mkAssign, mkUnaryNeg, mkBinOp, mkIntermediateCode;
                         field accessors getDestination, getOperand1, getOperand2
(4) Liveness.hs      <- isVar to validate variable name format

Usage Example:
================
NA

Misc Notes:
================
- All parse errors are raised with 'error' (no custom error type in this module)
- Blank lines are silently ignored; only the last non-empty line is treated as 'live:'
- Supported operators: +  -  *  /
- Integer literals are accepted as operands but only lowercase variable names
  are accepted as destinations (enforced by isVar from Liveness.hs)
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

-- ===========================================================================================================

{-
tokenizeLine
-------------
Splits a single raw instruction line into a list of string tokens,
discarding all whitespace.

Responsibilities:
- Skip any whitespace characters.
- Emit single-character tokens for operator symbols ( = + - * / )
- Emit multi-character tokens for alphanumeric identifiers and integer literals
-  Raise an error on any character that does not belong to the above categories

Returns:
  A list of String tokens, e.g. "a = b + c" -> ["a","=","b","+","c"']

Raises:
  error "Parse error: invalid character." on any unrecognised character
-}
tokenizeLine :: String -> [String]
tokenizeLine [] = []

tokenizeLine (c:cx) 
      | isSpace c = tokenizeLine cx 
      | c `elem` "=+-*/" = [c] : tokenizeLine cx
      | isAlpha c || isDigit c  = let (rest, leftover) = span (\x -> isAlpha x || isDigit x) cx
                    in  (c : rest) : tokenizeLine leftover
      | otherwise = error "Parse error: invalid character."

-- ===========================================================================================================
  {-
isValidOperand
---------------
Checks whether a token is a legal operand (right-hand side value).

Responsibilities:
- Accept the token if it is a variable name (as defined by isVar)
- Accept the token if it is a non-negative integer literal (all digits)
- Reject anything else

Returns:
  True  if the token is a valid variable or integer literal
  False otherwise
-}

isValidOperand :: String -> Bool
isValidOperand x
      | isVar x || all isDigit x = True
      | otherwise = False

-- ==========================================================================================================================

{-
parseInstruction
-----------------
Parses a single tokenized instruction line into an Operation, or
returns Nothing for blank lines.

Supported instruction forms (after tokenisation):
  [dst, "=", src]          ->  assignment        (mkAssign)
  [dst, "=", "-", src]        ->  unary negation    (mkUnaryNeg)
  [dst, "=", src1, op, src2]   ->  binary operation  (mkBinOp)

Responsibilities:
-  Tokenize the raw line. 
- Match the token list against each supported instruction shape.
- Validate that destinations are variables and operands are valid
- Delegate construction to smart constructors from Intermediate.hs.

Returns:
  Just Operation  on a 'well-formed' instruction line
  Nothing      -   on an empty token list (blank line)

Raises:
  error "Parse error: ..." if the token shape is recognised but the
  operands/destination fail validation, or if the token count matches
  no known instruction form
  
-}
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

-- =========================================================================================

{-
parseLiveLine
--------------
Parses the final 'live:' line of an intermediate-code file into a list
of live-out variable names, and validates each variable against the
parsed instruction list.

Responsibilities:
- Verify that the line begins with the prefix "live:".
- Split the remainder on commas to obtain individual variable tokens.
- Strip leading whitespace from each token and drop empty tokens.
- Delegate per-variable validation to checkVars.

Returns:
  A list of validated live-out variable name strings**

Raises:
  error "Parse error: final line must start with 'live:'" if the prefix
  is absent -- further errors may be raised by checkVars
-}
parseLiveLine :: String -> [Operation] -> [String]
parseLiveLine line ops =
  if take 5 line /= "live:"
  then error "Parse error: final line must start with 'live:'"
  else
    let pieces = splitOnCommas (drop 5 line)
        trimmed = map (dropWhile isSpace) pieces
        vars = filter (not . null) trimmed
    in checkVars vars ops

-- ===============================================================================================================

{-
checkVars:
-----------
Validates a list of candidate live-out variable names against the
parsed instruction list.

Responsibilities:
- Confirm each candidate token is a syntactically valid variable name
 
- Confirm each variable actually appears somewhere in the instruction
  list as a destination or operand (via appearsIn)
  
- Accumulate and return the validated variable list

Returns:
  The original variable list unchanged if all checks pass.

Raises:
  error "Parse error: invalid variable '...'"  if a token is not a valid variable name
  error "Parse error: variable '...' not found in code"  if a variable has no
  corresponding definition or use in the instruction list
-}
checkVars :: [String] -> [Operation] -> [String]
checkVars [] _ = []
checkVars (v:vs) ops
  | not (isVar v) = error ("Parse error: invalid variable '" ++ v ++ "'")
  | not (appearsIn v ops) = error ("Parse error: variable '" ++ v ++ "' not found in code")
  | otherwise = v : checkVars vs ops

-- ==========================================================================================================
{-
appearsIn
----------
Tests whether a variable name occurs anywhere within the instruction
list, either as a destination or as an operand.

Responsibilities:
- Check the destination field of each Operation
- Check operand1 of each Operation
- Check operand2 (a Maybe field) of each Operation

Returns:
  True  if the variable is found in at least one instruction field
  False if it appears in none
-}
appearsIn :: String -> [Operation] -> Bool
appearsIn v ops = any (\op -> v == getDestination op || v == getOperand1 op || getOperand2 op == Just v) ops

-- =============================================================================================================

{-
splitOnCommas
--------------
Splits a string on every comma character, returning the list of
substrings between commas (including empty strings for adjacent commas).

Responsibilities:
- Consume the input left-to-right
- Emit each segment up to (but not including) the next comma 
- Drop the comma itself before recursing (importnat)
- Return an empty list for an empty input string

Returns:
  A list of substrings, e.g. " a, b, c" -> [" a"," b"," c"]
-}
splitOnCommas :: String -> [String]
splitOnCommas [] = []
splitOnCommas s =
  let (piece, rest) = span (/= ',') s
  in piece : splitOnCommas (drop 1 rest)
      
-- =============================================================================================================

{-
readIR 
------
Parses the full text contents of an intermediate-code file into an
IntermediateCode object.This is the only function exported by Parser.hs.

Responsibilities:
-  Split the raw file text into lines and discard blank lines.
- Treat all lines except the last as instruction lines
 - Treat the last non-empty line as the 'live:' line
- Parse each instruction line with parseInstruction (skipping Nothing results)
 - Parse the live line with parseLiveLine, validating variables against parsed ops
 - Assemble results into an IntermediateCode value via mkIntermediateCode.

Returns:
  An IntermediateCode object containing:
    - the ordered list of parsed Operation objects.
    - the list of validated live-out variable names.

Raises:
  error (via parseLiveLine / checkVars) if:
    - the file is empty / has no non-empty lines
    - the final line is not a valid 'live:' line
    - any instruction line is malformed
    - any live-out variable is invalid or absent from the instructions
-}
readIR :: String -> IntermediateCode
readIR contents =
  let allLines = lines contents
      nonEmpty = filter (not . null) allLines
      instrLines = init nonEmpty
      liveLine = last nonEmpty
      ops = mapMaybe parseInstruction instrLines
      liveVars = parseLiveLine liveLine ops
  in mkIntermediateCode ops liveVars
