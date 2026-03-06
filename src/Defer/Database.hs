{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

module Defer.Database
  ( Article (..)
  , withDbPool
  , initDb
  , listArticles
  , insertImportedArticle
  ) where

import Control.Monad (when)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Logger (runStdoutLoggingT)
import Data.Aeson (ToJSON (toJSON), object, (.=))
import Data.Text (Text, pack)
import Database.Esqueleto.Experimental
  ( (^.)
  , asc
  , from
  , orderBy
  , select
  , table
  )
import Database.Persist (Entity (Entity), Filter, count, insert, insert_)
import Database.Persist.Sql (ConnectionPool, fromSqlKey, runMigration, runSqlPool)
import Database.Persist.Sqlite (createSqlitePool)
import Database.Persist.TH (mkMigrate, mkPersist, persistLowerCase, share, sqlSettings)

-- Persistent uses Template Haskell to generate schema types and migration code
-- from this quasi-quoted entity block.
share
  [mkPersist sqlSettings, mkMigrate "migrateAll"]
  [persistLowerCase|
ArticleRow
    title Text
    summary Text
    url Text Maybe
    content Text Maybe
    deriving Show Eq
|]

-- | Domain type used by handlers and JSON responses.
--
-- Newcomer tip: keep a separate domain type even when using an ORM-generated
-- row type. It prevents database details from leaking through your app.
data Article = Article
  { articleId :: Int
  , title :: Text
  , summary :: Text
  , url :: Maybe Text
  , content :: Maybe Text
  }
  deriving (Eq, Show)

instance ToJSON Article where
  toJSON article =
    object
      [ "id" .= articleId article
      , "title" .= title article
      , "summary" .= summary article
      , "url" .= url article
      , "content" .= content article
      ]

-- | Open a SQLite pool and run an action with it.
--
-- Newcomer tip: a pool is preferred over single connections in web apps,
-- because request handlers can safely share it.
withDbPool :: FilePath -> (ConnectionPool -> IO a) -> IO a
withDbPool dbPath action =
  runStdoutLoggingT $ do
    pool <- createSqlitePool (pack dbPath) 5
    liftIO (action pool)

-- | Run migrations and seed initial data when the table is empty.
initDb :: ConnectionPool -> IO ()
initDb pool =
  flip runSqlPool pool $ do
    runMigration migrateAll
    rowCount <- count ([] :: [Filter ArticleRow])
    when (rowCount == 0) $ do
      insert_ $ ArticleRow "Welcome to defer" "This is a SQLite-backed article summary placeholder." Nothing Nothing
      insert_ $ ArticleRow "Next step" "Fetch these from real sources and render them in the frontend." Nothing Nothing

-- | Fetch all articles ordered by ID (oldest first).
--
-- Newcomer tip: Esqueleto queries are fully typed, so bad column/table usage
-- is caught at compile time instead of failing only at runtime.
listArticles :: ConnectionPool -> IO [Article]
listArticles pool =
  flip runSqlPool pool $ do
    rows <- select $ do
      article <- from $ table @ArticleRow
      orderBy [asc (article ^. ArticleRowId)]
      pure article
    pure (map entityToArticle rows)
  where
    entityToArticle (Entity entityId articleRow) =
      Article
        { articleId = fromIntegral (fromSqlKey entityId)
        , title = articleRowTitle articleRow
        , summary = articleRowSummary articleRow
        , url = articleRowUrl articleRow
        , content = articleRowContent articleRow
        }

-- | Insert a parsed article imported from a URL and return the created record.
insertImportedArticle :: ConnectionPool -> Text -> Text -> Text -> Text -> IO Article
insertImportedArticle pool sourceUrl articleTitle articleSummary articleContent =
  flip runSqlPool pool $ do
    newId <- insert $ ArticleRow articleTitle articleSummary (Just sourceUrl) (Just articleContent)
    pure
      Article
        { articleId = fromIntegral (fromSqlKey newId)
        , title = articleTitle
        , summary = articleSummary
        , url = Just sourceUrl
        , content = Just articleContent
        }
