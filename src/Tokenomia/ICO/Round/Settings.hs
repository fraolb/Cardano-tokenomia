{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE RecordWildCards #-}

module Tokenomia.ICO.Round.Settings (
  RoundSettings (..),
  RoundAddresses (..),
  RatePerLovelace (..),
  PreviousRound (..),
  NextRound (..),
  KYCIntegration (..),
  getCollateral,
  getFees,
  getExchangeAddress,
  getTokenAddress,
  getRoundAddresses,
  notInvalidAddress,
) where

import Prelude hiding (print, round)

import Ledger (Slot (..))
import Plutus.V1.Ledger.Ada
import Plutus.V1.Ledger.Interval
import Plutus.V1.Ledger.Value

import Data.Text.Prettyprint.Doc (pretty)
import Tokenomia.Wallet.LocalRepository

import Tokenomia.Common.Address
import Tokenomia.Wallet.ChildAddress.ChildAddressRef

newtype NextRound = NextRound
  {exchangeAddress :: Address}

instance Show NextRound where
  show NextRound {exchangeAddress = Address exchangeAddress} =
    " Exchange Address = " <> exchangeAddress

data PreviousRound = PreviousRound {investorsWallet :: Wallet, exchangeWallet :: Wallet}

instance Show PreviousRound where
  show PreviousRound {investorsWallet = Wallet {name = investors}, exchangeWallet = Wallet {name = exchange}} =
    " Wallet Investors : " <> investors <> " |  Wallet Exchange : " <> exchange

data KYCIntegration
  = Integration
      { params :: ChildAddressIndex -> String
      , url :: String
      }
  | Simulation {fakePaybackAddress :: Address}
instance Show KYCIntegration where
  show Simulation {fakePaybackAddress = Address fakePaybackAddress} = "Simulation : " <> fakePaybackAddress
  show _ = "Integrated"

data RoundSettings = RoundSettings
  { syncSlot :: Maybe Slot
  , timeRange :: Interval Slot
  , kycIntegration :: KYCIntegration
  , maximumAdaPerAddress :: Ada
  , minimumAdaPerFund :: Ada
  , investorsWallet :: Wallet
  , exchangeTokenId :: AssetClass
  , tokenRatePerLovelace :: RatePerLovelace
  , previousRoundMaybe :: Maybe PreviousRound
  , nextRoundMaybe :: Maybe NextRound
  , addresses :: RoundAddresses
  }

newtype RatePerLovelace
  = RatePerLovelace Double
  deriving newtype (Real, RealFrac, Fractional, Num, Enum, Eq, Ord, Show)

data RoundAddresses = RoundAddresses
  { exchange :: IndexedAddress
  , tokens :: IndexedAddress
  , collateral :: IndexedAddress
  , fees :: IndexedAddress
  , adaSink :: Address
  }

instance Show RoundSettings where
  show RoundSettings {investorsWallet = Wallet {name = investorsWallet}, addresses = RoundAddresses {adaSink = Address adaSink, ..}, ..} =
    "\n|| Round Settings ||"
      <> "\n | Time range  = "
      <> (show . pretty) timeRange
      <> "\n | Fund range  = "
      <> (show . pretty) (interval minimumAdaPerFund maximumAdaPerAddress)
      <> "\n | KYC Integration = "
      <> show kycIntegration
      <> "\n | Exchange Token class = "
      <> show exchangeTokenId
      <> "\n | Exchange Rate (1 lovelace = x tokens) = "
      <> show tokenRatePerLovelace
      <> "\n | Investors Wallet   = "
      <> investorsWallet
      <> "\n | Token Address      = "
      <> show tokens
      <> "\n | Exchange Address   = "
      <> show exchange
      <> "\n | Collateral Address = "
      <> show collateral
      <> "\n | Fees Address       = "
      <> show fees
      <> "\n | Ada Sink Address   = "
      <> adaSink
      <> "\n | Previous Round     = "
      <> show previousRoundMaybe
      <> "\n | Next Round         = "
      <> show nextRoundMaybe

getTokenAddress :: RoundAddresses -> Address
getTokenAddress RoundAddresses {tokens = IndexedAddress {..}} = address

notInvalidAddress :: Address -> Bool
notInvalidAddress address =
  address
    `notElem` []

getExchangeAddress :: RoundAddresses -> Address
getExchangeAddress RoundAddresses {exchange = IndexedAddress {address = exchangeAddress}} = exchangeAddress

getFees :: RoundAddresses -> FeeAddressRef
getFees RoundAddresses {fees = IndexedAddress {..}} = FeeAddressRef childAddressRef

getCollateral :: RoundAddresses -> CollateralAddressRef
getCollateral RoundAddresses {collateral = IndexedAddress {..}} = CollateralAddressRef childAddressRef

getRoundAddresses :: RoundAddresses -> [Address]
getRoundAddresses
  RoundAddresses
    { exchange = IndexedAddress {address = exchange}
    , collateral = IndexedAddress {address = collateral}
    , fees = IndexedAddress {address = fees}
    , tokens = IndexedAddress {address = tokens}
    } =
    [exchange, fees, collateral, tokens]
