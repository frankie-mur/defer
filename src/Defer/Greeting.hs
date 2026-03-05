{-# LANGUAGE OverloadedStrings #-}

module Defer.Greeting
  ( greetingMessage
  ) where

import Data.Text (Text)

greetingMessage :: Text
greetingMessage = "Hello from defer (Haskell + WAI/Warp)!"
