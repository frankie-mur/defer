{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.ByteString.Lazy.Char8 qualified as LBS
import Data.List (isInfixOf)
import Defer.Database (initDb, withDbPool)
import Defer.App (app)
import Data.Text (Text)
import Defer.Greeting (greetingMessage)
import Network.HTTP.Types (hContentType, status200)
import Network.Wai (Application)
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
      , testCase "articles endpoint returns seeded JSON" testArticlesEndpoint
      ]

testGreeting :: IO ()
testGreeting =
  greetingMessage @?= ("Hello from defer (Haskell + WAI/Warp)!" :: Text)

testHomePage :: IO ()
testHomePage =
  withTestApp $ \testApp -> do
    response <- runSession (srequest request) testApp
    simpleStatus response @?= status200
    lookup hContentType (simpleHeaders response) @?= Just "text/html; charset=utf-8"
    assertBool "homepage includes Articles heading" ("Articles" `isInfixOf` LBS.unpack (simpleBody response))
    assertBool "homepage includes seeded article title" ("Welcome to defer" `isInfixOf` LBS.unpack (simpleBody response))
  where
    request = SRequest (setPath defaultRequest "/") ""

testHealthEndpoint :: IO ()
testHealthEndpoint =
  withTestApp $ \testApp -> do
    response <- runSession (srequest request) testApp
    simpleStatus response @?= status200
    lookup hContentType (simpleHeaders response) @?= Just "application/json; charset=utf-8"
    simpleBody response @?= "{\"status\":\"ok\"}"
  where
    request = SRequest (setPath defaultRequest "/health") ""

testArticlesEndpoint :: IO ()
testArticlesEndpoint =
  withTestApp $ \testApp -> do
    response <- runSession (srequest request) testApp
    simpleStatus response @?= status200
    lookup hContentType (simpleHeaders response) @?= Just "application/json; charset=utf-8"
    assertBool "articles endpoint contains seeded article" ("Welcome to defer" `isInfixOf` LBS.unpack (simpleBody response))
  where
    request = SRequest (setPath defaultRequest "/api/articles") ""

withTestApp :: (Application -> IO a) -> IO a
withTestApp runWithApp =
  withDbPool ":memory:" $ \pool -> do
    initDb pool
    runWithApp (app pool)
