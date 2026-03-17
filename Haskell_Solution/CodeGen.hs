{-
  CodeGen.hs — Maps to: codegen.py

  Translates intermediate code into target assembly,
  given register assignments from graph colouring.

  Pure function — takes IRBlock + assignments, returns TargetCode.
-}

module CodeGen
  ( generateTarget
  ) where

import IR
import Target
import Liveness (isVar)
import Data.Map (Map)

-- TODO
