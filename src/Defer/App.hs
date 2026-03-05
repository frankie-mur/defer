{-# LANGUAGE OverloadedStrings #-}

module Defer.App
  ( app
  , resolvePort
  ) where

import Data.Aeson (encode, object, (.=))
import Data.Text (Text)
import Defer.Database (listArticles)
import Defer.Frontend (homePage)
import Database.Persist.Sql (ConnectionPool)
import Network.HTTP.Types (status200, status404)
import Network.Wai (Application, pathInfo, responseLBS)
import System.Environment (lookupEnv)
import Text.Blaze.Html.Renderer.Utf8 (renderHtml)
import Text.Read (readMaybe)

-- | Main WAI application.
--
-- Newcomer tip: `Application` is just a function from request + callback to IO.
-- Pattern matching on `pathInfo` is a simple way to start before adding a router.
app :: ConnectionPool -> Application
app conn req respond = do
  articles <- listArticles conn
  let rootBody = renderHtml (homePage articles)
      healthBody = encode $ object ["status" .= ("ok" :: Text)]
      articlesBody = encode articles
  case pathInfo req of
    [] -> respond $ responseLBS status200 [("Content-Type", "text/html; charset=utf-8")] rootBody
    ["health"] -> respond $ responseLBS status200 [("Content-Type", "application/json; charset=utf-8")] healthBody
    ["api", "articles"] -> respond $ responseLBS status200 [("Content-Type", "application/json; charset=utf-8")] articlesBody
    _ -> respond $ responseLBS status404 [("Content-Type", "text/plain; charset=utf-8")] "Not Found\n"

-- | Read the HTTP port from @PORT@ and fall back to @3000@.
--
-- Newcomer tip: `Maybe` lets us model “might be missing” without null values.
resolvePort :: IO Int
resolvePort = do
  maybePort <- lookupEnv "PORT"
  pure $ maybe 3000 id (maybePort >>= readMaybe)
