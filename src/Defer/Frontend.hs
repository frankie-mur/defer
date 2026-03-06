{-# LANGUAGE OverloadedStrings #-}

module Defer.Frontend
  ( homePage
  ) where

import Data.Text (Text)
import Data.Text qualified as T
import Defer.Database (Article (..))
import Text.Blaze.Html5 qualified as H
import Text.Blaze.Html5.Attributes qualified as A

-- | Render the homepage HTML from the current list of articles.
--
-- Newcomer tip: keeping this function pure (`[Article] -> Html`) makes it
-- straightforward to test and reuse, because there is no IO here.
homePage :: [Article] -> H.Html
homePage articles =
  H.docTypeHtml $ do
    H.head $ do
      H.meta H.! A.charset "utf-8"
      H.meta H.! A.name "viewport" H.! A.content "width=device-width, initial-scale=1"
      H.title "defer"
      H.style "body { font-family: system-ui, sans-serif; margin: 2rem auto; max-width: 760px; padding: 0 1rem; line-height: 1.5; } h1 { margin-bottom: 0.3rem; } .card { border: 1px solid #ddd; border-radius: 8px; padding: 1rem; margin-top: 1rem; } .muted { color: #666; } .form-row { display: flex; gap: 0.5rem; margin-top: 0.75rem; } .url-input { flex: 1; padding: 0.5rem; } .btn { padding: 0.5rem 0.75rem; cursor: pointer; } .status { margin-top: 0.5rem; }"
    H.body $ do
      H.h1 "defer"
      H.p H.! A.class_ "muted" $ "Simple Haskell frontend scaffold for articles and summaries from SQLite."
      H.h2 "Import article"
      H.p H.! A.class_ "muted" $ "Paste a URL to fetch, parse, and store title/content/summary."
      H.form H.! A.id "import-form" $ do
        H.div H.! A.class_ "form-row" $ do
          H.input H.! A.id "article-url" H.! A.class_ "url-input" H.! A.type_ "url" H.! A.required "required" H.! A.placeholder "https://example.com/article"
          H.button H.! A.id "import-button" H.! A.class_ "btn" H.! A.type_ "submit" $ "Add article"
        H.p H.! A.id "import-status" H.! A.class_ "status muted" $ ""
      H.h2 "Articles"
      mapM_ renderArticle articles
      H.script $ H.preEscapedToHtml scriptContent
  where
    renderArticle article =
      H.article H.! A.class_ "card" $ do
        H.h3 (H.toHtml (title article))
        H.p (H.toHtml (summary article))

scriptContent :: Text
scriptContent =
  T.unlines
    [ "(() => {"
    , "const form = document.getElementById('import-form');"
    , "const input = document.getElementById('article-url');"
    , "const button = document.getElementById('import-button');"
    , "const status = document.getElementById('import-status');"
    , "if (!form || !input || !button || !status) return;"
    , "form.addEventListener('submit', async (event) => {"
    , "event.preventDefault();"
    , "status.textContent = 'Importing article...';"
    , "button.disabled = true;"
    , "try {"
    , "const response = await fetch('/api/articles', {"
    , "method: 'POST',"
    , "headers: { 'Content-Type': 'application/json' },"
    , "body: JSON.stringify({ url: input.value })"
    , "});"
    , "if (!response.ok) {"
    , "const payload = await response.json().catch(() => ({}));"
    , "throw new Error(payload.error || 'Failed to import article');"
    , "}"
    , "status.textContent = 'Article imported. Refreshing...';"
    , "window.location.reload();"
    , "} catch (error) {"
    , "status.textContent = error.message;"
    , "button.disabled = false;"
    , "}"
    , "});"
    , "})();"
    ]
