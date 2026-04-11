{-
Name: Main.hs
===============

Pipeline:
===============
Main.hs drives the entire project and calls each associated stage:

    (1)  Main.hs            <- validates args, reads file, sequences all stages

    (2)  Parser.hs        <-  parses input into an IntermediateCode object

    (3)  Liveness.hs      <- annotates each instruction with live_before/live_after

    (4)  Interference.hs  <- builds interference graph, performs register allocation

    (5)  CodeGen.hs       <- generates target assembly from coloured graph

    (6)  stdout / .s file  <- prints interference table, colouring, and register
                             assignments; writes assembly to <filename>.s

Responsibilities:
=====================
-  Validates command-line arguments (num_regs must be a positive integer, filename required).
-  Reads the input file using readFile and forces full evaluation via evaluate.
- Passes file contents to Parser (readIR) to produce an IntermediateCode value.
- Triggers liveness analysis on the parsed code (computeLiveness).
-   Collects all variable names from the IR block (collectVars).
- Builds the interference graph and attempts graph coloring (register allocation)
-  On success: generates target assembly, writes it to <filename>.s, prints assignments.
- On failure: reports that allocation failed (not enough registers).
- Returns appropriate exit codes (0 = success, 1 = allocation failed, 2 = bad input).

Associated Dependencies:
======================
(1) System.Environment   <- getArgs to retrieve command-line arguments
(2)  System.Exit        <- exitWith, ExitCode for structured exit codes
(3)  System.IO         <- hPutStrLn, stderr for error reporting
(4)  Control.Exception    <- try, evaluate, SomeException for safe error handling
(5)  Text.Read           <- readMaybe for safe integer parsing (no crash on bad input)
(6)  Intermediate.hs     <- IntermediateCode type; getOpList, getLiveOut,
                             getDestination, getOperand1, getOperand2, showIntermediateCode
(7)  Target.hs            <- showTargetCode to serialise assembly output
(8)  Liveness.hs           <- computeLiveness, isVar
(9)  Interference.hs      <- buildGraph, colourGraph, getAssignments,
                             showInterferenceTable, showColouring
(10) CodeGen.hs           <- generateTarget to produce target assembly
(11) Parser.hs             <- readIR to turn raw file text into IntermediateCode
(12) Data.Set / Data.Map  <- Set for live-out sets; Map for register assignments
(13) Data.List            <- nub, sort for deduplication in collectVars

Usage Example:
================
    $ ./gen 3 my_program.txt

Misc Notes:
================
- Exit code 0: allocation succeeded, assignments printed and .s file written
- Exit code 1: allocation failed (not enough registers)
- Exit code 2: bad arguments, file not found, or malformed input file

- I/O approach: uses readFile (lazy) then forces full evaluation with evaluate
   so that file-not-found errors surface inside try rather than later
- Error handling: uses Control.Exception.try at each pipeline stage so every
  failure produces a descriptive stderr message instead of a raw stack trace
-}

module Main (main) where

import System.Environment (getArgs)
import System.Exit (exitWith, ExitCode(..))
import System.IO (hPutStrLn, stderr)
import Control.Exception (try, evaluate, SomeException)
import Text.Read (readMaybe)

import Intermediate
  ( IntermediateCode
  , getOpList, getLiveOut
  , getDestination, getOperand1, getOperand2
  , showIntermediateCode
  )
import Target (showTargetCode)
import Liveness (computeLiveness, isVar)
import Interference
  ( buildGraph, colourGraph
  , getAssignments
  , showInterferenceTable, showColouring
  )
import CodeGen (generateTarget)
import Parser (readIR)

import qualified Data.Set as Set
import qualified Data.Map as Map
import Data.List (nub, sort)


-- =============================================================================================================
{-
collectVars
------------
Gathers every variable name that appears anywhere in an IR block:
destinations, operands, and live-out variables.

Responsibilities:
- Pull all tokens from destinations, operand1, and operand2 fields of each Operation
- Include all live-out variable names from the IntermediateCode
- Filter out numeric constants using isVar
- Deduplicate and sort the result for a canonical ordering

Returns:
  A sorted, deduplicated list of variable name strings present in the block
-}
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

