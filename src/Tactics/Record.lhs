\section{Record declaration}

%if False

> {-# OPTIONS_GHC -F -pgmF she #-}
> {-# LANGUAGE TypeOperators, TypeSynonymInstances, GADTs #-}

> module Tactics.Record where

> import Evidences.Tm
> import Evidences.Mangler

> import ProofState.Edition.ProofState

> import DisplayLang.Name

%endif

> elabRecord ::  String -> [(String , DInTmRN)] -> ProofState (EXTM :=>: VAL)
> elabRecord name fields = undefined -- XXX: not yet implemented

