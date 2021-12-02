{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ExtendedDefaultRules #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE NamedFieldPuns #-}

module Tokenomia.Token.Transfer
    ( transfer
    , transfer'
    ) where

import           Prelude hiding ((+),(-))
import           PlutusTx.Prelude  (AdditiveSemigroup((+)),AdditiveGroup((-)))

import           Data.List.NonEmpty
import           Control.Monad.Reader hiding (ask)
import           Control.Monad.Except

import           Ledger.Value
import           Tokenomia.Common.Environment

import           Ledger.Ada
import           Tokenomia.Wallet.UTxO as UTxO
import           Tokenomia.Common.Transacting
import           Tokenomia.Wallet.LocalRepository hiding (fetchById)
import           Tokenomia.Common.Error
import           Tokenomia.Wallet.Collateral.Read
import           Tokenomia.Wallet.CLI
import           Tokenomia.Common.Shell.Console (printLn)
import           Tokenomia.Common.Shell.InteractiveMenu  (ask,askString, askStringLeaveBlankOption)
import           Tokenomia.Common.Value
import           Tokenomia.Wallet.ChildAddress.ChildAddressRef
import           Tokenomia.Wallet.Type
import           Tokenomia.Wallet.ChildAddress.LocalRepository
import           Tokenomia.Common.Address
transfer ::
    ( MonadIO m
    , MonadReader Environment m
    , MonadError TokenomiaError m )
    => m ()
transfer = do
    Wallet {name} <- fetchWalletsWithCollateral >>= whenNullThrow NoWalletWithCollateral
        >>= \wallets -> do
            printLn "Select the wallet containing the tokens: "
            askToChooseAmongGivenWallets wallets
    utxoWithToken <- askUTxOFilterBy (containingOneToken . UTxO.value . utxo) (ChildAddressRef name 0) >>= whenNothingThrow NoUTxOWithOnlyOneToken
    amount <- ask @Integer                  "- Amount of Token to transfer : "
    receiverAddr <- Address <$> askString   "- Receiver address : "
    labelMaybe <- askStringLeaveBlankOption "- Add label to your transaction (leave blank if no) : "

    transfer' name receiverAddr utxoWithToken  amount labelMaybe

type MetadataLabel = String

transfer' ::
    (  MonadIO m
    , MonadReader Environment m
    , MonadError TokenomiaError m )
    => WalletName
    -> Address
    -> WalletUTxO
    -> Integer
    -> Maybe MetadataLabel
    -> m ()
transfer' walletName receiverAddr utxoWithToken amount labelMaybe = do
    let firstChildAddress = ChildAddressRef walletName 0
    metadataMaybe <- mapM (fmap Metadata . createMetadataFile)  labelMaybe
    ChildAddress {address = senderWalletChildAddress} <- fetchById firstChildAddress
    let (tokenPolicyHash,tokenNameSelected,totalAmount) = getTokenFrom . UTxO.value  . utxo $ utxoWithToken
        tokenId = singleton tokenPolicyHash tokenNameSelected
        valueToTransfer = tokenId amount + lovelaceValueOf 1379280
        change = tokenId (totalAmount - amount) + lovelaceValueOf 1379280

    buildAndSubmit
      (CollateralAddressRef firstChildAddress)
      (FeeAddressRef firstChildAddress)
      TxBuild
        { inputsFromWallet =  FromWallet utxoWithToken :| []
        , inputsFromScript = Nothing
        , outputs = ToWallet receiverAddr valueToTransfer Nothing
                :| [ToWallet senderWalletChildAddress change Nothing]
        , validitySlotRangeMaybe = Nothing
        , tokenSupplyChangesMaybe = Nothing
        , ..}

    