{-
Name: Interference.hs
===============
Pipeline:
===========
Interference.hs handles the fourth stage of the pipeline, building the
interference graph from liveness data and performing register allocation
via graph colouring:

    (1)  Main.hs            <- validates args, reads file, sequences all stages

    (2)  Parser.hs        <- parses input into an IntermediateCode object

    (3)  Liveness.hs     <- annotates each instruction with live_before /live_after

    (4)  Interference.hs  <- builds interference graph, performs register allocation 

    (5)  CodeGen.hs        <- generates target assembly from coloured graph

    (6)  stdout  <- prints interference table, colouring, and assignments

Responsibilities:
=====================

- Defines the Graph ADT
  
- Creates an empty graph with a fixed variable set (emptyGraph)

- Adds undirected interference edges between variables (addEdge)

- Adds edges between all pairs of variables in a single live set (addEdges)

- Constructs the full interference graph from liveness data (buildGraph)

- Attempts graph colouring with k colours (colourGraph) --- returns Nothing on failure

- Exposes the register assignment map from a coloured graph (getAssignments)

- Exposes the raw adjacency map (adjacency)

- Formats the interference table for stdout (showInterferenceTable)

- Formats the register colouring table for stdout (showColouring)

Associated Dependencies:
======================
NA

Usage Example:
================
      Nothing    -> putStr (showColouring graph numRegs)   -- failed
      Just coloured -> putStr (showColouring coloured numRegs) -- success

Misc Notes:
================
- Self-edges are silently ignored in addEdge (a variable never interferes with itself)
- colourGraph uses simple recursive backtracking — it tries registers [0..k-1]

-}

module Interference
  ( Graph
  , emptyGraph
  , addEdge
  , buildGraph
  , colourGraph
  , getAssignments
  , showInterferenceTable
  , showColouring
  , adjacency
  ) where

import Data.Map (Map)
import qualified Data.Map as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.List (sort, intercalate)

-- ============================================================================================================
{-
Graph  
-----
Represents an undirected interference graph.
Maps to: InterferenceGraph in interference.py

Fields:
  nodes       — Map from variable name -> Set of interfering variable names (the adjacency-set representation of the undirected graph)
                
  assignments     — Map from variable name -> assigned register number (empty until colourGraph is called; populated on success)
-}
data Graph = Graph
  { nodes       :: Map String (Set String)
  , assignments :: Map String Int
  } deriving (Show, Eq)


-- ============================================================================================================
{-
getAssignments
---------------
Returns the current register assignment map from a Graph.

(Maps to: graph.assignments in Python.)

Returns:
  Map String Int mapping each variable to its assigned register number.
  Empty if colourGraph has not yet been called or allocation failed.
-}
getAssignments :: Graph -> Map String Int
getAssignments g = assignments g


-- ============================================================================================================
{-
emptyGraph
-----------
Creates an empty interference graph pre-populated with the given
variable names as nodes, each with an empty adjacency set.
(Maps to: InterferenceGraph.__init__ in interference.py)

Responsibilities:
- Insert every variable as a key in the nodes map
- Initialise each variable's neighbour set to empty
- Initialise the assignments map to empty

Returns:
  A Graph with one node per variable and no edges or assignments.
-}
emptyGraph :: [String] -> Graph
emptyGraph vars =
  Graph (Map.fromList [(v, Set.empty) | v <- vars]) Map.empty


-- ============================================================================================================
{-
addEdge
--------
Adds an undirected interference edge between two variables.
c(Maps to: add_edge(u, v) in interference.py)

Meaning: v1 and v2 are simultaneously live at some point, so they
interfere and cannot be assigned the same register.

Responsibilities:
- Insert v2 into v1's neighbour set
-  Insert v1 into v2's neighbour set (undirected — both directions)
- Ignore self-edges (v1 == v2) silently

Returns:
  A new Graph with the edge added (or the original Graph unchanged
  if v1 == v2).
-}
addEdge :: String -> String -> Graph -> Graph
addEdge v1 v2 (Graph ns asg)
  | v1 == v2  = Graph ns asg
  | otherwise =
      let ns' = Map.adjust (Set.insert v2) v1
              $ Map.adjust (Set.insert v1) v2 ns
      in Graph ns' asg


-- =============================================================================================================
{-
buildGraph
-----------
Constructs a full interference graph from a variable list and a list
of live-after sets, one per instruction.
(Maps to: build_interference_graph in interference.py)


Responsibilities:
- Create an empty graph for the given variable list
- Fold over the live-after sets, calling addEdges for each

Returns:
  A Graph with edges between all pairs of variables that are
  simultaneously live at any point in the block.
-}
buildGraph :: [String] -> [Set String] -> Graph
buildGraph vars liveSets = foldl addEdges (emptyGraph vars) liveSets


