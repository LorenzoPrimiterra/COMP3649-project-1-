{-
  Interference.hs — Maps to: interference.py

  Builds the interference graph from liveness data
  and performs graph-colouring register allocation.

  Defines:
    - IGraph : undirected interference graph (adjacency-set representation)

  Constructor hidden.
-}

module Interference
  ( IGraph
  , buildGraph
  , allocateRegisters
  , getAssignments, getNeighbors
  , showTable, showColouring
  ) where

import IR
import Liveness (LiveSets)
import Data.Map (Map)
import Data.Set (Set)

-- TODO
