{-# LANGUAGE OverloadedStrings #-}

module Defer.App
  ( app
  , resolvePort
  ) where

import Data.Aeson (encode, object, (.=))
import Data.Text (Text)
import Defer.Frontend (homePage)
import Network.HTTP.Types (status200, status404)
import Network.Wai (Application, pathInfo, responseLBS)
import System.Environment (lookupEnv)
import Text.Blaze.Html.Renderer.Utf8 (renderHtml)
import Text.Read (readMaybe)

app :: Application
app req respond =
  case pathInfo req of
    [] -> respond $ responseLBS status200 [("Content-Type", "text/html; charset=utf-8")] rootBody
    ["health"] -> respond $ responseLBS status200 [("Content-Type", "application/json; charset=utf-8")] healthBody
    _ -> respond $ responseLBS status404 [("Content-Type", "text/plain; charset=utf-8")] "Not Found\n"
  where
    rootBody = renderHtml homePage
    healthBody = encode $ object ["status" .= ("ok" :: Text)]

resolvePort :: IO Int
resolvePort = do
  maybePort <- lookupEnv "PORT"
  pure $ maybe 3000 id (maybePort >>= readMaybe)