-- ============================================================================================================
{-
addEdges
---------
Adds interference edges between all pairs of variables within a
single live set.

For a live set {a, b, c}, adds edges: (a,b), (a,c), (b,c).

Responsibilities:
- Convert the live set to a list
- Generate all unique pairs (x < y to avoid duplicates)
- Fold addEdge over all pairs

Returns:
  A new Graph with edges added for every co-live variable pair.
-}
addEdges :: Graph -> Set String -> Graph
addEdges g liveSet =
  let vs = Set.toList liveSet
      pairs = [(x,y) | x <- vs, y <- vs, x < y]
  in foldl (\acc (x,y) -> addEdge x y acc) g pairs

-- ============================================================================================================
{-
adjacency
----------
Exposes the full adjacency map of a Graph.

Returns:
  Map String -- mapping each variable to its set of
  interfering neighbours. Useful for inspection and in Liveness
  computations that need the raw neighbour sets.
-}
adjacency :: Graph -> Map String (Set String)
adjacency g = nodes g

-- ============================================================================================================
{-
colourGraph
------------
Attempts to assign registers to all variables using graph colouring
with at most k colours (registers).
(Maps to: allocate_registers in interference.py)

 Algorithm: recursive backtracking — for each variable, try registers [0..k-1] in order; if assigning colour c to v is safe (no neighbour already has c), recurse on the remaining variables. Backtrack if no
colour works.

Responsibilities:
-  Try to colour all variables in Map.keys order
-  For each variable, attempt each register via tryColours
- Use safe to check that no already-coloured neighbour has the same register
- On complete success, return Just graph with assignments populated
-On failure, return Nothing

Returns:
  Just Graph  — colouring succeeded; graph's assignments map is populated
  Nothing     — not enough registers; colouring failed

Misc:
  Contains three internal helpers defined:
    colour      — recursive entry point over the variable list
    tryColours  —  iterates through candidate register colours for one variable
    safe        —  checks whether assigning colour c to v conflicts with neighbours
-}
colourGraph :: Int -> Graph -> Maybe Graph
colourGraph k (Graph ns asg) =
  let allVars = Map.keys ns 
  in case assignColours allVars asg of
       Nothing     -> Nothing
       Just newAsg -> Just (Graph ns newAsg)
  where
    -- try to assign a colour to every variable in the list
    regList = [0..k-1]
    assignColours [] currentAsg = Just currentAsg
    assignColours (v:vs) currentAsg = tryEachReg v vs currentAsg regList

    -- try each register for variable v, backtrack if none work
    tryEachReg _ _ _ [] = Nothing
    tryEachReg v vs currentAsg (c:cs)
      | isSafe v c currentAsg =
          case assignColours vs (Map.insert v c currentAsg) of
            Just sol -> Just sol
            Nothing  -> tryEachReg v vs currentAsg cs
      | otherwise = tryEachReg v vs currentAsg cs

    -- check that no neighbour of v already has colour c
    isSafe v c currentAsg =
      let neighbs = Set.toList (Map.findWithDefault Set.empty v ns )
      in all (\n -> Map.lookup n currentAsg /= Just c) neighbs


-- ============================================================================================================
{-
showInterferenceTable
----------------------
Formats the interference graph as a human-readable table for stdout.
(Maps to: print_table in interference.py)

Output format:
    ---- Variable Interference Table ---
     a: b, t1
    b: a

Responsibilities:
- Sort variables for a canonical display order
 - For each variable, sort and comma-join its neighbour set
- Prepend the section header

Returns:
  A formatted multi-line String ending with a trailing newline
-}
showInterferenceTable :: Graph -> String
showInterferenceTable (Graph ns _) =
  let vars = sort (Map.keys ns)
      showRow v =
        let neighbs = sort (Set.toList (Map.findWithDefault Set.empty v ns))
        in v ++ ": " ++ intercalate ", " neighbs
  in "--- Variable Interference Table ---\n" ++
     unlines (map showRow vars)


-- ============================================================================================================
{-
showColouring
--------------
Formats the register colouring as a human-readable table for stdout.

Output format:
     R0: a b
    R1: t1

Responsibilities:
 - Initialise a map of register -> [] for all k registers
-  Fold over the assignment map, appending each variable to its register's list
- Emit one line per register in order R0..R(k-1)..

Returns:
  A formatted multi-line String with one register per line,
  ending with a trailing newline (via unlines).
  Registers with no assigned variables appear as empty lines (e.g. "R2 ").
-}
showColouring :: Graph -> Int -> String
showColouring (Graph _ asg) k =
  let -- build a list of (register, [variables]) for each register
      getVarsForReg r = [v | (v, regNum) <- Map.toList asg, regNum == r]
  in unlines [ "R" ++ show r ++ ": " ++ unwords (getVarsForReg r)
             | r <- [0..k-1]
             ]