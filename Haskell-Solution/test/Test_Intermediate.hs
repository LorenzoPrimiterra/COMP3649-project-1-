
module Test_Intermediate (spec) where
import Test.Hspec
import Intermediate

spec :: Spec
spec = describe "Intermediate Code Generation" $ do

    it "Test 1: generates Three Address Instruction for a simple arithmetic chain" $ do
        let ir = mkIntermediateCode
                   [ mkBinOp  "a"  "a"  "+" "1"
                   , mkBinOp  "t1" "a"  "*" "2"
                   , mkBinOp  "b"  "t1" "/" "3"
                   ]
                   ["a", "b"]
        showIntermediateCode ir `shouldBe` "a = a + 1\nt1 = a * 2\nb = t1 / 3\nlive: a, b"

    it "Test 2: handles unary negation" $ do
        let ir = mkIntermediateCode [ mkUnaryNeg "x" "x" ] ["x"]
        showIntermediateCode ir `shouldBe` "x = -x\nlive: x"

    it "Test 3: manages complex 7-line blocks" $ do
        let ir = mkIntermediateCode
                   [ mkBinOp "a" "a" "+" "1"
                   , mkBinOp "t1" "a" "*" "4"
                   , mkBinOp "t2" "t1" "+" "1"
                   , mkBinOp "t3" "a" "*" "3"
                   , mkBinOp "b" "t2" "-" "t3"
                   , mkBinOp "t4" "b" "/" "2"
                   , mkBinOp "d" "c" "+" "t4"
                   ]
                   ["d"]
        let output = showIntermediateCode ir
        output `shouldContain` "b = t2 - t3"
        output `shouldContain` "live: d"

    it "Test 4: stores multiple live-out variables" $ do
        let ir = mkIntermediateCode
                   [ mkAssign "a" "1"
                   , mkAssign "b" "2"
                   ]
                   ["a", "b"]
        showIntermediateCode ir `shouldContain` "live: a, b"