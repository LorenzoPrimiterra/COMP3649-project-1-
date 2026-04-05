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


-- ************************************************************
-- reg — matches _reg(var, assignments) in codegen.py
-- ************************************************************
-- | Return the register name assigned to a variable.
--
--   e.g. reg "a" {a->0} = "R0"

reg :: String -> Map String Int -> String
reg var asg =
  case Map.lookup var asg of
    Nothing -> error ("CodeGen: no register assignment for variable: " ++ var)
    Just n  -> "R" ++ show n


-- ************************************************************
-- isIntLiteral — matches _is_int_literal(tok) in codegen.py
-- ************************************************************
-- | Check whether a token is an integer literal.

isIntLiteral :: String -> Bool
isIntLiteral []       = False
isIntLiteral ('-':cs) = not (null cs) && all isDigit cs
isIntLiteral cs       = all isDigit cs


-- ************************************************************
-- asmOperand — matches _asm_operand(tok, assignments) in codegen.py
-- ************************************************************
-- | Convert an IR operand into an assembly operand.
--
--   Integer literal -> "#n"   (immediate)
--   Variable        -> "Rk"   (register)

asmOperand :: String -> Map String Int -> String
asmOperand tok asg
  | isIntLiteral tok = "#" ++ tok
  | isVar tok        = reg tok asg
  | otherwise        = error ("CodeGen: unexpected operand: " ++ tok)


-- ************************************************************
-- asmOperandRaw — matches _asm_operand_raw(tok) in codegen.py
-- ************************************************************
-- | Convert an IR operand into a non-register assembly operand.
--   Always returns memory/immediate form (never a register).
--   Used when reloading a value that was clobbered.

asmOperandRaw :: String -> String
asmOperandRaw tok
  | isIntLiteral tok = "#" ++ tok
  | otherwise        = tok


-- ************************************************************
-- Helper: build an AsmInstruction with src and dst
-- ************************************************************

mkInstr :: String -> String -> String -> AsmInstruction
mkInstr op src dst = mkAsmInstruction op (Just src) (Just dst)


-- ************************************************************
-- opToAsm — matches op_to_asm(op, assignments) in codegen.py
-- ************************************************************
-- | Translate a single three-address IR instruction into assembly.
--
--   Supported forms:
--     dst = src           -> MOV src,Rdst  (skip if same register)
--     dst = -src          -> MOV src,Rdst; MUL #-1,Rdst
--     dst = src1 op src2  -> MOV src1,Rdst; OP src2,Rdst
--                            (with clobber handling)

opToAsm :: Operation -> Map String Int -> [AsmInstruction]
opToAsm op asg =
  let dstR = reg (getDestination op) asg
  in
  -- Case: dst = src (simple assignment)
  if getOperator op == Nothing && not (isUnaryNeg op) then
    let src = asmOperand (getOperand1 op) asg
    in  if src == dstR then []                      -- skip MOV Rk,Rk
        else [mkInstr "MOV" src dstR]

  -- Case: dst = -src (unary negation)
  else if isUnaryNeg op then
    let src = asmOperand (getOperand1 op) asg
    in  (if src /= dstR then [mkInstr "MOV" src dstR] else [])
        ++ [mkInstr "MUL" "#-1" dstR]

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
      [mkInstr asmOp src2 dstR]

    -- src2 is in dst register — MOV would clobber it
    else if src2 == dstR then
      case opStr of
        -- Commutative: swap operands
        "+" -> [mkInstr asmOp src1 dstR]
        "*" -> [mkInstr asmOp src1 dstR]
        -- SUB: negate then add (dst has src2, we want src1 - src2)
        "-" -> [ mkInstr "MUL" "#-1" dstR
               , mkInstr "ADD" src1 dstR
               ]
        -- DIV: reload src2 from memory/immediate after overwriting
        "/" -> let src2Raw = case getOperand2 op of
                               Just s  -> asmOperandRaw s
                               Nothing -> error "CodeGen: missing operand2 for DIV"
               in [ mkInstr "MOV" src1 dstR
                  , mkInstr "DIV" src2Raw dstR
                  ]
        _   -> error ("CodeGen: unsupported operator: " ++ opStr)

    -- No conflict — standard sequence
    else
      [ mkInstr "MOV" src1 dstR
      , mkInstr asmOp src2 dstR
      ]


-- ************************************************************
-- generateTarget — matches generate_target(code, assignments)
-- ************************************************************
-- | Generate target assembly for a single basic block.
--
--   1) Load vars live on entry into their assigned registers
--   2) Translate each IR operation to assembly
--   3) Store vars live on exit back to memory (only if modified)
--
--   Parameters:
--     liveBefore : list of live-before sets (from computeLiveness)
--     code       : the IntermediateCode block
--     asg        : variable-to-register assignments from graph colouring

generateTarget :: [Set String] -> IntermediateCode -> Map String Int -> TargetCode
generateTarget liveBefore code asg =
  let ops     = getOpList code
      liveOut = getLiveOut code

      -- 1) Load live-on-entry variables into registers
      liveIn = if null ops then Set.empty else head liveBefore
      loads  = [ mkInstr "MOV" v (reg v asg)
               | v <- sort (Set.toList liveIn)
               , isVar v
               ]

      -- 2) Translate each instruction
      --    Also track which variables are written (dirty)
      (bodyInstrs, dirty) = foldl translateOp ([], Set.empty) ops

      translateOp (instrs, d) op =
        ( instrs ++ opToAsm op asg
        , Set.insert (getDestination op) d
        )

      -- 3) Store live-on-exit variables back to memory
      --    Only if they were modified in the block
      liveOutSet = Set.fromList liveOut
      stores = [ mkInstr "MOV" (reg v asg) v
               | v <- sort (Set.toList (Set.intersection liveOutSet dirty))
               , isVar v
               ]

  in addInstructions (loads ++ bodyInstrs ++ stores) emptyTargetCode