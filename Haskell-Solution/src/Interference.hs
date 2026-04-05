{-
  Interference.hs — Maps to: interference.py

  Builds the interference graph from liveness data
  and performs graph-colouring register allocation.

  Uses an adjacency-set representation:
    Map String (Set String)

  Also stores register assignments:
    Map String Int
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
  ) where

import Data.Map (Map)
import qualified Data.Map as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.List ((\\), sort)


-- ************************************************************
-- Graph ADT
-- ************************************************************
-- | Represents an undirected interference graph.
--
--   nodes:
--     Map from variable -> set of interfering variables
--
--   assignments:
--     Map from variable -> assigned register number

data Graph = Graph
  { nodes       :: Map String (Set String)
  , assignments :: Map String Int
  } deriving (Show, Eq)


-- ************************************************************
-- getAssignments — matches graph.assignments in Python
-- ************************************************************
-- | Return the current register assignments.

getAssignments :: Graph -> Map String Int
getAssignments = assignments


-- ************************************************************
-- emptyGraph — matches InterferenceGraph.__init__
-- ************************************************************
-- | Create an empty interference graph with given variables.
--
--   Each variable is added as a node with no edges.

emptyGraph :: [String] -> Graph
emptyGraph vars =
  Graph (Map.fromList [(v, Set.empty) | v <- vars]) Map.empty


-- ************************************************************
-- addEdge — matches add_edge(u, v)
-- ************************************************************
-- | Add an undirected edge between v1 and v2.
--
--   Meaning:
--     v1 and v2 interfere and cannot share a register.
--
--   Self-edges are ignored.

addEdge :: String -> String -> Graph -> Graph
addEdge v1 v2 g
  | v1 == v2 = g
  | otherwise =
      let ns = nodes g
          ns' = Map.adjust (Set.insert v2) v1 $
                Map.adjust (Set.insert v1) v2 ns
      in g { nodes = ns' }


-- ************************************************************
-- buildGraph — matches build_interference_graph
-- ************************************************************
-- | Construct a graph from liveness data.
--
--   Parameters:
--     vars      = all variables in the block
--     liveAfter = list of live-after sets for each instruction
--
--   Idea:
--     Any variables that are live at the same time interfere,
--     so we add edges between all pairs in each live set.

buildGraph :: [String] -> [Set String] -> Graph
buildGraph vars = foldl addEdges (emptyGraph vars)


-- ************************************************************
-- addEdges — helper for buildGraph
-- ************************************************************
-- | Add edges between all pairs of variables in a live set.
--
--   For a set {a, b, c}, we add:
--     (a,b), (a,c), (b,c)

addEdges :: Graph -> Set String -> Graph
addEdges g liveSet =
  let vs = Set.toList liveSet
  in foldl (\acc (x,y) -> addEdge x y acc)
           g
           [(x,y) | x <- vs, y <- vs, x < y]


-- ************************************************************
-- colourGraph — matches allocate_registers
-- ************************************************************
-- | Attempt to assign registers using graph colouring.
--
--   Parameters:
--     k = number of registers available
--
--   Returns:
--     Just graph  -> successful colouring
--     Nothing     -> not enough registers

colourGraph :: Int -> Graph -> Maybe Graph
colourGraph k g =
  case colour (Map.keys (nodes g)) (assignments g) of
    Nothing  -> Nothing
    Just asg -> Just g { assignments = asg }
  where
    colours = [0..k-1]

    -- ********************************************************
    -- colour — recursive color solver
    -- ********************************************************
    -- | Assign registers to all variables.

    colour :: [String] -> Map String Int -> Maybe (Map String Int)
    colour [] asg = Just asg

    colour (v:vs) asg =
      tryColours v vs asg colours


    -- ********************************************************
    -- tryColours — try all registers for a variable
    -- ********************************************************
    -- | Attempts each register until a valid assignment is found.

    tryColours :: String -> [String] -> Map String Int -> [Int]
               -> Maybe (Map String Int)
    tryColours _ _ _ [] = Nothing
    tryColours v vs asg (c:cs)
      | safe v c asg =
          case colour vs (Map.insert v c asg) of
            Just sol -> Just sol
            Nothing  -> tryColours v vs asg cs
      | otherwise = tryColours v vs asg cs


    -- ********************************************************
    -- safe — matches is_safe(var, color)
    -- ********************************************************
    -- | Check whether assigning colour c to variable v is valid.
    --
    --   A colour is valid if no neighbor of v already has c.

    safe :: String -> Int -> Map String Int -> Bool
    safe v c asg =
      let neighbors = Set.toList (nodes g Map.! v)
      in all (\n -> Map.lookup n asg /= Just c) neighbors


-- ************************************************************
-- showInterferenceTable — matches print_table in Python
-- ************************************************************
-- | Format the interference table as:
--
--     --- Variable Interference Table ---
--     a: b, t1
--     b: a

showInterferenceTable :: Graph -> String
showInterferenceTable g =
  let vars = sort (Map.keys (nodes g))
      showRow v =
        let neighbors = sort (Set.toList (Map.findWithDefault Set.empty v (nodes g)))
        in v ++ ": " ++ commaJoin neighbors
      commaJoin []     = ""
      commaJoin [x]    = x
      commaJoin (x:xs) = x ++ ", " ++ commaJoin xs
  in "--- Variable Interference Table ---\n" ++
     unlines (map showRow vars)


-- ************************************************************
-- showColouring — matches print_register_colouring
-- ************************************************************
-- | Format assignments as:
--
--     R0: a b
--     R1: t1
--
--   Each register lists its assigned variables.

showColouring :: Graph -> Int -> String
showColouring g k =
  let asg = assignments g
      groups = Map.fromList [(r, []) | r <- [0..k-1]]
      filled =
        Map.foldrWithKey
          (\var r acc -> Map.adjust (var:) r acc) groups asg
  in unlines
       [ "R" ++ show r ++ ": " ++ unwords (Map.findWithDefault [] r filled) | r <- [0..k-1]]