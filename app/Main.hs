module Main (main) where

import Defer.App (app, resolvePort)
import Defer.Database (initDb, withDbPool)
import Network.Wai.Handler.Warp qualified as Warp
import System.Environment (lookupEnv)

-- | Application entrypoint.
--
-- Startup flow:
-- 1) resolve DB path
-- 2) create pool
-- 3) run migrations/seed
-- 4) start Warp server
main :: IO ()
main = do
  dbPath <- resolveDbPath
  withDbPool dbPath $ \pool -> do
    initDb pool
    port <- resolvePort
    putStrLn $ "Starting defer-web on http://localhost:" <> show port <> " (db: " <> dbPath <> ")"
    Warp.run port (app pool)

-- | Read SQLite file path from @DB_PATH@, defaulting to @defer.sqlite3@.
resolveDbPath :: IO FilePath
resolveDbPath = do
  maybePath <- lookupEnv "DB_PATH"
  pure $ maybe "defer.sqlite3" id maybePath
