{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeApplications #-}

module Tokenomia.Token.CLAPStyle.Burn (burn) where

import PlutusTx.Prelude (AdditiveGroup ((-)), AdditiveSemigroup ((+)))
import Prelude hiding (print, (+), (-))

import Control.Monad.Except
import Control.Monad.Reader hiding (ask)

import Data.List.NonEmpty
import Ledger.Ada
import Ledger.Value

import Tokenomia.Common.Environment
import Tokenomia.Common.Transacting
import Tokenomia.Script.LocalRepository
import Tokenomia.Wallet.UTxO as UTxO
import Tokenomia.Wallet.WalletUTxO

import Tokenomia.Common.Error
import Tokenomia.Common.Shell.Console (printLn)
import Tokenomia.Common.Shell.InteractiveMenu (ask)
import Tokenomia.Common.Value
import Tokenomia.Wallet.CLI
import Tokenomia.Wallet.ChildAddress.ChildAddressRef
import Tokenomia.Wallet.ChildAddress.LocalRepository
import Tokenomia.Wallet.Collateral.Read
import Tokenomia.Wallet.Type

burn ::
  ( MonadIO m
  , MonadReader Environment m
  , MonadError TokenomiaError m
  ) =>
  m ()
burn = do
  Wallet {name} <-
    fetchWalletsWithCollateral >>= whenNullThrow NoWalletWithCollateral
      >>= \wallets -> do
        printLn "Select the burner wallet : "
        askToChooseAmongGivenWallets wallets
  printLn "- Select the utxo containing the tokens to burn :"
  utxoWithTokensToBurn <- askUTxOFilterBy (containingOneToken . UTxO.value . utxo) (ChildAddressRef name 0) >>= whenNothingThrow NoUTxOWithOnlyOneToken
  amountToBurn <- ask @Integer "- Amount to burn : "
  burn' name utxoWithTokensToBurn amountToBurn

burn' ::
  ( MonadIO m
  , MonadReader Environment m
  , MonadError TokenomiaError m
  ) =>
  WalletName ->
  WalletUTxO ->
  Integer ->
  m ()
burn' walletName walletUTxO@WalletUTxO {utxo = UTxO {value = totalAmountBurnable}} amountToBurn = do
  let (tokenPolicyHash, tokenNameSelected, _) = getTokenFrom totalAmountBurnable
      valueToBurn = singleton tokenPolicyHash tokenNameSelected amountToBurn
      change = totalAmountBurnable - valueToBurn
      firstChildAddress = ChildAddressRef walletName 0

  monetaryScript <- getMonetaryPolicyPath tokenPolicyHash >>= whenNothingThrow TryingToBurnTokenWithoutScriptRegistered
  ChildAddress {address} <- fetchById firstChildAddress
  buildAndSubmit
    (Unbalanced (FeeAddressRef firstChildAddress))
    (Just $ CollateralAddressRef firstChildAddress)
    TxBuild
      { inputsFromWallet = FromWallet walletUTxO :| []
      , inputsFromScript = Nothing
      , outputs = ToWallet address (change + lovelaceValueOf 1379280) Nothing :| []
      , validitySlotRangeMaybe = Nothing
      , tokenSupplyChangesMaybe = Just $ Burn {amount = valueToBurn, script = monetaryScript} :| []
      , metadataMaybe = Nothing
      , ..
      }
