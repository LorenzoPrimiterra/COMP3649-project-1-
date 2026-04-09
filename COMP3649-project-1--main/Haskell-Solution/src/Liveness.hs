{-
  Liveness.hs — Maps to: liveness.py

  Computes live_before and live_after sets for each instruction
  via a single backwards pass over the basic block.

  Role in the Pipeline
  --------------------
  Called from Main.hs after the block has been parsed:

    Parser.hs        <- produces the IntermediateCode value
          |
    Liveness.hs      <- walks instructions backwards, fills live_before/live_after
          |
    Main.hs          <- passes results to Interference.hs and CodeGen.hs

  Responsibilities
  ----------------
  - Determine which variables are defined (written) by each instruction.
  - Determine which variables are used (read) by each instruction.
  - Walk backwards through the instruction list to compute liveness sets.
  - Return live_before and live_after aligned with the instruction list.
  - Distinguish variables from constants so constants are never tracked.

  Out of Scope
  ------------
  - Storing liveness results (Main.hs / Intermediate.hs).
  - Parsing instructions (Parser.hs).
  - Building interference graphs or assigning registers (Interference.hs).
  - Generating assembly instructions (CodeGen.hs).

  Key Abstractions
  ----------------
  isVar(tok)
      Returns True if a token is a variable name rather than a constant.

  defs(op)
      Returns the set of variables written by an instruction.

  uses(op)
      Returns the set of variables read by an instruction.

  computeLiveness(ops, live_out)
      Walks backwards through the instruction list and returns
      live_before and live_after for each instruction.

  Notes
  -----
  - Liveness is computed in a single backwards pass (foldr) since the
    input is a single basic block with no branches or loops.
  - Constants are intentionally ignored — only variables have live ranges.
  - Exports pure functions; no ADT needed, just set computations.
-}

module Liveness
  ( LiveSets
  , computeLiveness
  , isVar
  , defs
  , uses
  ) where

import Intermediate
  ( Operation, getDestination, getOperand1, getOperand2 )
import Data.Set (Set)
import qualified Data.Set as Set


-- | (live_before, live_after) for each instruction, indexed by position.
type LiveSets = ( [Set String], [Set String] )


-- ************************************************************
-- isVar — matches is_var(tok) in liveness.py
-- ************************************************************
-- | Return True if tok is a variable name in our IR.
--
--   Variables:
--     - single lowercase letter excluding 't'  (a..z but not t)
--     - 't' followed by one or more digits      (t1, t2, t10, ...)
--
--   Constants (integer literals) return False.

isVar :: String -> Bool
isVar [c]        = c /= 't' && c `elem` ['a'..'z']
isVar ('t':rest) = not (null rest) && all (`elem` ['0'..'9']) rest
isVar _          = False


-- ************************************************************
-- defs — matches defs(op) in liveness.py
-- ************************************************************
-- | Return the set of variables DEFINED (written) by this instruction.
--
--   In three-address code every instruction has the form:
--       destination = ...
--   so destination is always a def.

defs :: Operation -> Set String
defs op = Set.singleton (getDestination op)


-- ************************************************************
-- uses — matches uses(op) in liveness.py
-- ************************************************************
-- | Return the set of variables USED (read) by this instruction.
--
--   Any variable on the right-hand side is a use.
--   Constants are ignored — they don't have live ranges.

uses :: Operation -> Set String
uses op =
  let u1 = case getOperand1 op of
              s | isVar s   -> Set.singleton s
                | otherwise -> Set.empty
      u2 = case getOperand2 op of
              Just s | isVar s -> Set.singleton s
              _                -> Set.empty
  in Set.union u1 u2


-- ************************************************************
-- computeLiveness — matches compute_liveness(ops, live_out) in liveness.py
-- ************************************************************
-- | Walk backwards through the instruction list and return
--   (live_before, live_after) aligned with ops.
--
--   live_before[i] = vars live right before ops[i]
--   live_after[i]  = vars live right after  ops[i]
--
--   Uses foldr to walk bottom -> top, accumulating
--   (current_live, [(live_before_i, live_after_i)]) pairs.
--   foldr processes right-to-left (bottom -> top), matching the Python loop:
--       for i in range(n - 1, -1, -1)
--   Building the list with (:) gives forward order automatically.

computeLiveness :: [Operation] -> Set String -> LiveSets
computeLiveness ops live_out =
  let
    step :: Operation -> (Set String, [(Set String, Set String)])
                      -> (Set String, [(Set String, Set String)])
    step op (current_live, pairs) =
      let
        live_after_i  = current_live                                        -- live_after[i]  = set(current_live)
        d             = defs op                                             -- d = defs(ops[i])
        u             = uses op                                             -- u = uses(ops[i])
        live_before_i = Set.union u (Set.difference live_after_i d)        -- live_before[i] = u | (live_after[i] - d)
        current_live' = live_before_i                                       -- current_live   = live_before[i]
      in
        (current_live', (live_before_i, live_after_i) : pairs)

    (_final_live, pairs) = foldr step (live_out, []) ops

    live_before = map fst pairs
    live_after  = map snd pairs
  in
    (live_before, live_after)
