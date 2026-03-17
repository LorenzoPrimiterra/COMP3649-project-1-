{-
  Liveness.hs — Maps to: liveness.py

  Computes live_before and live_after sets for each instruction
  via a single backwards pass over the basic block.

  Exports pure functions — no ADT needed, just set computations.
-}

module Liveness
  ( LiveSets
  , computeLiveness
  , isVar
  ) where

import IR
import Data.Set (Set)

-- | (live_before, live_after) for each instruction, indexed by position
type LiveSets = ( [Set String]    -- live_before
               , [Set String] )   -- live_after

-- TODO
