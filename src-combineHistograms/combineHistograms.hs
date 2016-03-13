import Rarecoal.RareAlleleHistogram (RareAlleleHistogram(..), showHistogram, readHistogram)
import Control.Monad (foldM, when)
import Control.Error (scriptIO, runScript, Script, tryRight)
import qualified Data.Text.IO as T
import qualified Data.Map.Strict as Map
import qualified Options.Applicative as OP
import Data.Monoid ((<>))

main :: IO ()
main = OP.execParser parser >>= runWithOptions
  where
    parser = OP.info (OP.helper <*> OP.some parseFileName) (OP.fullDesc <> OP.progDesc "Tool to combine multiple histogram files, for help add option -h")
    parseFileName =
        OP.strArgument $ OP.metavar "histogram_file" <> OP.help "histogram file, put as many as you want to add up"
    
runWithOptions :: [FilePath] -> IO ()
runWithOptions fileNames = runScript $ do
    newHist <- combine fileNames
    outs <- tryRight $ showHistogram newHist
    scriptIO $ T.putStr outs

combine :: [FilePath] -> Script RareAlleleHistogram
combine filenames = do
    histograms <- mapM readHistogram filenames
    tryRight $ foldM addHistograms (head histograms) (tail histograms)

addHistograms :: RareAlleleHistogram -> RareAlleleHistogram -> Either String RareAlleleHistogram
addHistograms hist1 hist2 = do
    when (raNames hist1 /= raNames hist2) $ Left "histograms have different names"
    when (raNVec hist1 /= raNVec hist2) $ Left "histograms have different NVecs"
    when (raMaxAf hist1 /= raMaxAf hist2) $ Left "histograms have different maxAf"
    when (raConditionOn hist1 /= raConditionOn hist2) $ Left "histograms differ in conditioning"
    return $ hist1 {raCounts = Map.unionWith (+) (raCounts hist1) (raCounts hist2)}
