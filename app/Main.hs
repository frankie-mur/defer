module Main (main) where

import Defer.App (app, resolvePort)
import Network.Wai.Handler.Warp qualified as Warp

main :: IO ()
main = do
  port <- resolvePort
  putStrLn $ "Starting defer-web on http://localhost:" <> show port
  Warp.run port app
