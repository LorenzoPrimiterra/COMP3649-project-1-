{-
Name: Intermediate.hs
===============
Pipeline:
===========

Intermediate.hs defines the core IR data types shared across every stage
of the pipeline. It is a dependency of all other modules:

     (1)  Main.hs           <- validates args, reads file, sequences all stages

    (2)  Parser.hs        <- parses input into an IntermediateCode object
                             uses Operation constructors and IntermediateCode builder

     (3)  Liveness.hs     <- annotates each instruction with live_before/live_after
                             uses Operation accessors to extract defs/uses

    (4)  Interference.hs  <- builds interference graph, performs register allocation
                             uses IntermediateCode and Operation accessors

    (5)  CodeGen.hs       <- generates target assembly from coloured graphh
                             uses Operation accessors to emit correct instructions

    (6)  stdout <- prints interference table, colouring, and assignments



Responsibilities:
=====================

- Defines Operation: a single three-address IR instruction

- Provides smart constructors: mkAssign, mkUnaryNeg, mkBinOp

- Provides Operation accessors:: getDestination, getOperand1, getOperand2,
  getOperator, isUnaryNeg
  
- Provides Operation display: showOperation

- Defines IntermediateCode: an ordered list of Operations plus a live-out variable list
 
- Provides IntermediateCode constructors: mkIntermediateCode, emptyIntermediateCode, addOperation

- Provides IntermediateCode accessors: getOpList, getLiveOut

- Provides IntermediateCode display: showIntermediateCodee


Associated Dependencies:
======================
NA

Usage Example:
================
MA

Misc Notes:
================
- showIntermediateCode always ends without a trailing newline on the live: line,
  but uses unlines for the instruction block (so instructions each end with \n)
- showOperation raises error on an invalid internal Op combination —- this should
  never occur if only the exported smart constructors are used
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


-- ===================================================================================================
{-
Operation  
---------
Represents a single three-address intermediate code instruction.
Maps to: intermediate.py Operation(destination, operand1, operand2, operator, unary_neg)

Internal representation:
    Op destination operand1 (Maybe operator) (Maybe operand2) isUnaryNeg

Supported instruction forms (created via smart constructors):
    dst = src              mkAssiign   — Op dst src Nothing  Nothing  False
    dst = -src             mkUnaryNeg — Op dst src Nothing  Nothing  True
    dst = src1 op src2     mkBinOp   — Op dst src1 (Just op ) (Just src2) False

Fields:
  destination  — the variable being written (always present)
  operand 1     — the primary right-hand source (always present)
  operator    — the binary operator if applicable (Nothing for assign/unary)
  operand  2     — the secondary right-hand source (Nothing for assign/unary)
  isUnaryNeg   — True only for unary negation instructions
-}
data Operation = Op String String (Maybe String) (Maybe String) Bool
  deriving (Show)

-- ===================================================================================================
{-
mkAssign
---------
Constructs an assignment instruction: dst = src

Returns:
  An Operation representing a direct variable - to - variable or
  constant-to-variable assignment.
-}
mkAssign :: String -> String -> Operation
mkAssign dst src = Op dst src Nothing Nothing False
-- ===================================================================================================
{-
mkUnaryNeg
-----------
Constructs a unary negation instruction: dst = -src

Returns:
An Operation with isUnaryNeg = True
-}
mkUnaryNeg :: String -> String -> Operation
mkUnaryNeg dst src = Op dst src Nothing Nothing True

-- ===================================================================================================
{-
mkBinOp
--------
Constructs a binary operation instruction: dst = src1 op src2

Responsibilities:
- Accept destination, two source operands, and an operator string
- Supported operators: +  -  *  /

Returns:
  An Operation with both operator and operand2 set
-}
mkBinOp :: String -> String -> String -> String -> Operation
mkBinOp dst src1 op src2 = Op dst src1 (Just op) (Just src2) False

-- ===================================================================================================
{-

getDestination / getOperand1 / getOperand2 / getOperator / isUnaryNeg
----------------------------------------------------------------------

getDestination  — returns the destination variable String

getOperand1     — returns the primary source operand String

getOperand2     — returns the secondary source operand as Maybe String
                  
                  
getOperator     — returns the binary operator as Maybe String
                  
                  
isUnaryNeg      — returns True if this instruction is a unary negation
-}
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

-- ===================================================================================================
{-
showOperation
--------------
Formats a single Operation as a printable IR instruction string.

Returns:
  A String in standard IR notation, e.g. "t1 = a * 4"
-}
showOperation :: Operation -> String
showOperation (Op dst src1 Nothing  _        False) = dst ++ " = " ++ src1
showOperation (Op dst src1 Nothing  _        True)  = dst ++ " = -" ++ src1
showOperation (Op dst src1 (Just op) (Just src2) _) =
  dst ++ " = " ++ src1 ++ " " ++ op ++ " " ++ src2
showOperation _ = error "Invalid operation"

-- ===================================================================================================
{-
IntermediateCode  
----------------
 Represents a complete intermediate code block: an ordered list of
Operations and the set of live-out variable names for the block.
(Maps to: intermediate.py IntermediateCode(oplist, live_out))

-}
data IntermediateCode = IC [Operation] [String]
  deriving (Show)

-- ===================================================================================================
{-
mkIntermediateCode
------------------
Constructs an Intermediatecode from a completed operation list and
live-out variable list. Typically called by Parser after all lines
have been parsed.

Returns:
  An IntermediateCode containing the given ops and live-out variables.
-}
mkIntermediateCode :: [Operation] -> [String] -> IntermediateCode
mkIntermediateCode ops liveOut = IC ops liveOut

-- ===================================================================================================
{-


emptyIntermediateCode
----------------------
Creates an IntermediateCode with no instructions and no live-out variables.
Useful as a starting point when building a block incrementally via addOperation.

Returns:
  An IntermediateCode with empty op list and empty live-out list.
-}
emptyIntermediateCode :: IntermediateCode
emptyIntermediateCode = IC [] []

-- ===================================================================================================
{-
addOperation
-------------
Appends a single olperation to the end of an IntermediateCodes instruction list.
The live-out list is preserved unchanged.

Returns:
  A new IntermediateCode with the operation appended at the end.
-}
addOperation :: Operation -> IntermediateCode -> IntermediateCode
addOperation op (IC ops lv) = IC (ops ++ [op]) lv

-- ===================================================================================================
{-
getOpList / getLiveOut
-----------------------

getOpList   — returns the [Operation] list in insertion order
 getLiveOut     — returns the [String] list of live-out variable names
 
-}
getOpList :: IntermediateCode -> [Operation]
getOpList (IC ops _) = ops

getLiveOut :: IntermediateCode -> [String]
getLiveOut (IC _ lv) = lv

-- ===================================================================================================
{-
showIntermediateCode
---------------------
 Formats a complete IntermediateCode block as a printable string matching
the original input file format. Also used by Main.hs to force full lazy
evaluation of the parsed IR, ensuring all parse errors surface early..

Responsibilities:
- Map showOperation over every instruction, joining with newlines via unlines

- Append the live-out line in the form "live: a, b, c" using commaJoin

Returns:
  A multi-line String with one instruction per line followed by the
  live.
-}
showIntermediateCode :: IntermediateCode -> String
showIntermediateCode (IC ops liveOut) =
  unlines (map showOperation ops) ++
  "live: " ++ commaJoin liveOut
  where
    commaJoin []     = ""
    commaJoin [x]    = x
    commaJoin (x:xs) = x ++ ", " ++ commaJoin xs
