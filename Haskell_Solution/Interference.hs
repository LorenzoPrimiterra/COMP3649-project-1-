{-
  Interference.hs — Maps to: interference.py

  Builds the interference graph from liveness data
  and performs graph-colouring register allocation.

  Defines:
    - Graph : undirected interference graph (adjacency-set representation)

  Constructor hidden.
-}

module Interference
  ( Graph
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
