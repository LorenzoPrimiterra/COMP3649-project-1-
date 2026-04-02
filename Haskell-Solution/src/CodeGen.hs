{-
  CodeGen.hs — Maps to: codegen.py

  Translates intermediate code into target assembly,
  given register assignments from graph colouring.

  Pure function — takes IRBlock + assignments, returns TargetCode.
-}

module CodeGen
  ( generateTarget
  ) where

import Intermediate
import Target
import Liveness (isVar)
import Data.Map (Map)

generateTarget _ = Nothing
-- TODO
