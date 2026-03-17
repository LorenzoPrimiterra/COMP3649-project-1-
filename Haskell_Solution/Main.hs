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
-}

module Main (main) where

import System.Environment (getArgs)
import System.Exit (exitWith, ExitCode(..))
import System.IO (hPutStrLn, stderr)

import IR
import Target
import Liveness
import Interference
import CodeGen
import Parser

-- TODO
main :: IO ()
main = undefined
