
{-
Spec.hs is the main calling function for our automated test suite.

If you wish to add a testcase, add it in the test folder under Test_{testname}.hs.

After, do a qualified import and call the filename along with spec

-}
import Test.Hspec ( hspec, describe )
import qualified Test_CodeGen
import qualified Test_Intermediate
import qualified Test_Liveness
import qualified Test_Target
import qualified Test_Interference

main :: IO ()
main = hspec $ do
  describe "Codegen Tests" $ do
    Test_CodeGen.spec
  describe "Intermediate Representation Tests" $ do
    Test_Intermediate.spec
  describe "Liveness Tests" $ do
    Test_Liveness.spec
  describe "Target Code Tests" $ do
    Test_Target.spec
  describe "Test Interference Graph & Coloring" $ do
    Test_Interference.spec