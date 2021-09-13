{-# LANGUAGE OverloadedStrings #-}
module Spec(main) where

import qualified Spec.Smartchain.Contract.CLAP.MonetaryPolicy (tests)
import qualified Spec.Smartchain.Contract.Vesting (tests)
import           Test.Tasty
import           Test.Tasty.Hedgehog       (HedgehogTestLimit (..))

main :: IO ()
main = defaultMain tests

-- | Number of successful tests for each hedgehog property.
--   The default is 100 but we use a smaller number here in order to speed up
--   the test suite.
--
limit :: HedgehogTestLimit
limit = HedgehogTestLimit (Just 5)

tests :: TestTree
tests = localOption limit $ testGroup "use cases" [
    Spec.Smartchain.Contract.CLAP.MonetaryPolicy.tests,
    Spec.Smartchain.Contract.Vesting.tests
    ]