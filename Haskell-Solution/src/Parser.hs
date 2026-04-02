{-
  Parser.hs — Maps to: parser.py

  Reads and validates the input file, producing an IRBlock.

  Handles:
    - Tokenizing lines (whitespace-insensitive)
    - Validating instruction formats
    - Parsing the final "live:" line
    - Raising errors on malformed input
-}

module Parser
  ( readIR
  ) where

import Intermediate


-- | Parse file contents (as a String) into an IRBlock.
--   Calls error on malformed input.
readIR :: String -> IntermediateCode
readIR _ = emptyIntermediateCode

-- TODO
