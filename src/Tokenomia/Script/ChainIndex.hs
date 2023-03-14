{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE ExtendedDefaultRules #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE TupleSections #-}
{-# OPTIONS_GHC -fno-warn-missing-signatures #-}
{-# OPTIONS_GHC -fno-warn-unused-top-binds #-}
{-# LANGUAGE RecordWildCards #-}


{-# OPTIONS_GHC -Wno-orphans #-}
{-# OPTIONS_GHC -fno-warn-missing-signatures #-}
{-# OPTIONS_GHC -fno-warn-unused-top-binds #-}

module Tokenomia.Script.ChainIndex
    ( queryUTxO
    ) where


import qualified Data.Text.Lazy as TL
import           Data.Text.Lazy.Encoding as TLE ( decodeUtf8 )

import           Control.Monad.Reader ( MonadReader, MonadIO(..), asks )
import Shh.Internal
    ( capture, load, (|>), ExecReference(SearchPath) )


import Tokenomia.Common.Serialise ( FromCLI(fromCLI) )
import Tokenomia.Common.Environment ( Environment(magicNumber) )
import           Tokenomia.Common.Value ()
import Tokenomia.Script.UTxO ( ScriptUTxO )
import Tokenomia.Common.Address ( Address(..) )


load SearchPath ["cardano-cli"]

queryUTxO ::
  ( MonadIO m
  , MonadReader Environment m )
  => Address
  -> m [ScriptUTxO]
queryUTxO (Address address) = do
    magicN <- asks magicNumber
    fromCLI . TL.toStrict . TLE.decodeUtf8 <$> liftIO (cardano_cli "query" "utxo" "--testnet-magic" magicN "--address" address |> capture)
