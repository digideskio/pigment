\section{Relabelling}

%if False

> {-# OPTIONS_GHC -F -pgmF she #-}
> {-# LANGUAGE GADTs, TypeOperators, TupleSections, PatternGuards,
>              FlexibleContexts #-}

> module Tactics.Relabel where

> import Control.Applicative
> import Control.Monad
> import Control.Monad.Except
> import Control.Monad.State
> import Data.Foldable hiding (foldr)
> import Data.Traversable

> import Evidences.Tm
> import Evidences.Utilities
> import Evidences.Eval
> import Evidences.Operators
> import Evidences.DefinitionalEquality
> import Evidences.TypeChecker

> import ProofState.Edition.ProofState
> import ProofState.Edition.GetSet
> import ProofState.Edition.Navigation
> import ProofState.Edition.Scope

> import ProofState.Interface.ProofKit
> import ProofState.Interface.Definition
> import ProofState.Interface.Solving
> import ProofState.Interface.Lifting
> import ProofState.Interface.Parameter

> import DisplayLang.DisplayTm
> import DisplayLang.Name

> import Elaboration.ElabMonad
> import Elaboration.Elaborator

> import Kit.BwdFwd
> import Kit.MissingLibrary

%endif

The |partApplyREF| command takes a reference and list of argument values (as
generated by |splitSpine|, and splits them into a term in local scope (i.e.
the reference applied to the shared parameters) and a list of additional
arguments.
\adam{where should this live?}

> partApplyREF :: REF -> [VAL] -> ProofStateT e (EXTM :=>: VAL :<: TY, [VAL])
> partApplyREF r@(_ := DECL :<: _) as = return (P r :=>: NP r :<: pty r, as)
> partApplyREF r as = do
>     es <- getGlobalScope
>     help (pty r) B0 (paramREFs es) as
>   where
>     help :: TY -> Bwd REF -> [REF] -> [VAL] -> ProofStateT e (EXTM :=>: VAL :<: TY, [VAL])
>     help (PI s t) cs (r:rs) (NP x : as) | r == x =
>         help (t $$ A (NP x)) (cs :< r) rs as
>     help ty cs [] as = do
>         let t = P r $## fmap NP cs
>         return (t :=>: evTm t :<: ty, as)
>     help ty cs rs as = throwError $ StackError
>         [ err "partApplyREF: failed on type "
>         , errTyVal (ty :<: SET)
>         , err " with refs "
>         , map ErrorREF rs
>         ]


A relabelling is a map from refrences to strings, giving a new name that should
be used for the reference.

> type Relabelling = Bwd (REF, String)

The |relabel| command changes the names of the pattern variables in a programming
problem. It takes an unelaborated application corresponding to the programming
problem, matches it against the existing arguments to determine the renaming,
and refines the proof state appropriately.

> relabel :: DExTmRN -> ProofState ()
> relabel (DP [(f, Rel 0)] ::$ ts) = do
>     tau' :=>: tau <- getHoleGoal
>     case tau of
>         LABEL (N l) ty -> do
>             let Just (r, as) = splitSpine l
>             unless (f == refNameAdvice r) $
>                 throwError $ sErr "relabel: mismatched function name!"
>             ts'  <- traverse unA ts
>             (_ :<: rty, as') <- partApplyREF r as
>             rl   <- execStateT (relabelArgs rty ts' as') B0
>             es   <- getEntriesAbove
>             refineProofState (liftType es tau') (N .($:$ paramSpine es))
>             introLambdas rl (paramREFs es)
>         _ -> throwError $ sErr "relabel: goal is not a labelled type!"
> relabel _ = throwError $ sErr "relabel: malformed relabel target!"

Once the refinement has been made, we need to introduce the hypotheses using
their new names. The |introLambdas| command takes a relabelling and the
references from the entries that were abstracted over, and introduces a
hypothesis corresponding to each reference with the reference's new name.

> introLambdas :: Relabelling -> [REF] -> ProofState ()
> introLambdas rl [] = return ()
> introLambdas rl (x:xs) = lambdaParam newName >> introLambdas rl xs
>   where
>     newName = case find ((x ==) . fst) rl of
>                   Just (_, s)  -> s
>                   Nothing      -> refNameAdvice x

> unA :: MonadError (StackError t) m => Elim a -> m a
> unA (A a)  = return a
> unA _      = throwError $ sErr "unA: not an A!"



> extendRelabelling :: REF -> String -> StateT Relabelling (ProofStateT a) ()
> extendRelabelling r s = do
>     rl <- get
>     case find ((r ==) . fst) rl of
>         Nothing                   -> put (rl :< (r, s))
>         Just (_, t)  | s == t     -> return ()
>                      | otherwise  -> throwErrorS
>             [ err ("relabelValue: inconsistent names '" ++ s ++ "' and '" ++
>                    t ++ "' for")
>             , errRef r
>             ]


> relabelArgs :: TY -> [DInTmRN] -> [VAL] -> StateT Relabelling ProofState ()
> relabelArgs _ []  []   = return ()
> relabelArgs _ []  _    = throwError $ sErr "relabel: too few arguments!"
> relabelArgs _ _   []   = throwError $ sErr "relabel: too many arguments!"
> relabelArgs (PI s t) (w:ws) (a:as) = do
>     relabelValue (s :>: (w, a))
>     relabelArgs (t $$ A a) ws as
> relabelArgs ty ws as  = throwErrorS
>     [ err "relabel: unmatched\nty ="
>     , errTyVal (ty :<: SET)
>     , err "\nas ="
>     , foldMap errVal as
>     ]


> relabelValue :: (TY :>: (DInTmRN, VAL)) -> StateT Relabelling ProofState ()

If the value we are matching against is a stuck recursive call, we match against
the user-friendly label (which is what the user would expect) rather than the
horrible induction term.

> relabelValue (ty :>: (w, N (n :$ Call l))) = relabelValue (ty :>: (w, l))

If we are matching two parameters (applied to some arguments), we can extend
the relabelling and matching the arguments.

> relabelValue (ty :>: (DN (DP [(s, Rel 0)] ::$ ws), N n))
>   | Just (r, as) <- splitSpine n = do
>     (_ :<: ty, as')  <- lift $ partApplyREF r as
>     extendRelabelling r s
>     ws'              <- lift $ traverse unA ws
>     relabelArgs ty ws' as'

If the display term is an underscore then we make no changes to the relabelling.

> relabelValue (ty :>: (DU, _)) = return ()

If the display term and value are both canonical, we halfzip them together
(ensuring the constructors match) and use |canTy| to match the pieces.

> relabelValue (C cty :>: (DC w, C v)) = case halfZip w v of
>     Nothing -> throwError $ sErr "relabelValue: mismatched constructors!"
>     Just wv -> (liftage fst $ canTy chev (cty :>: wv)) >> return ()
>   where
>     chev :: (TY :>: (DInTmRN, VAL)) ->
>                 StateT Relabelling (ProofStateT (DInTmRN, VAL)) (() :=>: VAL)
>     chev (ty :>: (w, v)) = do
>         liftage (\ t -> (t, error "erk")) $ relabelValue (ty :>: (w, v))
>         return (() :=>: v)
>
>     liftage :: (s -> t) -> StateT x (ProofStateT s) a
>                             -> StateT x (ProofStateT t) a
>     liftage = mapStateT . liftErrorState


If it is a tag (possibly applied to arguments) and needs to be matched against
an element of an inductive type, we match the tags and values.

> relabelValue (ty@(MU l d) :>: (DTag s as, CON (PAIR t xs)))
>   | Just (e, f) <- sumlike d = do
>     ntm :=>: nv  <- lift $ elaborate (Loc 0) (ENUMT e :>: DTAG s)
>     sameTag      <- lift $ withNSupply $ equal (ENUMT e :>: (nv, t))
>     unless sameTag $ throwError $ sErr "relabel: mismatched tags!"
>     relabelValue (descOp @@ [f t, ty] :>: (foldr DPAIR DVOID as, xs))

Similarly for indexed data types:

> relabelValue (IMU l _I d i :>: (DTag s as, CON (PAIR t xs)))
>   | Just (e, f) <- sumilike _I (d $$ A i) = do
>     ntm :=>: nv  <- lift $ elaborate (Loc 0) (ENUMT e :>: DTAG s)
>     sameTag      <- lift $ withNSupply $ equal (ENUMT e :>: (nv, t))
>     unless sameTag $ throwError $ sErr "relabel: mismatched tags!"
>     relabelValue (idescOp @@ [_I, f t,
>         L $ "i" :. [.i. IMU (fmap (-$ []) l) (_I -$ []) (d -$ []) (NV i)] ]
>             :>: (foldr DPAIR DU as, xs))

Lest we forget, tags may also belong to enumerations!

> relabelValue (ENUMT e :>: (DTag s [], t)) = do
>   ntm :=>: nv <- lift $ elaborate (Loc 0) (ENUMT e :>: DTAG s)
>   sameTag <- lift $ withNSupply $ equal (ENUMT e :>: (nv, t))
>   unless sameTag $ lift $ throwError $ sErr "relabel: mismatched tags!"

Nothing else matches? We had better give up.

> relabelValue (ty :>: (w, v)) = lift $ throwErrorS
>     [ err "relabel: can't match"
>     , errTm w
>     , err "with"
>     , errTyVal (v :<: ty)
>     ]

