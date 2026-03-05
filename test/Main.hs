{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.ByteString.Lazy.Char8 qualified as LBS
import Data.List (isInfixOf)
import Defer.App (app)
import Data.Text (Text)
import Defer.Greeting (greetingMessage)
import Network.HTTP.Types (hContentType, status200)
import Network.Wai.Test (SRequest (SRequest), defaultRequest, runSession, setPath, simpleBody, simpleHeaders, simpleStatus, srequest)
import Test.Tasty (defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, testCase)

main :: IO ()
main =
  defaultMain $
    testGroup
      "defer tests"
      [ testCase "greeting message is stable" testGreeting
      , testCase "homepage renders HTML" testHomePage
      , testCase "health endpoint returns JSON" testHealthEndpoint
      ]

testGreeting :: IO ()
testGreeting =
  greetingMessage @?= ("Hello from defer (Haskell + WAI/Warp)!" :: Text)

testHomePage :: IO ()
testHomePage = do
  response <- runSession (srequest request) app
  simpleStatus response @?= status200
  lookup hContentType (simpleHeaders response) @?= Just "text/html; charset=utf-8"
  assertBool "homepage includes Articles heading" ("Articles" `isInfixOf` LBS.unpack (simpleBody response))
  where
    request = SRequest (setPath defaultRequest "/") ""

testHealthEndpoint :: IO ()
testHealthEndpoint = do
  response <- runSession (srequest request) app
  simpleStatus response @?= status200
  lookup hContentType (simpleHeaders response) @?= Just "application/json; charset=utf-8"
  simpleBody response @?= "{\"status\":\"ok\"}"
  where
    request = SRequest (setPath defaultRequest "/health") ""
