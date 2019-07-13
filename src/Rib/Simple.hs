{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

-- Sensible defaults for writing the most simple static site
module Rib.Simple
  ( Page(..)
  , Post(..)
  , isDraft
  , simpleBuildRules
  , settings
  ) where

import Control.Monad
import Data.Aeson (FromJSON, ToJSON)
import Data.Maybe
import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)

import Development.Shake
import Development.Shake.FilePath
import Lucid
import Text.Pandoc (Pandoc)

import Rib.Pandoc (getPandocMetaValue, parsePandoc)
import Rib.Server (getHTMLFileUrl)
import qualified Rib.Settings as S
import Rib.Shake (parsePandocCached)

-- | Represents a HTML page that will be generated
data Page
  = Page_Index [Post]
  | Page_Post Post
  deriving (Generic, Show, FromJSON, ToJSON)

-- | A Post corresponding to the Markdown content
data Post = Post
  { _post_doc :: Pandoc
  , _post_url :: Text
  }
  deriving (Generic, Eq, Ord, Show, FromJSON, ToJSON)

isDraft :: Post -> Bool
isDraft = fromMaybe False . getPandocMetaValue "draft" . _post_doc

-- Build rules for the simplest site possible.
--
-- Just posts and static files.
simpleBuildRules
  :: [FilePath]
  -- ^ Which files are considered to be static files.
  -> [FilePath]
  -- ^ Which files are considered to be post files
  -> S.Settings Page
  -> Action ()
simpleBuildRules staticFilePatterns postFilePatterns cfg@S.Settings {..} = do
  -- Copy static assets
  files <- getDirectoryFiles contentDir staticFilePatterns
  void $ forP files $ \inp ->
    copyFileChanged (contentDir </> inp) (destDir </> inp)

  -- Generate posts
  postFiles <- getDirectoryFiles contentDir postFilePatterns
  posts <- forP postFiles $ \f -> do
    let out = destDir </> f -<.> "html"
        inp = contentDir </> f
    Page_Post post <- parsePandocCached cfg inp
    liftIO $ renderToFile out $ renderPage $ Page_Post post
    pure post

  -- Generate the main table of contents
  let publicPosts = filter (not . isDraft) posts
  liftIO $ renderToFile (destDir </> "index.html") $
    renderPage $ Page_Index publicPosts


settings :: S.Settings Page
settings = S.Settings
  { renderPage = \page -> do
      h1_ "TODO: You should override the renderPage function in your settings"
      pre_ $ toHtml $ T.pack $ show page
  , parsePage = \f -> do
      doc <- parsePandoc . T.pack <$> readFile' f
      pure $ Page_Post $ Post doc $ getHTMLFileUrl $ dropDirectory1 f
  , contentDir = "content"
  , destDir = "content.generated"
  , rebuildPatterns = ["**/*.html", "**/*.md"]

  , buildRules = simpleBuildRules ["static//**"] ["*.md"]
  }
