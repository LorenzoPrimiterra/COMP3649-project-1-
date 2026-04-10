{-
  Test_Interference.hs
  Automated test cases for Interference.hs
  Tests interference graph building and coloring.

  Usage in GHCi:
    stack test
-}

module Test_Interference (spec) where

import Test.Hspec
import Interference
    ( buildGraph, colourGraph, addEdge, emptyGraph, getAssignments, adjacency )
import qualified Data.Set as Set
import qualified Data.Map as Map

spec :: Spec
spec = do

  -- ************************************************************
  -- emptyGraph tests
  -- ************************************************************
  describe "Testing emptyGraph" $ do

    it "Test 1: creates empty graph with no variables" $ do
      let g = emptyGraph []
      adjacency g `shouldBe` Map.empty

    it "Test 2: creates singleton graph with no edges" $ do
      let g = emptyGraph ["a"]
      adjacency g `shouldBe`
        Map.fromList [("a", Set.empty)]


  -- ************************************************************
  -- addEdge tests
  -- ************************************************************
  describe "Testing addEdge" $ do

    it "Test 3: adds undirected edge between two variables" $ do
      let g = addEdge "a" "b" (emptyGraph ["a","b"])
      adjacency g Map.! "a" `shouldBe` Set.fromList ["b"]
      adjacency g Map.! "b" `shouldBe` Set.fromList ["a"]

    it "Test 4: does not add self edges" $ do
      let g = addEdge "a" "a" (emptyGraph ["a"])
      adjacency g Map.! "a" `shouldBe` Set.empty


  -- ************************************************************
  -- buildGraph tests
  -- ************************************************************
  describe "Testing buildGraph" $ do

    it "Test 5: empty input produces empty graph" $ do
      let g = buildGraph [] []
      adjacency g `shouldBe` Map.empty

    it "Test 6: singleton live set produces no edges" $ do
      let g = buildGraph ["a"] [Set.fromList ["a"]]
      adjacency g Map.! "a" `shouldBe` Set.empty

    it "Test 7: builds complete graph from one live set" $ do
      let g = buildGraph ["a","b","c"]
                [Set.fromList ["a","b","c"]]
      adjacency g Map.! "a" `shouldBe` Set.fromList ["b","c"]
      adjacency g Map.! "b" `shouldBe` Set.fromList ["a","c"]
      adjacency g Map.! "c" `shouldBe` Set.fromList ["a","b"]

    it "Test 8: builds graph across multiple live sets" $ do
      let g = buildGraph ["a","b","c"]
                [ Set.fromList ["a","b"]
                , Set.fromList ["b","c"]
                ]
      adjacency g Map.! "a" `shouldBe` Set.fromList ["b"]
      adjacency g Map.! "b" `shouldBe` Set.fromList ["a","c"]
      adjacency g Map.! "c" `shouldBe` Set.fromList ["b"]


  -- ************************************************************
  -- colourGraph tests
  -- ************************************************************
  describe "Testing colourGraph" $ do

    it "Test 9: empty graph is trivially colourable" $ do
      let g = buildGraph [] []
      colourGraph 1 g `shouldBe` Just g

    it "Test 10: singleton graph works with one register" $ do
      let g = buildGraph ["a"] [Set.fromList ["a"]]
      case colourGraph 1 g of
        Nothing -> expectationFailure "Should succeed"
        Just g' -> Map.size (getAssignments g') `shouldBe` 1

    it "Test 11: two connected nodes need two registers" $ do
      let g = buildGraph ["a","b"] [Set.fromList ["a","b"]]
      colourGraph 2 g `shouldSatisfy` (/= Nothing)

    it "Test 12: fails when not enough registers" $ do
      let g = buildGraph ["a","b"] [Set.fromList ["a","b"]]
      colourGraph 1 g `shouldBe` Nothing

    it "Test 13: triangle graph requires 3 colours" $ do
      let g = buildGraph ["a","b","c"] [Set.fromList ["a","b","c"]]
      colourGraph 2 g `shouldBe` Nothing
      colourGraph 3 g `shouldSatisfy` (/= Nothing)

    it "Test 14: no adjacent nodes share same colour" $ do
      let g = buildGraph ["a","b","c"] [Set.fromList ["a","b","c"]]
      case colourGraph 3 g of
        Nothing -> expectationFailure "Should succeed"
        Just g' -> do
          let asg = getAssignments g'
              ns  = adjacency g'

          mapM_ (\(v, neighs) ->
              mapM_ (\n ->
                Map.lookup v asg `shouldNotBe` Map.lookup n asg
              ) (Set.toList neighs)
            ) (Map.toList ns)