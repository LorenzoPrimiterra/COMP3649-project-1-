{-
  CodeGen.hs — Maps to: codegen.py

  Translates intermediate code into target assembly,
  given register assignments from graph colouring.

  Pure function — takes IntermediateCode + assignments, returns TargetCode.

  High-level algorithm (matches codegen.py generate_target):
    1. Load variables live on entry into their assigned registers
    2. Translate each IR operation into one or more assembly instructions
    3. Store variables live on exit (that were modified) back to memory
-}

module CodeGen
  ( generateTarget
  ) where

import Intermediate
  ( Operation, IntermediateCode
  , getDestination, getOperand1, getOperand2, getOperator, isUnaryNeg
  , getOpList, getLiveOut
  )
import Target
  ( AsmInstruction, TargetCode
  , mkAsmInstruction, emptyTargetCode, addInstructions
  )
import Liveness (isVar)
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.List (sort)
import Data.Char (isDigit)


-- helper to look up the register name for a variable
-- e.g. "a" with assignment {a->0} gives "R0"
reg :: String -> Map String Int -> String
reg var asg =
  case Map.lookup var asg of
    Nothing -> error ("CodeGen: no register assignment for variable: " ++ var)
    Just n  -> "R" ++ show n


-- check whether a token is an integer literal (possibly negative)
isIntLiteral :: String -> Bool
isIntLiteral []       = False
isIntLiteral ('-':cs) = not (null cs) && all isDigit cs
isIntLiteral cs       = all isDigit cs


-- convert an IR operand to an assembly operand
-- integer literals become immediate (#n), variables become register (Rk)
asmOperand :: String -> Map String Int -> String
asmOperand tok asg
  | isIntLiteral tok = "#" ++ tok
  | isVar tok        = reg tok asg
  | otherwise        = error ("CodeGen: unexpected operand: " ++ tok)


-- convert an IR operand to a non-register assembly operand
-- always returns memory/immediate form, used when reloading a clobbered value
asmOperandRaw :: String -> String
asmOperandRaw tok
  | isIntLiteral tok = "#" ++ tok
  | otherwise        = tok


-- shorthand for building an instruction with src and dst
makeInstr :: String -> String -> String -> AsmInstruction
makeInstr opcode src dst = mkAsmInstruction opcode (Just src) (Just dst)


-- translate a single three-address IR instruction into assembly instructions
opToAsm :: Operation -> Map String Int -> [AsmInstruction]
opToAsm op asg =
  let dstR = reg (getDestination op) asg
  in
  -- Case: dst = src (simple assignment)
  if getOperator op == Nothing && not (isUnaryNeg op) then
    let src = asmOperand (getOperand1 op) asg
    in  if src == dstR then []
        else [makeInstr "MOV" src dstR]

  -- Case: dst = -src (unary negation)
  else if isUnaryNeg op then
    let src = asmOperand (getOperand1 op) asg
    in  (if src /= dstR then [makeInstr "MOV" src dstR] else [])
        ++ [makeInstr "MUL" "#-1" dstR]

  -- Case: dst = src1 op src2 (binary operation)
  else
    let src1   = asmOperand (getOperand1 op) asg
        src2   = case getOperand2 op of
                   Just s  -> asmOperand s asg
                   Nothing -> error "CodeGen: binary op missing operand2"
        opStr  = case getOperator op of
                   Just o  -> o
                   Nothing -> error "CodeGen: binary op missing operator"
        asmOp  = case opStr of
                   "+" -> "ADD"
                   "-" -> "SUB"
                   "*" -> "MUL"
                   "/" -> "DIV"
                   _   -> error ("CodeGen: unsupported operator: " ++ opStr)
    in
    -- src1 already in dst register — skip the MOV
    if src1 == dstR then
      [makeInstr asmOp src2 dstR]

    -- src2 is in dst register — MOV would clobber it
    else if src2 == dstR then
      case opStr of
        "+" -> [makeInstr asmOp src1 dstR]
        "*" -> [makeInstr asmOp src1 dstR]
        "-" -> [ makeInstr "MUL" "#-1" dstR
               , makeInstr "ADD" src1 dstR
               ]
        "/" -> let src2Raw = case getOperand2 op of
                               Just s  -> asmOperandRaw s
                               Nothing -> error "CodeGen: missing operand2 for DIV"
               in [ makeInstr "MOV" src1 dstR
                  , makeInstr "DIV" src2Raw dstR
                  ]
        _   -> error ("CodeGen: unsupported operator: " ++ opStr)

    -- No conflict — standard sequence
    else
      [ makeInstr "MOV" src1 dstR
      , makeInstr asmOp src2 dstR
      ]


-- generate target assembly for a single basic block
--   1) load vars live on entry into their assigned registers
--   2) translate each IR operation to assembly
--   3) store vars live on exit back to memory (only if modified)
generateTarget :: [Set String] -> IntermediateCode -> Map String Int -> TargetCode
generateTarget liveBefore code asg =
  let ops     = getOpList code
      liveOut = getLiveOut code

      -- 1) load live-on-entry variables into registers
      liveIn = if null ops then Set.empty else head liveBefore
      loads  = [ makeInstr "MOV" v (reg v asg)
               | v <- sort (Set.toList liveIn)
               , isVar v
               ]

      -- 2) translate each instruction and track which vars get written
      bodyInstrs = concatMap (\op -> opToAsm op asg) ops
      dirty      = Set.fromList (map getDestination ops)

      -- 3) store live-on-exit variables back to memory if they were modified
      liveOutSet = Set.fromList liveOut
      stores = [ makeInstr "MOV" (reg v asg) v
               | v <- sort (Set.toList (Set.intersection liveOutSet dirty))
               , isVar v
               ]

  in addInstructions (loads ++ bodyInstrs ++ stores) emptyTargetCode