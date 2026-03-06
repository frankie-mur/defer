{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Defer.App
  ( app
  , resolvePort
  ) where

import Data.Aeson (FromJSON (..), eitherDecode, encode, object, withObject, (.:), (.=))
import Data.Text (Text)
import Defer.ArticleImport (ParsedArticle (..), fetchAndParseArticle)
import Defer.Database (insertImportedArticle, listArticles)
import Defer.Frontend (homePage)
import Database.Persist.Sql (ConnectionPool)
import GHC.Generics (Generic)
import Network.HTTP.Types (methodGet, methodPost, status200, status201, status400, status404, status422)
import Network.Wai (Application, pathInfo, requestMethod, responseLBS, strictRequestBody)
import System.Environment (lookupEnv)
import Text.Blaze.Html.Renderer.Utf8 (renderHtml)
import Text.Read (readMaybe)

-- | Request body for importing a new article from a URL.
--
-- Example JSON:
-- { "url": "https://example.com/some-article" }
data AddArticleRequest = AddArticleRequest
  { url :: Text
  }
  deriving (Eq, Show, Generic)

instance FromJSON AddArticleRequest where
  parseJSON = withObject "AddArticleRequest" $ \obj ->
    AddArticleRequest <$> obj .: "url"

-- | Main WAI application.
--
-- Newcomer tip: `Application` is just a function from request + callback to IO.
-- Pattern matching on `pathInfo` is a simple way to start before adding a router.
app :: ConnectionPool -> Application
app conn req respond = do
  case pathInfo req of
    -- HTML homepage
    [] | requestMethod req == methodGet -> do
      articles <- listArticles conn
      respond $ responseLBS status200 [("Content-Type", "text/html; charset=utf-8")] (renderHtml (homePage articles))
    -- Lightweight health probe for local checks/deploys
    ["health"] | requestMethod req == methodGet ->
      respond $ responseLBS status200 [("Content-Type", "application/json; charset=utf-8")] (encode $ object ["status" .= ("ok" :: Text)])
    -- List all stored articles as JSON
    ["api", "articles"] | requestMethod req == methodGet -> do
      articles <- listArticles conn
      respond $ responseLBS status200 [("Content-Type", "application/json; charset=utf-8")] (encode articles)
    -- Import an article by URL and persist parsed content
    ["api", "articles"] | requestMethod req == methodPost -> do
      requestBody <- strictRequestBody req
      -- Step 1: decode incoming JSON payload
      case eitherDecode requestBody of
        Left _ ->
          respond $ responseLBS status400 [("Content-Type", "application/json; charset=utf-8")] (encode $ object ["error" .= ("Invalid JSON payload" :: Text)])
        Right (AddArticleRequest sourceUrl) -> do
          -- Step 2: fetch + parse remote page data
          parsed <- fetchAndParseArticle sourceUrl
          case parsed of
            Left parseError ->
              -- 422: request format is valid, but the referenced content could
              -- not be processed into a usable article
              respond $ responseLBS status422 [("Content-Type", "application/json; charset=utf-8")] (encode $ object ["error" .= parseError])
            Right parsedArticle -> do
              -- Step 3: persist normalized article fields in SQLite
              created <-
                insertImportedArticle
                  conn
                  sourceUrl
                  (parsedTitle parsedArticle)
                  (parsedSummary parsedArticle)
                  (parsedContent parsedArticle)
              -- Return the created article JSON immediately for frontend use
              respond $ responseLBS status201 [("Content-Type", "application/json; charset=utf-8")] (encode created)
    _ -> respond $ responseLBS status404 [("Content-Type", "text/plain; charset=utf-8")] "Not Found\n"

-- | Read the HTTP port from @PORT@ and fall back to @3000@.
--
-- Newcomer tip: `Maybe` lets us model “might be missing” without null values.
resolvePort :: IO Int
resolvePort = do
  maybePort <- lookupEnv "PORT"
  pure $ maybe 3000 id (maybePort >>= readMaybe)
