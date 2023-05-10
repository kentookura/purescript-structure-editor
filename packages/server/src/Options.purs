module API.Options
  ( options
  , optionsParser
  , Options
  , Options_
  ) where

import Prelude

import Control.Alt ((<|>))
import Effect (Effect)
import Effect.Console (log)
import Data.Array as A
import Data.Foldable (sequence_)
import Data.Maybe (Maybe(..), optional)
import Data.String as S

import Data.Array (replicate)
import Options.Applicative
import Data.Semigroup ((<>))

import Node.Process as Process

type Options_ a =
  { port :: a
  , outputDirectory :: String
  , sourceDirectories :: Array String
  }

type Options = Options_ (Maybe Int)

defaultOptions :: Options
defaultOptions =
  { port: Nothing
  , outputDirectory: "output"
  , sourceDirectories: []
  }

buildOptions :: Options -> { port :: Maybe Int, includes :: String, outputDirectory :: String } -> Options
buildOptions defaults { port, includes, outputDirectory } = do
  { port
  , sourceDirectories: defaults.sourceDirectories <> includesArr
  , outputDirectory
  }
  where
  includesArr = sepArguments ";" includes

  sepArguments :: String -> String -> Array String
  sepArguments sep =
    A.filter (not S.null) <<< S.split (S.Pattern sep)

options :: Options -> Parser Options
options defaults = ado
  port <- optional
    ( option int
        ( long "port"
            <> short 'p'
            <> metavar "PORT"
            <> help "What port to start the server on"
        )
    )
  outputDirectory <-
    strOption
      ( long "output"
          <> short 'O'
          <> metavar "OUTPUT"
          <> value "output"
          <> help "Output directory for compiled HTML"
      ) <|> pure "output"

  includes <-
    strOption
      ( long "include"
          <> short 'I'
          <> help "Directories for additional source files, separated by `;`"
          <> value ""
          <> metavar "INCLUDES"
      ) <|> pure ""
  in
    buildOptions defaults { port, outputDirectory, includes }

optionsParser :: Effect Options
optionsParser = do
  defaults <- mkDefaultOptions
  execParser (opts defaults) >>= pure
  --case _ of
  --  Nothing -> do
  --    Process.exit 0
  --  Just os -> pure os
  where
  opts defaults = info (options defaults <**> helper)
    (fullDesc <> progDesc "Watches and compiles notes")

mkDefaultOptions :: Effect Options
mkDefaultOptions =
  (defaultOptions { sourceDirectories = _ })
    <$> scanDefaultDirectories

scanDefaultDirectories :: Effect (Array String)
scanDefaultDirectories =
  let
    defaultDirectories = [ "notes" ]
    mkGlob dir = dir <> "/**/*.md"
  in
    A.filterA (map (not <<< A.null) <<< gazeImpl <<< mkGlob) defaultDirectories

foreign import gazeImpl :: String -> Effect (Array String)