{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Data.Aeson (encode, object, (.=))
import Data.ByteString.Lazy.Char8 qualified as LBS
import Data.List (isInfixOf)
import Data.Text qualified as T
import Defer.ArticleImport (parseArticleHtml, parsedContent, parsedTitle)
import Defer.Database (initDb, withDbPool)
import Defer.App (app)
import Data.Text (Text)
import Defer.Greeting (greetingMessage)
import Network.HTTP.Types (hContentType, methodPost, status200, status400, status422)
import Network.Wai (Application, requestHeaders, requestMethod)
import Network.Wai.Test (SRequest (SRequest), defaultRequest, runSession, setPath, simpleBody, simpleHeaders, simpleStatus, srequest)
import Test.Tasty (defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, testCase)

main :: IO ()
main =
  defaultMain $
    testGroup
      "defer tests"
      [ testCase "greeting message is stable" testGreeting
      , testCase "article parser extracts title and content" testArticleParser
      , testCase "homepage renders HTML" testHomePage
      , testCase "health endpoint returns JSON" testHealthEndpoint
      , testCase "articles endpoint returns seeded JSON" testArticlesEndpoint
      , testCase "POST /api/articles rejects invalid JSON" testCreateArticleInvalidJson
      , testCase "POST /api/articles rejects invalid URL" testCreateArticleInvalidUrl
      ]

testGreeting :: IO ()
testGreeting =
  greetingMessage @?= ("Hello from defer (Haskell + WAI/Warp)!" :: Text)

testArticleParser :: IO ()
testArticleParser = do
  let parsed = parseArticleHtml "<html><head><title>Example Article</title></head><body><p>First paragraph.</p><p>Second paragraph.</p></body></html>"
  parsedTitle parsed @?= "Example Article"
  assertBool "parser includes first paragraph" ("First paragraph." `T.isInfixOf` parsedContent parsed)

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

testCreateArticleInvalidJson :: IO ()
testCreateArticleInvalidJson =
  withTestApp $ \testApp -> do
    response <- runSession (srequest requestPayload) testApp
    simpleStatus response @?= status400
  where
    requestPayload =
      SRequest
        ( setPath
            ( defaultRequest
                { requestMethod = methodPost
                , requestHeaders = [(hContentType, "application/json")]
                }
            )
            "/api/articles"
        )
        "not-json"

testCreateArticleInvalidUrl :: IO ()
testCreateArticleInvalidUrl =
  withTestApp $ \testApp -> do
    response <- runSession (srequest requestPayload) testApp
    simpleStatus response @?= status422
  where
    requestPayload =
      SRequest
        ( setPath
            ( defaultRequest
                { requestMethod = methodPost
                , requestHeaders = [(hContentType, "application/json")]
                }
            )
            "/api/articles"
        )
        payload
    payload = encode $ object ["url" .= ("not-a-valid-url" :: Text)]

withTestApp :: (Application -> IO a) -> IO a
withTestApp runWithApp =
  withDbPool ":memory:" $ \pool -> do
    initDb pool
    runWithApp (app pool)
