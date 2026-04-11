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
- computeLiveness uses foldr to walk bottom-to-top (right-to-left), mirroring
  the Python loop: for i in range(n - 1, -1, -1)
- foldr with (:) accumulation naturally produces results in forward order
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

-- | (live_before, live_after) for each instruction, indexed by position
type LiveSets = ( [Set String], [Set String] )   -- live_before & live_after

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
isVar [c]        = c /= 't' && c `elem` ['a'..'z']       -- single lowercase letter, not 't'
isVar ('t':rest) = not (null rest) && all (`elem` ['0'..'9']) rest  -- t followed by digits
isVar _          = False


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
  let u1 = case getOperand1 op of
              s | isVar s   -> Set.singleton s
                | otherwise -> Set.empty
      u2 = case getOperand2 op of
              Just s | isVar s   -> Set.singleton s
              _                  -> Set.empty
  in Set.union u1 u2


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
- Use foldr to process instructions right-to-left (bottom -> top), mirroring
  the Python loop ( for i in range(n - 1, -1, -1))
- compute live_after and live_before using the recurrence above
- Accumulate (live_before_i, live_after_i) pairs with (:) so the result
  comes out in forward order
- Split the pair list into two parallel lists and return as LiveSets

Returns:
  A LiveSets tuple (live_before, live_after) where:
  
     live_before[i] = Set of variables live immediately before instruction i
    live_after[i]  = Set of variables live immediately after  instruction i
  Both lists are aligned with ops by index.
-}
computeLiveness :: [Operation] -> Set String -> LiveSets
computeLiveness ops live_out =
  let
    -- foldr processes right-to-left (bottom -> top), matching the Python loop:
    --   for i in range(n - 1, -1, -1):
    --
    -- accumulator: (current_live, list of (live_before_i, live_after_i) pairs)
    -- We build the list with (:) so it comes out in forward order automatically.

    step :: Operation -> (Set String, [(Set String, Set String)])
                      -> (Set String, [(Set String, Set String)])
    step op (current_live, pairs) =
      let
        live_after_i  = current_live                              -- live_after[i] = set(current_live)

        d             = defs op                                   -- d = defs(ops[i])
        u             = uses op                                   -- u = uses(ops[i])

        live_before_i = Set.union u (Set.difference live_after_i d)  -- live_before[i] = u | (live_after[i] - d)

        current_live' = live_before_i                             -- current_live = live_before[i]
      in
        (current_live', (live_before_i, live_after_i) : pairs)

    (_final_live, pairs) = foldr step (live_out, []) ops

    live_before = map fst pairs
    live_after  = map snd pairs
  in
    (live_before, live_after)