-- ===================================================================================================================
{-
runPipeline
--------------

Executes the full compilation pipeline for a parsed IntermediateCode value:
 liveness analysis, interference graph construction, graph colouring (register
 allocation), target assembly generation, and output.

Responsibilities:
- Compute live_before / live_after sets for every instruction via computeLiveness.
- Collect all variable names with collectVars.
- Build live sets for graph construction:
       liveSets = [live_before[0]] ++ liveAfter
       (mirrors the Python build_interference_graph logic).
- Build the interference graph with buildGraph.
- Print the interference table to stdout.
- Attempt graph colouring with colourGraph using numRegs colours.

- On failure: print the (partial) colouring table and a FAILED message; return False.
- On success: print the colouring table and a SUCCESS message; generate target
  assembly via generateTarget; write assembly to <filename>.s; print
  variable -> register assignments; return True

Returns:
  True  if graph colouring succeeded (allocation possible with numRegs registers)
  False if colouring failed (not enough registers)

Raises:
  Any exception from liveness/codegen stages propagates up to be caught
  by the try wrapper in main
-}
runPipeline :: Int -> IntermediateCode -> String -> IO Bool
runPipeline numRegs code filename = do

  -- 1. Compute liveness
  let ops        = getOpList code
      liveOut    = getLiveOut code
      liveOutSet = Set.fromList liveOut
      (liveBefore, liveAfter) = computeLiveness ops liveOutSet

  -- 2. Collect all variables, build interference graph
  --    liveSets includes live_before[0] (entry) plus all live_after sets,
  --    matching the Python build_interference_graph logic
  let allVars  = collectVars code
      liveSets = if null ops then []
                 else head liveBefore : liveAfter
      graph    = buildGraph allVars liveSets

  -- 3. Print interference table to stdout
  putStr (showInterferenceTable graph)

  -- 4. Attempt graph colouring (register allocation)
  case colourGraph numRegs graph of
    Nothing -> do
      putStr (showColouring graph numRegs)
      putStrLn ("FAILED: graph is not " ++ show numRegs
                ++ "-colourable (not enough registers).")
      return False

    Just coloured -> do
      -- Print colouring table
      putStr (showColouring coloured numRegs)
      putStrLn ("SUCCESS: coloured with <= " ++ show numRegs ++ " registers")

      -- 5. Generate target assembly
      let asg    = getAssignments coloured
          target = generateTarget liveBefore code asg

      -- Write assembly to output file (<filename>.s)
      let outFile = filename ++ ".s"
      writeFile outFile (showTargetCode target)

      -- Print variable -> register assignments
      putStrLn "Variable -> Register assignment:"
      mapM_ (\(var, r) -> putStrLn (var ++ ": R" ++ show r))
            (Map.toAscList asg)

      return True


-- =========================================================================================================================
    {-
main  
------
Entry point. Retrieves command-line arguments, validates them, reads and
parses the input file, and runs the full register allocation pipeline.

Responsibilities:
- Retrieve args with getArgs; require exactly two: <num_regs> and <filename>.
- Validate num_regs with readMaybe (safe — no crash on non-integer input).
- Read the input file with readFile; force full evaluation via evaluate so
  file-not-found errors are caught by try rather than deferred lazily
- Parse file contents with readIR; force full evaluation via
  evaluate (length (showIntermediateCode code)) to ensure ALL parse errors
  (including those hiding in unevaluated thunks) surface here rather than
  later in the pipeline
- Delegate pipeline execution to runPipeline, wrapped in try to catch
  any unexpected failures during liveness or codegen
- Map pipeline result to the appropriate exit code

Exit Codes:
  ExitSuccess   (0) — allocation succeeded; .s file written
  ExitFailure 1 (1) — allocation failed (graph not k-colourable)
  ExitFailure 2 (2) — bad arguments, file not found, or malformed input

Raises:
NA
-}
main :: IO ()
main = do
  args <- getArgs

  -- Validate: exactly two arguments required
  case args of
    [nStr, filename] -> do

      -- Validate: first argument must be a positive integer
      -- Uses readMaybe for safe parsing (no crash on non-integer input)
      case readMaybe nStr :: Maybe Int of
        Nothing -> do
          hPutStrLn stderr "Error: <num_regs> must be a positive integer"
          exitWith (ExitFailure 2)
        Just numRegs
          | numRegs <= 0 -> do
              hPutStrLn stderr "Error: <num_regs> must be a positive integer"
              exitWith (ExitFailure 2)
          | otherwise -> do

              -- Attempt to read the input file
              -- readFile is lazy, so we force full evaluation with evaluate
              -- so that file-not-found errors are caught by try
              readResult <- try (do contents <- readFile filename
                                    evaluate (length contents)
                                    return contents)
                            :: IO (Either SomeException String)
              case readResult of
                Left _ -> do
                  hPutStrLn stderr ("Error: file not found: " ++ filename)
                  exitWith (ExitFailure 2)

                Right contents -> do
                  -- Attempt to parse the file contents
                  -- readIR returns IntermediateCode, but Haskell is lazy:
                  -- evaluate alone only forces the outer IC constructor (WHNF),
                  -- leaving inner lists (operations, live vars) as unevaluated
                  -- thunks that may still contain error calls.
                  -- To ensure ALL parse errors are caught here, we force
                  -- full evaluation by evaluating showIntermediateCode,
                  -- which traverses every operation and live variable.
                  parseResult <- try (do let code = readIR contents
                                         evaluate (length (showIntermediateCode code))
                                         return code)
                                 :: IO (Either SomeException IntermediateCode)
                  case parseResult of
                    Left err -> do
                      hPutStrLn stderr ("Parse error: " ++ show err)
                      exitWith (ExitFailure 2)

                    Right code -> do
                      -- Run the full pipeline, wrapped in try to catch
                      -- any unexpected errors during liveness/codegen
                      pipeResult <- try (runPipeline numRegs code filename)
                                    :: IO (Either SomeException Bool)
                      case pipeResult of
                        Left err -> do
                          hPutStrLn stderr ("Error: " ++ show err)
                          exitWith (ExitFailure 2)
                        Right success ->
                          if success
                            then exitWith ExitSuccess
                            else exitWith (ExitFailure 1)

    _ -> do
      hPutStrLn stderr "Usage: gen <num_regs> <input_filename>"
      exitWith (ExitFailure 2)
