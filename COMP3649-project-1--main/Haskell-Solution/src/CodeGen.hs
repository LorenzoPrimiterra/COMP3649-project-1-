{-
  CodeGen.hs — Maps to: codegen.py

  Translates intermediate code into target assembly, given register
  assignments produced by graph colouring.

  Role in the Pipeline
  --------------------
  Final translation stage of the compiler backend:

    Parser.hs        <- reads and validates the input file
          |
    Intermediate.hs  <- stores the three-address instruction sequence
          |
    Liveness.hs      <- computes live_before and live_after sets
          |
    Interference.hs  <- builds the interference graph and assigns registers
          |
    CodeGen.hs       <- translates intermediate code into assembly language
          |
    Target.hs        <- stores and formats the generated assembly sequence
          |
    output file      <- written as <filename>.s

  Responsibilities
  ----------------
  - Translate each three-address instruction into equivalent assembly code.
  - Use register assignments to map program variables to machine registers.
  - Convert integer literals into immediate operands.
  - Load variables that are live on entry into their assigned registers.
  - Generate one or more target instructions per intermediate instruction.
  - Store modified variables that are live on exit back to memory.

  Supported Intermediate-Code Forms
  -----------------------------------
  1. Simple assignment:   dst = src
  2. Unary negation:      dst = -src
  3. Binary arithmetic:   dst = src1 op src2   (op in {+, -, *, /})

  Target Architecture Assumptions
  ---------------------------------
  Supported assembly operations:
    MOV src,Ri    MOV Ri,dst
    ADD src,Ri    SUB src,Ri
    MUL src,Ri    DIV src,Ri

  Operand modes:
    immediate (#n), absolute (variable name), register (Ri)

  High-Level Algorithm
  ---------------------
  1. Load live-on-entry variables from memory into their assigned registers.
  2. Traverse the intermediate instruction sequence in program order and
     translate each instruction into one or more assembly instructions.
  3. Store back any variables that are both live on exit and modified
     within the block.

  Out of Scope
  ------------
  - Parsing input files.
  - Computing liveness information.
  - Building the interference graph.
  - Assigning registers.
  - Register spilling.
  - Assembly optimization.

  Notes
  -----
  - Pure function: takes IntermediateCode + assignments, returns TargetCode.
  - Assumes register allocation has already succeeded.
  - Generated code is correct but not necessarily optimal.
  - Redundant instructions such as MOV R0,R0 may appear; they can be
    eliminated in a later optimization pass.
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
--   Example: reg "a" {a->0} = "R0"

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
--   Integer literal -> "#n"  (immediate mode)
--   Variable        -> "Rk"  (register mode)

asmOperand :: String -> Map String Int -> String
asmOperand tok asg
  | isIntLiteral tok = "#" ++ tok
  | isVar tok        = reg tok asg
  | otherwise        = error ("CodeGen: unexpected operand: " ++ tok)


-- ************************************************************
-- asmOperandRaw — matches _asm_operand_raw(tok) in codegen.py
-- ************************************************************
-- | Convert an IR operand into a non-register assembly operand.
--
--   Always returns the memory/immediate form — never a register name.
--   Used when reloading a value that was clobbered by a prior instruction.

asmOperandRaw :: String -> String
asmOperandRaw tok
  | isIntLiteral tok = "#" ++ tok
  | otherwise        = tok


-- ************************************************************
-- mkInstr — convenience wrapper for mkAsmInstruction
-- ************************************************************
-- | Build an AsmInstruction with both src and dst.

mkInstr :: String -> String -> String -> AsmInstruction
mkInstr op src dst = mkAsmInstruction op (Just src) (Just dst)


-- ************************************************************
-- opToAsm — matches op_to_asm(op, assignments) in codegen.py
-- ************************************************************
-- | Translate a single three-address IR instruction into assembly.
--
--   Supported forms:
--     dst = src           -> MOV src,Rdst   (omitted if same register)
--     dst = -src          -> MOV src,Rdst ; MUL #-1,Rdst
--     dst = src1 op src2  -> MOV src1,Rdst ; OP src2,Rdst
--                            (with clobber handling for src2 == dstR)

opToAsm :: Operation -> Map String Int -> [AsmInstruction]
opToAsm op asg =
  let dstR = reg (getDestination op) asg
  in

  -- Case: dst = src  (simple assignment)
  if getOperator op == Nothing && not (isUnaryNeg op) then
    let src = asmOperand (getOperand1 op) asg
    in  if src == dstR then []                          -- skip MOV Rk,Rk
        else [mkInstr "MOV" src dstR]

  -- Case: dst = -src  (unary negation)
  else if isUnaryNeg op then
    let src = asmOperand (getOperand1 op) asg
    in  (if src /= dstR then [mkInstr "MOV" src dstR] else [])
        ++ [mkInstr "MUL" "#-1" dstR]

  -- Case: dst = src1 op src2  (binary operation)
  else
    let src1  = asmOperand (getOperand1 op) asg
        src2  = case getOperand2 op of
                  Just s  -> asmOperand s asg
                  Nothing -> error "CodeGen: binary op missing operand2"
        opStr = case getOperator op of
                  Just o  -> o
                  Nothing -> error "CodeGen: binary op missing operator"
        asmOp = case opStr of
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
        -- Commutative ops: swap operands
        "+" -> [mkInstr asmOp src1 dstR]
        "*" -> [mkInstr asmOp src1 dstR]
        -- SUB: negate then add  (dst holds src2; we want src1 - src2)
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

    -- No conflict — standard two-instruction sequence
    else
      [ mkInstr "MOV" src1 dstR
      , mkInstr asmOp src2 dstR
      ]


-- ************************************************************
-- generateTarget — matches generate_target(code, assignments) in codegen.py
-- ************************************************************
-- | Generate target assembly for a single basic block.
--
--   Algorithm:
--     1) Load vars live on entry into their assigned registers.
--     2) Translate each IR operation into assembly instructions.
--     3) Store vars live on exit back to memory (only if modified).
--
--   Parameters:
--     liveBefore : live-before sets from computeLiveness
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

      -- 2) Translate each instruction; accumulate the set of written vars
      (bodyInstrs, dirty) = foldl translateOp ([], Set.empty) ops

      translateOp (instrs, d) op =
        ( instrs ++ opToAsm op asg
        , Set.insert (getDestination op) d
        )

      -- 3) Store live-on-exit variables back to memory (if modified in block)
      liveOutSet = Set.fromList liveOut
      stores     = [ mkInstr "MOV" (reg v asg) v
                   | v <- sort (Set.toList (Set.intersection liveOutSet dirty))
                   , isVar v
                   ]

  in addInstructions (loads ++ bodyInstrs ++ stores) emptyTargetCode
