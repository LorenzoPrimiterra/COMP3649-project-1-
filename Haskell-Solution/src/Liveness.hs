{-
Name: Liveness.hs
==========================

Pipeline:
=============
Liveness.hs handles the second stage of the pipeline, computing live variable
sets for each instruction via a single backwards pass:

    (1)  Main.hs          <- validates args, reads file, sequences all stages

    (2)  Parser.hs         <- parses input into an IntermediateCode object

    (3)  Liveness.hs      <- annotates each instruction with live_before/live_after

    (4)  Interference.hs   <- builds interference graph, performs register allocation

    (5)  CodeGen.hs        <-   generates target assembly from coloured graph

    (6)  stdout /.s file <- prints interference table, colouring, and assignments

Responsibilities:
=====================
- Defines the LiveSets type alias: paired lists of live_before / live_after sets
 - Determines whether a token is a variable or a constant (isVar)
- Computes the set of variables defined (written) by an instruction (defs)
 - Computes the set of variables used (read) by an instruction (uses)
- Walks backwards over the instruction list to produce live_before and live_after
  sets for every instruction, aligned by position (computeLiveness)

Associated Dependencies:
======================
(1) Intermediate.hs  <- Operation type -- getDestination, getOperand1, getOperand2
                        for extracting instruction fields
                        
(2) Data.Set          <- Set type and set operations (singleton, union, difference,
                        empty) used throughout liveness computations

Usage Example:
================
NA

Misc Notes:
================
- Exports only pure functions — no ADT needed, just set computations
- computeLiveness reverses the instruction list and recurses through it,
  then reverses the results back to get forward order
- isVar is also imported and used by Parser.hs for operand/destination validation
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
import Data.Char (isDigit, isLower)

-- | (live_before, live_after) for each instruction, indexed by position
type LiveSets = ( [Set String], [Set String] )

-- =============================================================================================================
{-
isVar
------
Determines whether a token is a variable name in the IR, or a constant.
(Maps to: is_var(tok) in liveness.py))

Variable name rules:
  - A single lowercase letter excluding 't'   (a to z but not t)
  -- The letter 't' followed by one or more digits  (t1, t2, t10, ...)

Responsibilities:
- Acccept single-character lowercase names that are not 't'
- Accept temporary variable names of the form t<digits>
-  Reject integer literals and anything else.

Returns:
  True  if the token is a valid variable name
  False if the token is a constant (integer literal) or otherwise invalid
-}
isVar :: String -> Bool
isVar [c] = isLower c && c /= 't'
isVar ('t':rest)
  | null rest    = False
  | otherwise    = all isDigit rest
isVar _ = False


-- =============================================================================================================
{-
defs
-------
Returns the set of variables DEFINED (written) by a single instruction.
Maps to: defs(op) in liveness.py

Responsibilities:
- Extract the destination field of the Operation
- Return it as a singleton set

Returns:
  A singleton Set containing the destination variable name.
  In 3-address code every instruction has the form dst = ...,
  so the destination is always the one defined variable.
-}
defs :: Operation -> Set String
defs op = Set.singleton (getDestination op)


-- =============================================================================================================
 
{-
uses
--------
Returns the set of variables USED (read) by a single instruction.
Maps to: uses(op) in liveness.py

Responsibilities:
- Check operand1 ; include it if it is a variable (isVar), skip if a constant
-  Check operand2 (a Maybe field); include it if present and a variable
- Return the union of both operand sets

Returns:
  A Set of variable name strings appearing on the right-hand side.
  Constants (integer literals) are excluded — they have no live ranges.
  
-}
uses :: Operation -> Set String
uses op =
  let op1 = getOperand1 op
      op2 = getOperand2 op
      -- check if operand1 is a variable, if so add it
      s1 = if isVar op1 then Set.singleton op1 else Set.empty
      -- operand2 is a Maybe, so we need to unwrap it first
      s2 = case op2 of
             Just v  -> if isVar v then Set.singleton v else Set.empty
             Nothing -> Set.empty
  in Set.union s1 s2


-- =============================================================================================================
 
{-
computeLiveness
----------------
Walks backwards through the instruction list and computes live_before and
live_after sets for each instruction, returning them aligned with the
original instruction order.

(Maps to: compute_liveness(ops, live_out) in liveness.py)

The backwards recurrence at each instruction i:
    live_after[i]  = current_live
    live_before[i] = uses(op) ∪ (live_after[i] − defs(op))
    current_live   = live_before[i]

Responsibilities:
- Accept the instruction list and the initial live-out set for the block
- Reverse the instruction list and recurse through it to process bottom-to-top,
  mirroring the Python loop ( for i in range(n - 1, -1, -1))
- compute live_after and live_before using the recurrence above
- Reverse the resulting lists back to forward order
- Return as LiveSets

Returns:
  A LiveSets tuple (live_before, live_after) where:
  
     live_before[i] = Set of variables live immediately before instruction i
    live_after[i]  = Set of variables live immediately after  instruction i
  Both lists are aligned with ops by index.
-}
computeLiveness :: [Operation] -> Set String -> LiveSets
computeLiveness ops liveOut =
  -- reverse the ops so we can walk left-to-right instead of right-to-left
  -- (mirrors Python's range(n-1, -1, -1) but with recursion instead)
  let (lbRev, laRev) = walkBackwards (reverse ops) liveOut
  in  (reverse lbRev, reverse laRev)
  where
    -- process each instruction, carrying currentLive downward
    walkBackwards [] _ = ([], [])
    walkBackwards (op:rest) currentLive =
      let la_i = currentLive
          d    = defs op
          u    = uses op
          lb_i = Set.union u (Set.difference la_i d)
          (restLB, restLA) = walkBackwards rest lb_i
      in  (lb_i : restLB, la_i : restLA)