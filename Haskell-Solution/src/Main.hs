{-
  Main.hs — Maps to: main.py

  Entry point. Orchestrates the full pipeline:
    1. Validate command-line args (num_regs, filename)
    2. Read and parse input file        (Parser)
    3. Compute liveness                  (Liveness)
    4. Build interference graph          (Interference)
    5. Attempt register allocation       (Interference)
    6. Generate target assembly          (CodeGen)
    7. Print tables, write .s file       (Target)

  Exit codes: 0 = success, 1 = allocation failed, 2 = bad input

  Week 12: uses hard-coded test data instead of file parsing.
  Week 13 will add argument handling and Parser.
-}

module Main (main) where

import System.Environment (getArgs)
import System.Exit (exitWith, ExitCode(..))
import System.IO (hPutStrLn, stderr)

import Intermediate
import Target
import Liveness
import Interference
import CodeGen

import qualified Data.Set as Set
import qualified Data.Map as Map
import Data.List (nub, sort)


-- ************************************************************
-- Hard-coded test cases (same as Test_Intermediate.hs)
-- ************************************************************

-- | test.txt: a = a + 1; t1 = a * 2; b = t1 / 3; live: a, b
test1 :: IntermediateCode
test1 = mkIntermediateCode
  [ mkBinOp  "a"  "a"  "+" "1"
  , mkBinOp  "t1" "a"  "*" "2"
  , mkBinOp  "b"  "t1" "/" "3"
  ]
  ["a", "b"]

-- | test_livein.txt: r = r + s; live: r
test2 :: IntermediateCode
test2 = mkIntermediateCode
  [ mkBinOp "r" "r" "+" "s" ]
  ["r"]

-- | x = -x; live: x
test3 :: IntermediateCode
test3 = mkIntermediateCode
  [ mkUnaryNeg "x" "x" ]
  ["x"]

-- | Spec example (7-line)
test4 :: IntermediateCode
test4 = mkIntermediateCode
  [ mkBinOp  "a"  "a"  "+" "1"
  , mkBinOp  "t1" "a"  "*" "4"
  , mkBinOp  "t2" "t1" "+" "1"
  , mkBinOp  "t3" "a"  "*" "3"
  , mkBinOp  "b"  "t2" "-" "t3"
  , mkBinOp  "t4" "b"  "/" "2"
  , mkBinOp  "d"  "c"  "+" "t4"
  ]
  ["d"]


-- ************************************************************
-- collectVars — gathers all variable names from an IR block
-- ************************************************************

collectVars :: IntermediateCode -> [String]
collectVars code =
  let ops     = getOpList code
      liveOut = getLiveOut code
      allTokens = liveOut
                  ++ concatMap (\op ->
                       [getDestination op, getOperand1 op]
                       ++ maybe [] (:[]) (getOperand2 op)
                     ) ops
  in sort (nub (filter isVar allTokens))


-- ************************************************************
-- runPipeline — full pipeline on a given test case
-- ************************************************************

runPipeline :: Int -> IntermediateCode -> String -> IO ()
runPipeline numRegs code label = do

  -- Show the intermediate code
  putStrLn "Intermediate code:"
  putStr (showIntermediateCode code)
  putStrLn ""
  putStrLn ""

  -- 1. Compute liveness
  let ops        = getOpList code
      liveOut    = getLiveOut code
      liveOutSet = Set.fromList liveOut
      (liveBefore, liveAfter) = computeLiveness ops liveOutSet

  -- 2. Collect all variables, build interference graph
  let allVars  = collectVars code
      liveSets = if null ops then []
                 else head liveBefore : liveAfter
      graph    = buildGraph allVars liveSets

  -- 3. Print interference table
  putStr (showInterferenceTable graph)
  putStrLn ""

  -- 4. Attempt graph colouring
  case colourGraph numRegs graph of
    Nothing -> do
      putStrLn ("FAILED: graph is not " ++ show numRegs
                ++ "-colourable (not enough registers).")

    Just coloured -> do
      -- Print colouring table
      putStr (showColouring coloured numRegs)
      putStrLn ("SUCCESS: coloured with <= " ++ show numRegs ++ " registers")
      putStrLn ""

      -- 5. Generate target assembly
      let asg    = getAssignments coloured
          target = generateTarget liveBefore code asg

      -- Print assembly to stdout
      putStrLn "Generated assembly:"
      putStr (showTargetCode target)

      -- Write assembly to file
      let outFile = label ++ ".s"
      writeFile outFile (showTargetCode target)
      putStrLn ("Assembly written to: " ++ outFile)

      -- Print variable -> register assignments
      putStrLn ""
      putStrLn "Variable -> Register assignment:"
      mapM_ (\(var, r) -> putStrLn (var ++ ": R" ++ show r))
            (Map.toAscList asg)

  putStrLn ""


-- ************************************************************
-- main
-- ************************************************************

main :: IO ()
main = do
  args <- getArgs
  case args of
    -- no args: run all hard-coded tests
    [] -> do
      runPipeline 2 test1 "test1"
      runPipeline 2 test2 "test2"
      runPipeline 2 test3 "test3"
      runPipeline 2 test4 "test4_2regs"
      runPipeline 3 test4 "test4_3regs"

    -- one arg: num_regs, runs test1 by default
    [nStr] -> do
      let n = read nStr :: Int
      runPipeline n test1 "test1"

    _ -> do
      hPutStrLn stderr "Usage: Main [num_regs]"
      exitWith (ExitFailure 2)