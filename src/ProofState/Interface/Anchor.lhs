\section{Anchor resolution}


%if False

> {-# OPTIONS_GHC -F -pgmF she #-}
> {-# LANGUAGE FlexibleInstances, TypeOperators, TypeSynonymInstances,
>              GADTs, RankNTypes #-}

> module ProofState.Interface.Anchor where

> import Debug.Trace

> import Control.Applicative
> import Control.Monad

> import Data.Foldable
> import Data.Traversable

> import Kit.MissingLibrary
> import Kit.BwdFwd
> import Kit.Trace

> import NameSupply.NameSupply

> import ProofState.Structure.Developments

> import ProofState.Edition.ProofState
> import ProofState.Edition.GetSet
> import ProofState.Edition.Navigation
> import ProofState.Edition.Scope

> import Evidences.Tm

> import DisplayLang.Name

%endif

> isAnchor :: Traversable f => Entry f -> Bool
> isAnchor (EEntity _ _ _ _ (Just _))  = True
> isAnchor _                           = False

> anchorsInScope :: ProofState Entries
> anchorsInScope = do
>   scope <- getInScope 
>   return $ foldMap anchors scope
>       where anchors t | isAnchor t = B0 :< t
>                       | otherwise  = B0

To cope with shadowing, we will need some form of |RelativeAnchor|:

< type RelativeAnchor = (Anchor, Int)

With shadowing punished by De Bruijn. Meanwhile, let's keep it simple.


> resolveAnchor :: Anchor -> ProofStateT e (Maybe REF)
> resolveAnchor anchor = do
>   scope <- getInScope
>   case seekAnchor scope of
>     B0 -> return $ Nothing
>     _ :< ref -> return $ Just ref
>     where seekAnchor :: Entries -> Bwd REF
>           seekAnchor B0 = (|)
>           seekAnchor (scope :< EPARAM ref _ _ _ (Just anchor')) 
>                            | anchor' == anchor = {-trace ("Pgot! " ++ anchor') $-} B0 :< ref
>                            | otherwise = {-trace ("Pgot " ++ anchor') $-} seekAnchor scope
>           seekAnchor (scope :< EPARAM ref _ _ _ Nothing) = {-trace "Param" $-} seekAnchor scope
>           seekAnchor (scope :< EDEF ref _ _ dev _ (Just anchor'))
>                            | anchor' == anchor = {-trace ("Dgot! " ++ anchor') $-} B0 :< ref
>                            | otherwise =  {-trace ("Dgot " ++ anchor') $-} seekAnchor (devEntries dev) 
>                                           <+> seekAnchor scope
>           seekAnchor (scope :< EDEF ref _ _ dev _ Nothing) = {-trace "def" $-}  seekAnchor (devEntries dev) 
>                                           <+> seekAnchor scope
>           seekAnchor (scope :< EModule _ dev) = {-trace "module" $-} seekAnchor (devEntries dev) <+> seekAnchor scope


Find the entry corresponding to the given anchor:

> findAnchor :: Anchor -> ProofState ()
> findAnchor = undefined

Redefine the entry corresponding from the given anchor, so that's name
is the second anchor:

> renameAnchor :: Anchor -> Anchor -> ProofState ()
> renameAnchor = undefined