{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE RecordWildCards #-}

module Tokenomia.ICO.Funds.Validation.CardanoCLI.Plan (
  mkPlan,
  mkPlan',
  Plan (..),
  State (..),
  getTxBalance,
) where

import Prelude hiding (print, round)

import Tokenomia.ICO.Funds.Validation.CardanoCLI.Command
import Tokenomia.ICO.Round.Settings

import Data.List.NonEmpty as NEL
import Data.Set.NonEmpty qualified as NES
import Data.Set.Ordered as OS
import Tokenomia.Common.Transacting
import Tokenomia.ICO.Balanceable

mkPlan ::
  Maybe Fees ->
  NES.NESet Command ->
  Plan Command
mkPlan a b = snd $ mkPlan' a b

mkPlan' ::
  Maybe Fees ->
  NES.NESet Command ->
  (State, Plan Command)
mkPlan' Nothing commands =
  ( State
      { commands = empty
      , quotientFeesPerFund = 0
      , remainderFeesPerFund = 0
      , totalCommands = NES.size commands
      }
  , Plan {feesMaybe = Nothing, ..}
  )
mkPlan' (Just fees) commandsNotBlancedWithFees =
  let (quotientFeesPerFund, remainderFeesPerFund) = getQuotRem fees commandsNotBlancedWithFees
      s@State {commands} =
        foldr
          transition
          State
            { commands = empty
            , quotientFeesPerFund = quotientFeesPerFund
            , remainderFeesPerFund = remainderFeesPerFund
            , totalCommands = NES.size commandsNotBlancedWithFees
            }
          (NES.toDescList commandsNotBlancedWithFees)
   in ( s
      , Plan
          { feesMaybe = Just fees
          , commands = (NES.fromList . NEL.fromList . OS.toAscList) commands
          }
      )

data State = State
  { quotientFeesPerFund :: !Fees
  , remainderFeesPerFund :: !Fees
  , totalCommands :: !Int
  , commands :: !(OS.OSet Command)
  }
  deriving stock (Show)

transition :: Command -> State -> State
transition c State {..} =
  case c of
    SendOnExchangeAddressAndPartiallyRefund {..} -> appendCommand SendOnExchangeAddressAndPartiallyRefund {adasToRefund = adasToRefund - feesPerCommand, ..}
    SendOnExchangeAddressAndPartiallyMoveToNextRound {..} -> appendCommand SendOnExchangeAddressAndPartiallyMoveToNextRound {adasToMove = adasToMove - feesPerCommand, ..}
    Refund {..} -> appendCommand Refund {adasToRefund = adasToRefund - feesPerCommand, ..}
    MoveToNextRound {..} -> appendCommand MoveToNextRound {adasToMove = adasToMove - feesPerCommand, ..}
    SendOnExchangeAddress {..} -> appendCommand SendOnExchangeAddress {adasToSendOnExchange = adasToSendOnExchange - feesPerCommand, ..}
  where
    appendCommand command = State {commands = commands |> command, ..}
    feesPerCommand = quotientFeesPerFund + addRemainderFeesPerFundIfLastCommand
    addRemainderFeesPerFundIfLastCommand = if totalCommands == size commands + 1 then remainderFeesPerFund else 0

getQuotRem ::
  Fees ->
  NES.NESet Command ->
  (Fees, Fees)
getQuotRem totalFees xs = totalFees `quotRem` (fromIntegral . NES.size) xs

data Plan command = Plan
  { feesMaybe :: Maybe Fees
  , commands :: NES.NESet command
  }

instance AdaBalanceable (Plan Command) where
  adaBalance Plan {..} = adaBalance commands - adaBalance feesMaybe

instance (Show command) => Show (Plan command) where
  show Plan {..} =
    "\n|| PLAN || "
      <> "\n| Fees = "
      <> show feesMaybe
      <> "\n| Commands = "
      <> show commands

getTxBalance :: RoundAddresses -> Plan a -> TxBalance
getTxBalance _ Plan {feesMaybe = Just fees} = Balanced fees
getTxBalance roundAddresses Plan {feesMaybe = Nothing} = Unbalanced $ getFees roundAddresses
