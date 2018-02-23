{-# LANGUAGE OverloadedStrings #-}

import SequenceFormats.FreqSum (FreqSumEntry(..), FreqSumHeader(..), printFreqSumStdOut)
import SequenceFormats.VCF (readVCFfromStdIn, vcfToFreqSumEntry, VCFheader(..), VCFentry)

import Data.IORef (newIORef, readIORef, writeIORef, IORef)
import qualified Data.Text as T
import qualified Options.Applicative as OP
import Pipes (Pipe, runEffect, (>->), cat, for, yield)
import qualified Pipes.Prelude as P

main :: IO ()
main = OP.execParser opts >> run
  where
    opts = OP.info (OP.helper <*> pure ()) (OP.progDesc "convert a multi-sample VCF, read from \
                                                         \stdin, into a freqSum file")

run :: IO ()
run = do
    (VCFheader _ names, vcfProd) <- readVCFfromStdIn
    let fsHeader = FreqSumHeader names (replicate (length names) 2)
    lastPos <- newIORef ("", 0)
    runEffect $ vcfProd >-> processVCFentry >-> P.filterM (removeDuplicatePositions lastPos) >->
        printFreqSumStdOut fsHeader

processVCFentry :: Pipe VCFentry FreqSumEntry IO ()
processVCFentry = for cat $ \vcfEntry -> do
    case vcfToFreqSumEntry vcfEntry of
        Left err -> error err
        Right a -> yield a

removeDuplicatePositions :: IORef (T.Text, Int) -> FreqSumEntry -> IO Bool
removeDuplicatePositions lastPos (FreqSumEntry chrom pos _ _ _) = do
    (chrom', pos') <- readIORef lastPos
    let ret = if chrom' == chrom && pos' == pos then False else True
    writeIORef lastPos (chrom, pos)
    return ret

