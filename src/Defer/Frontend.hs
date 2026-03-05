{-# LANGUAGE OverloadedStrings #-}

module Defer.Frontend
  ( homePage
  ) where

import Data.Text (Text)
import Text.Blaze.Html5 qualified as H
import Text.Blaze.Html5.Attributes qualified as A

homePage :: H.Html
homePage =
  H.docTypeHtml $ do
    H.head $ do
      H.meta H.! A.charset "utf-8"
      H.meta H.! A.name "viewport" H.! A.content "width=device-width, initial-scale=1"
      H.title "defer"
      H.style "body { font-family: system-ui, sans-serif; margin: 2rem auto; max-width: 760px; padding: 0 1rem; line-height: 1.5; } h1 { margin-bottom: 0.3rem; } .card { border: 1px solid #ddd; border-radius: 8px; padding: 1rem; margin-top: 1rem; } .muted { color: #666; }"
    H.body $ do
      H.h1 "defer"
      H.p H.! A.class_ "muted" $ "Simple Haskell frontend scaffold for articles and summaries."
      H.h2 "Articles"
      mapM_ renderArticle sampleArticles
  where
    renderArticle (titleText, summaryText) =
      H.article H.! A.class_ "card" $ do
        H.h3 (H.toHtml titleText)
        H.p (H.toHtml summaryText)

sampleArticles :: [(Text, Text)]
sampleArticles =
  [ ("Welcome to defer", "This is a placeholder summary. Next we will load real articles from an API or database.")
  , ("Why Haskell for web apps", "Strong types and pure functions help keep app logic reliable as the project grows.")
  ]
