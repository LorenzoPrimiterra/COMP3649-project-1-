{-
  Main.hs — Maps to: main.py

  Entry point and top-level orchestrator for the register allocator.

  Role in the Pipeline
  --------------------
  Drives the entire pipeline by invoking each stage in order:

    Command-line args    (input)
          |
      Main.hs          <- validates args, reads file, sequences all stages
          |
      Parser.hs        <- parses input into an IntermediateCode value
          |
      Liveness.hs      <- computes live_before / live_after for each instruction
          |
      Interference.hs  <- builds interference graph, performs register allocation
          |
      CodeGen.hs       <- translates IR into target assembly
          |
      Target.hs        <- formats and writes the .s output file

  Responsibilities
  ----------------
  - Validate command-line arguments (num_regs must be a positive integer).
  - Read and parse the input file.
  - Trigger liveness analysis on the parsed code.
  - Build the interference graph and attempt register allocation.
  - Print the interference table and final register assignments.
  - Generate target assembly and write it to <filename>.s.
  - Return appropriate exit codes (0 = success, 1 = allocation failed,
    2 = bad input).

  Out of Scope
  ------------
  - Parsing or validating instruction syntax (Parser.hs).
  - Liveness computation logic (Liveness.hs).
  - Interference graph construction or graph colouring (Interference.hs).
  - Defining data structures (Intermediate.hs).
  - Translating IR to assembly (CodeGen.hs).

  Exit Codes
  ----------
  - 0 : allocation succeeded, assembly written to .s file.
  - 1 : allocation failed (not enough registers).
  - 2 : bad arguments or malformed input file.

  Error Handling
  --------------
  Uses Control.Exception.try at each stage to catch exceptions gracefully:
    - File reading errors  (e.g. file not found)
    - Parse errors         (raised via error in Parser.hs)
    - Pipeline errors      (unexpected failures during liveness / codegen)
  Each caught exception produces a descriptive message on stderr and
  exits with code 2, rather than producing an unhandled stack trace.

  I/O Approach
  ------------
  Uses readFile (as recommended in the Haskell Solution Development Guidance)
  to read the entire input file as a String, which is then passed to
  Parser.readIR to produce an IntermediateCode value.
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


-- ************************************************************
-- collectVars — matches the variable-collection logic in main.py
-- ************************************************************
-- | Collect every variable that appears in the block:
--   destinations, operands, and live-out variables.
--   Filters out constants using isVar, then sorts and deduplicates.

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
-- runPipeline — full pipeline for a parsed IntermediateCode value
-- ************************************************************
-- | Run liveness analysis, build the interference graph, attempt
--   graph colouring, and (on success) generate target assembly and
--   write it to <filename>.s.
--
--   Returns True if allocation succeeded, False otherwise.

runPipeline :: Int -> IntermediateCode -> String -> IO Bool
runPipeline numRegs code filename = do

  -- 1. Compute liveness
  let ops        = getOpList code
      liveOut    = getLiveOut code
      liveOutSet = Set.fromList liveOut
      (liveBefore, liveAfter) = computeLiveness ops liveOutSet

  -- 2. Collect all variables and build the interference graph.
  --    liveSets includes live_before[0] (entry) plus all liveAfter sets,
  --    matching the Python build_interference_graph logic.
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


-- ************************************************************
-- main — matches main() in main.py
-- ************************************************************
-- | Entry point. Retrieves command-line arguments, validates them,
--   reads and parses the input file, and runs the full register
--   allocation pipeline.
--
--   Uses try (from Control.Exception) at each stage to catch
--   exceptions and report them cleanly rather than crashing.

main :: IO ()
main = do
  args <- getArgs

  -- Validate: exactly two arguments required
  case args of
    [nStr, filename] -> do

      -- Validate: first argument must be a positive integer.
      -- readMaybe gives safe parsing with no crash on non-integer input.
      case readMaybe nStr :: Maybe Int of
        Nothing -> do
          hPutStrLn stderr "Error: <num_regs> must be a positive integer"
          exitWith (ExitFailure 2)
        Just numRegs
          | numRegs <= 0 -> do
              hPutStrLn stderr "Error: <num_regs> must be a positive integer"
              exitWith (ExitFailure 2)
          | otherwise -> do

              -- Attempt to read the input file.
              -- readFile is lazy, so we force full evaluation with evaluate
              -- so that file-not-found errors are caught by try.
              readResult <- try (do contents <- readFile filename
                                    evaluate (length contents)
                                    return contents)
                            :: IO (Either SomeException String)
              case readResult of
                Left _ -> do
                  hPutStrLn stderr ("Error: file not found: " ++ filename)
                  exitWith (ExitFailure 2)

                Right contents -> do
                  -- Attempt to parse the file contents.
                  -- readIR returns IntermediateCode, but Haskell is lazy:
                  -- evaluate alone only forces the outer IC constructor (WHNF),
                  -- leaving inner lists as unevaluated thunks that may still
                  -- contain error calls. To ensure ALL parse errors are caught
                  -- here, we force full evaluation by evaluating
                  -- showIntermediateCode, which traverses every operation and
                  -- live variable.
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
                      -- any unexpected errors during liveness / codegen.
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
