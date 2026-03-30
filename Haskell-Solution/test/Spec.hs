import Test.Hspec
import Interference
import qualified Data.Set as Set
{-
Spec.hs is the main calling function for our automated test suite.

TODO: Break Spec.hs up so that it just calls each of the individual
test cases we have, but also automate it.
-}
main :: IO ()
main = hspec $ do
    --test if graph can be built
  describe "Graph construction" $ do
    it "builds edges correctly" $ do
      let g = buildGraph ["a","b","c"] [Set.fromList ["a","b","c"]]
      show g `shouldSatisfy` (not . null)
-- Try to colour the graph
  describe "Graph colouring" $ do
    it "succeeds with enough registers" $ do
      let g = buildGraph ["a","b"] [Set.fromList ["a","b"]]
      colourGraph 2 g `shouldSatisfy` (/= Nothing)
--try an uncolourable graph
    it "fails with too few registers" $ do
      let g = buildGraph ["a","b"] [Set.fromList ["a","b"]]
      colourGraph 1 g `shouldBe` Nothing