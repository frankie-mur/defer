{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module Defer.ArticleImport
  ( ParsedArticle (..)
  , fetchAndParseArticle
  , parseArticleHtml
  ) where

import Control.Exception (SomeException, try)
import Data.ByteString.Lazy (ByteString)
import Data.ByteString.Lazy qualified as LBS
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE
import Data.Text.Encoding.Error (lenientDecode)
import Network.HTTP.Simple (HttpException, Request, getResponseBody, httpLBS, parseRequest)
import Text.HTML.TagSoup (Tag (TagClose, TagOpen, TagText), parseTags)

-- | Parsed article data extracted from a web page.
data ParsedArticle = ParsedArticle
  { parsedTitle :: Text
  , parsedSummary :: Text
  , parsedContent :: Text
  }
  deriving (Eq, Show)

-- | Fetch a URL and parse article-like content from the HTML.
fetchAndParseArticle :: Text -> IO (Either Text ParsedArticle)
fetchAndParseArticle urlText = do
  requestOrError <- mkRequest urlText
  case requestOrError of
    Left err -> pure (Left err)
    Right request -> do
      responseOrError <- try @HttpException (httpLBS request)
      case responseOrError of
        Left _ -> pure (Left "Failed to fetch URL")
        Right response ->
          pure (Right (parseArticleHtml (decodeUtf8Lenient (getResponseBody response))))

mkRequest :: Text -> IO (Either Text Request)
mkRequest urlText = do
  requestOrError <- try @SomeException (parseRequest (T.unpack urlText))
  pure $
    case requestOrError of
      Left _ -> Left "Invalid URL"
      Right request -> Right request

parseArticleHtml :: Text -> ParsedArticle
parseArticleHtml htmlText =
  ParsedArticle
    { parsedTitle = titleText
    , parsedSummary = mkSummary contentText
    , parsedContent = contentText
    }
  where
    tags = parseTags htmlText
    titleText =
      case extractTextInTag "title" tags of
        "" -> "Untitled article"
        value -> value
    paragraphTexts = extractTextsInTag "p" tags
    contentText =
      if null paragraphTexts
        then fallbackBodyText tags
        else T.intercalate "\n\n" paragraphTexts

extractTextInTag :: Text -> [Tag Text] -> Text
extractTextInTag tagName tags =
  case extractTextsInTag tagName tags of
    [] -> ""
    (x : _) -> x

extractTextsInTag :: Text -> [Tag Text] -> [Text]
extractTextsInTag tagName = go False []
  where
    go _ acc [] = reverse (filter (not . T.null) (map normalizeWhitespace acc))
    go inTarget acc (TagOpen name _ : rest)
      | name == tagName = go True acc rest
      | otherwise = go inTarget acc rest
    go inTarget acc (TagClose name : rest)
      | name == tagName = go False acc rest
      | otherwise = go inTarget acc rest
    go inTarget acc (TagText txt : rest)
      | inTarget = go inTarget (txt : acc) rest
      | otherwise = go inTarget acc rest
    go inTarget acc (_ : rest) = go inTarget acc rest

fallbackBodyText :: [Tag Text] -> Text
fallbackBodyText tags =
  let texts = [normalizeWhitespace txt | TagText txt <- tags]
      chunks = filter (not . T.null) texts
   in T.intercalate " " chunks

mkSummary :: Text -> Text
mkSummary fullContent
  | T.length trimmed <= 280 = trimmed
  | otherwise = T.take 280 trimmed <> "…"
  where
    trimmed = normalizeWhitespace fullContent

normalizeWhitespace :: Text -> Text
normalizeWhitespace = T.unwords . T.words

decodeUtf8Lenient :: ByteString -> Text
decodeUtf8Lenient = TE.decodeUtf8With lenientDecode . LBS.toStrict
