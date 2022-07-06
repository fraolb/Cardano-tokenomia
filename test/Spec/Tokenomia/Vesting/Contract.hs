{-# LANGUAGE MonoLocalBinds #-}

module Spec.Tokenomia.Vesting.Contract (tests, retrieveFundsTrace, vesting) where

import Control.Monad (void)
import Data.Default (Default (def))
import Test.Tasty
import Test.Tasty.HUnit qualified as HUnit

import Ledger.Ada qualified as Ada
import Ledger.Time (POSIXTime)
import Ledger.TimeSlot qualified as TimeSlot
import Plutus.Contract.Test
import Plutus.Trace.Emulator (EmulatorTrace)
import Plutus.Trace.Emulator qualified as Trace

import PlutusTx.Numeric qualified as Numeric
import Prelude hiding (not)

import Tokenomia.Vesting.Contract

tests :: TestTree
tests =
  let con = vestingContract (vesting startTime)
   in testGroup
        "Vesting Contract"
        [ checkPredicate
            "secure some funds with the vesting script"
            (walletFundsChange w2 (Numeric.negate $ totalAmount $ vesting startTime))
            $ do
              hdl <- Trace.activateContractWallet w2 con
              Trace.callEndpoint @"vest funds" hdl ()
              void $ Trace.waitNSlots 1
        , checkPredicate
            "retrieve some funds"
            ( walletFundsChange w2 (Numeric.negate $ totalAmount $ vesting startTime)
                .&&. assertNoFailedTransactions
                .&&. walletFundsChange w1 (Ada.lovelaceValueOf 10)
            )
            retrieveFundsTrace
        , checkPredicate
            "cannot retrieve more than allowed"
            ( walletFundsChange w1 mempty
                .&&. assertContractError con (Trace.walletInstanceTag w1) (== expectedError) "error should match"
            )
            $ do
              hdl1 <- Trace.activateContractWallet w1 con
              hdl2 <- Trace.activateContractWallet w2 con
              Trace.callEndpoint @"vest funds" hdl2 ()
              Trace.waitNSlots 10
              Trace.callEndpoint @"retrieve funds" hdl1 (Ada.lovelaceValueOf 30)
              void $ Trace.waitNSlots 1
        , checkPredicate
            "can retrieve everything at the end"
            ( walletFundsChange w1 (totalAmount $ vesting startTime)
                .&&. assertNoFailedTransactions
                .&&. assertDone con (Trace.walletInstanceTag w1) (const True) "should be done"
            )
            $ do
              hdl1 <- Trace.activateContractWallet w1 con
              hdl2 <- Trace.activateContractWallet w2 con
              Trace.callEndpoint @"vest funds" hdl2 ()
              Trace.waitNSlots 20
              Trace.callEndpoint @"retrieve funds" hdl1 (totalAmount $ vesting startTime)
              void $ Trace.waitNSlots 2
        , HUnit.testCaseSteps "script size is reasonable" $ \step -> reasonable' step (vestingScript $ vesting startTime) 33000
        ]
  where
    startTime = TimeSlot.scSlotZeroTime def

{- | The scenario used in the property tests. It sets up a vesting scheme for a
   total of 60 lovelace over 20 blocks (20 lovelace can be taken out before
   that, at 10 blocks).
-}
vesting :: POSIXTime -> VestingParams
vesting startTime =
  VestingParams
    { vestingTranche1 = VestingTranche (startTime + 10000) (Ada.lovelaceValueOf 20)
    , vestingTranche2 = VestingTranche (startTime + 20000) (Ada.lovelaceValueOf 40)
    , vestingOwner = walletPubKeyHash w1
    }

retrieveFundsTrace :: EmulatorTrace ()
retrieveFundsTrace = do
  startTime <- TimeSlot.scSlotZeroTime <$> Trace.getSlotConfig
  let con = vestingContract (vesting startTime)
  hdl1 <- Trace.activateContractWallet w1 con
  hdl2 <- Trace.activateContractWallet w2 con
  Trace.callEndpoint @"vest funds" hdl2 ()
  Trace.waitNSlots 10
  Trace.callEndpoint @"retrieve funds" hdl1 (Ada.lovelaceValueOf 10)
  void $ Trace.waitNSlots 2

expectedError :: VestingError
expectedError =
  let payment = Ada.lovelaceValueOf 30
      maxPayment = Ada.lovelaceValueOf 20
      mustRemainLocked = Ada.lovelaceValueOf 40
   in InsufficientFundsError payment maxPayment mustRemainLocked
