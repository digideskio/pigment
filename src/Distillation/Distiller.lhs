The distiller {#sec:Distillation.Distiller}
=============

> {-# OPTIONS_GHC -F -pgmF she #-}
> {-# LANGUAGE GADTs, TypeOperators, PatternGuards, PatternSynonyms #-}

> module Distillation.Distiller where

> import Control.Monad.State
> import Text.PrettyPrint.HughesPJ (Doc)
> import Kit.BwdFwd
> import Kit.MissingLibrary
> import ProofState.Structure.Developments
> import ProofState.Edition.ProofState
> import ProofState.Interface.ProofKit
> import ProofState.Interface.NameResolution
> import ProofState.Interface.Name
> import DisplayLang.DisplayTm
> import DisplayLang.Scheme
> import DisplayLang.Name
> import DisplayLang.PrettyPrint
> import DisplayLang.Reactify
> import NameSupply.NameSupplier
> import Evidences.Tm
> import Evidences.Mangler
> import Evidences.TypeChecker
> import Evidences.BetaQuotation
> import Evidences.Eval
> import Evidences.Operators
> import Evidences.DefinitionalEquality
> import React

The distiller, like the elaborator, is organized on a `check` / `infer`
basis, following the type-checker implementation in
Section [subsec:Evidences.TypeChecker.type-checking]. `distill` mirrors
`check` — distilling `INTM`s, while `distillInfer` mirrors `infer` —
distilling `EXTM`s.

Distilling `INTM`s {#subsec:Distillation.Distiller.intm}
------------------

The `distill` command converts a typed `INTM` in the Evidence language
to a term in the Display language; that is, it reverses `elaborate`. It
peforms christening at the same time, turning absolute names into
relative names.

The distiller first tries to apply Feature-specific rules. These rules
contain the intelligence of the distiller, aiming at making a concise
Display term. If unsuccessful, the distiller falls back to the generic
rules in `distillBase`.

When going under a binder, we have to introduce fresh names to distill
further. When christening, these fresh names have to be dealt with
separately (see `unresolve` in
Section [subsec:ProofState.Interface.NameResolution.christening]):
indeed, they are actually bound variables. Hence, we collect this *local
scope* as a list of `Entries`.

> distill :: Entries -> (TY :>: INTM) -> ProofStateT INTM (DInTmRN :=>: VAL)
> distill es (ANCHORS :>: x@(ANCHOR (TAG u) t ts)) = do
>     (displayTs :=>: _) <- distill es (ALLOWEDBY (evTm t) :>: ts)
>     return (DANCHOR u displayTs :=>: evTm x)

The following cases turn vaguely list-like data into actual lists. We
don't want this in general, but it is useful in special cases (when the
data type is really supposed to be a list, as in `EnumD`).

> distill _ (MU (Just (ANCHOR (TAG r) _ _)) _ :>: CON (PAIR ZE VOID))
>     | r == "EnumU" = return (DVOID :=>: CON (PAIR ZE VOID))
> distill es (C ty@(Mu (Just (ANCHOR (TAG r) _ _) :?=: _)) :>:
>     C c@(Con (PAIR (SU ZE) (PAIR _ (PAIR _ VOID)))))
>     | r == "EnumU" = do
>       Con (DPAIR _ (DPAIR s (DPAIR t _)) :=>: v) <- canTy  (distill es)
>                                                            (ty :>: c)
>       return ((DPAIR s t) :=>: CON v)

If we have a canonical value in `MU s`, where `s` starts with a finite
sum, then we can (probably) turn it into a tag applied to some
arguments.

> distill es (ty@(MU l s) :>: CON (PAIR t x)) | Just (e, f) <- sumlike s = do
>     m   :=>: tv  <- distill es (ENUMT e :>: t)
>     as  :=>: xv  <- distill es (descOp @@ [f tv, ty] :>: x)
>     case m of
>         DTAG s   -> return $ DTag s (unfold as)  :=>: CON (PAIR tv xv)
>         _        -> return $ DCON (DPAIR m as)   :=>: CON (PAIR tv xv)
>   where
>     unfold :: DInTmRN -> [DInTmRN]
>     unfold DU           = [] -- since DVOID gets turned into this first
>     unfold DVOID        = []
>     unfold (DPAIR s t)  = s : unfold t
>     unfold t            = [t]

Conversely, we can distill an index to a tag as follows. Note that if
the index contains a stuck term, we simply give up and let the normal
distillation rules take over; the pretty-printer will then do the right
thing.

> distill _ (ENUMT t :>: tm) | Just r <- findIndex (t :>: tm) = return r
>     where
>       findIndex :: (VAL :>: INTM) -> Maybe (DInTmRN :=>: VAL)
>       findIndex (CONSE (TAG s)  _ :>: ZE)    = Just (DTAG s :=>: evTm tm)
>       findIndex (CONSE _        a :>: SU b)  = findIndex (a :>: b)
>       findIndex _                            = Nothing

Since elaboration turns lists into functions from enumerated types, we
can do the reverse when distilling. This is slightly dubious.

> distill es (PI (ENUMT e) t :>: L (x :. N (op :@ [e', NV 0, t', b])))
>   | op == switchOp = distill es (branchesOp @@ [e, t] :>: b)
> distill es (PROP :>: tm@(EQBLUE (tty :>: t) (uty :>: u))) = do
>     t' <- toDExTm es (tty :>: t)
>     u' <- toDExTm es (uty :>: u)
>     return $ DEqBlue t' u' :=>: evTm tm

When distilling a proof of an equation, we first check to see if the
equation holds definitionally. If so, we avoid forcing the proof and
return refl instead.

> distill es (p@(PRF (EQBLUE (_S :>: s) (_T :>: t))) :>: q) = do
>     r <- askNSupply
>     if equal (SET :>: (_S, _T)) r && equal (_S :>: (s, t)) r
>         then return (DU :=>: N (P refl :$ A _S :$ A s))
>         else distillBase es (p :>: q)
> distill es (IMU l _I s i :>: CON (PAIR t x))
>   | Just (e, f) <- sumilike _I (s $$ A i) = do
>     m   :=>: tv  <- distill es (ENUMT e :>: t)
>     as  :=>: xv  <-
>       distill es (idescOp @@ [  _I,f tv
>                              ,  L $ "i" :. [.i.
>                                   IMU (fmap (-$ []) l)
>                                       (_I -$ []) (s -$ []) (NV i)]
>                              ] :>: x)
>     case m of
>         DTAG s   -> return $ DTag s (unfold as)  :=>: CON (PAIR tv xv)
>         _        -> return $ DCON (DPAIR m as)   :=>: CON (PAIR tv xv)
>   where
>     unfold :: DInTmRN -> [DInTmRN]
>     unfold DVOID        = []
>     unfold DU        = []
>     unfold (DPAIR s t)  = s : unfold t
>     unfold t            = [t]
> distill es (SET :>: tm@(C (IMu ltm@(Just l :?=: (Id _I :& Id s)) i))) = do
>     let lab = evTm ((l :? ARR _I ANCHORS) :$ A i)
>     labTm                <- bquoteHere lab
>     (labDisplay :=>: _)  <- distill es (ANCHORS :>: labTm)
>     _It :=>: _Iv         <- distill es (SET :>: _I)
>     st :=>: sv           <- distill es (ARR _Iv (idesc $$ A _Iv) :>: s)
>     it :=>: iv           <- distill es (_Iv :>: i)
>     return $ (DIMU (Just labDisplay) _It st it :=>: evTm tm)

To avoid an infinite loop when distilling, we have to be a little
cleverer and call canTy directly rather than letting distill do it for
us.

> distill _ (NU _ _ :>: CON (PAIR ZE VOID)) =
>     return (DVOID :=>: CON (PAIR ZE VOID))
> distill es (C ty@(Nu _) :>: C c@(Con (PAIR (SU ZE) (PAIR _ (PAIR _ VOID))))) = do
>     Con (DPAIR _ (DPAIR s (DPAIR t _)) :=>: v) <- canTy (distill es) (ty :>: c)
>     return (DPAIR s t :=>: CON v)

If a label is not in scope, we remove it, so the definition appears at
the appropriate place when the proof state is printed.

> distill es (SET :>: tm@(C (Nu ltm@(Just _ :?=: _)))) = do
>     cc <- canTy (distill es) (Set :>: Nu ltm)
>     return ((DC $ fmap termOf cc) :=>: evTm tm)
> distill es (PRF TRIVIAL :>: _) = return (DU :=>: VOID)
> distill es (UNIT :>: _) = return $ DVOID :=>: VOID
> distill entries tt = distillBase entries tt

We separate out the standard distillation cases (without aspect
extensions) so that aspect distill rules can give up and invoke the base
cases.

> distillBase :: Entries -> (TY :>: INTM) -> ProofStateT INTM (DInTmRN :=>: VAL)

We distill structurally through canonical terms:

> distillBase entries (C ty :>: C c) = do
>     cc <- canTy (distill entries) (ty :>: c)
>     return $ (DC $ fmap termOf cc) :=>: evTm (C c)

To distill a $lambda$-abstraction, we speculate a fresh reference and
distill under the binder, then convert the scope appropriately. The
`INTM` version of the entry type should never be used, so we can simply
omit it. (Hopefully we will switch the entries to `Bwd REF` so this will
not be necessary.)

> distillBase entries (ty :>: l@(L sc)) = do
>     let x = fortran l
>     (kind, dom, cod) <- lambdable ty `catchMaybe`  (StackError
>         [ err "distill: type "
>         , errVal ty
>         , err " is not lambdable."
>         ])
>     tm' :=>: _ <-  freshRef (x :<: dom) $ \ref ->
>                    distill  (entries :< EPARAM  ref (mkLastName ref) kind
>                                                 (error "distill: type undefined") AnchNo True)
>                             (cod (pval ref) :>: underScope sc ref)
>     return $ DL (convScope sc x tm') :=>: (evTm $ L sc)
>   where
>     convScope :: Scope {TT} REF -> String -> DInTmRN -> DSCOPE
>     convScope (_ :. _)  x  tm = x ::. tm
>     convScope (K _)     _  tm = DK tm

If we encounter a neutral term, we switch to `distillInfer`.

> distillBase entries (_ :>: N n) = do
>     (n' :<: _) <- distillInfer entries n []
>     return $ DN n' :=>: evTm n

If none of the cases match, we complain loudly.

> distillBase _ (ty :>: tm) =  throwErrorS
>     [ err "distill: can't cope with\n"
>     , errTm tm
>     , err " :<: "
>     , errVal ty
>     ]

Distilling `EXTM`s
------------------

The `distillInfer` command is the `EXTM` version of `distill`, which
also yields the type of the term. Following `distill`, we maintain the
local scope of fresh references.

Moreover, recall that the `DExTm` terms are in Spine form: they are
composed of a `DHead` — either parameter, type annotation, or embedding
of `ExTm` — and followed by a spine of eliminators. To perform this
translation, we accumulate a `spine` and distill it when we reach the
head. Doing so, shared parameters can be removed (see
subsection [subsec:ProofState.Interface.NameResolution.christening]).

> distillInfer ::  Entries -> EXTM -> Spine {TT} REF ->
>                  ProofStateT INTM (DExTmRN :<: TY)

If we spot a neutral term being called when distilling, we distill the
label instead, thereby replacing horrible stuck inductions with the
pretty functions they implement.

> distillInfer es (t :$ Call (N l)) as = distillInfer es l as

To distill a parameter with a spine of eliminators, we use |unresolve|
to determine a relative name for the reference, the number of shared
parameters, and possibly a scheme attached to it. We then call on
|distillSpine| to process the eliminators, and return the distilled
elimination with the shared parameters and implicit arguments removed.

> distillInfer entries tm@(P (name := kind :<: ty)) spine = do
>     -- Compute a relative name from |name|
>     proofCtxt <- get
>     let  (relName, argsToDrop, mSch) =
>           unresolve name kind spine (inBScope proofCtxt) entries
>     -- Distill the spine
>     (e', ty') <- distillSpine entries (evTm tm :<: ty) spine
>     -- Remove shared parameters and implicit arguments
>     let  spine1  = drop argsToDrop e'
>          spine2  = maybe spine1 (hideImplicit spine1) mSch
>     -- Ignore de Bruijn index on FAKE references (issue 87)
>     let relName' = case (relName, kind) of
>                          ([(s, _)], FAKE)  -> [(s, Rel 0)]
>                          _                 -> relName
>     -- Return the relative name applied to the simplified spine
>     return $ (DP relName' ::$ spine2) :<: ty'
>   where

If the parameter has a scheme attached, we need to remove implicit
arguments once we have distilled the spine and dropped the shared
parameters. We proceed structurally through the scheme, removing
arguments that should be implicit.

>     hideImplicit :: DSPINE -> Scheme x -> DSPINE
>     hideImplicit as      (SchType _)            = as
>     hideImplicit (a:as)  (SchExplicitPi _ sch)  = a : hideImplicit as sch
>     hideImplicit (a:as)  (SchImplicitPi _ sch)  = hideImplicit as sch
>     hideImplicit []      _                      = []

To distill an elimination, we simply push the eliminator on to the
spine.

> distillInfer entries (t :$ e) spine = distillInfer entries t (e : spine)

Because there are no operators in the display syntax, we replace them
with parameters containing the appropriate primitive references.

> distillInfer entries (op :@ args) spine =
>     distillInfer  entries (P  (lookupOpRef op)) (map A args ++ spine)

Unnecessary type ascriptions can simply be dropped. As we can always
*infer* the type of a neutral term, there is no point in keeping its
ascription. This also ensures that shared parameters are handled
correctly when the head is a parameter under a type ascription, because
distillation will proceed using the rule for parameters above.

> distillInfer entries (N t :? _) spine  = distillInfer entries t spine

Typed identity functions applied to an argument can simply be removed.
We do this because they are inserted by elaboration of type annotations;
if a user manually creates one, we can safely remove it anyway.

> distillInfer entries (L (_ :. NV 0) :? PI ty _) ((A a):spine) =
>     distillInfer entries (a :? ty) spine

Otherwise, we have no choice but distilling both side of the type
ascription (term and value). This gives a type annotation applied to the
distilled term, together with the distilled spine.

> distillInfer entries (t :? ty) spine   = do
>     -- Distill the type
>     ty1  :=>: vty  <- distill entries (SET :>: ty)
>     -- Distill the term
>     t1   :=>: vt   <- distill entries (vty :>: t)
>     -- Distill the spine
>     (e, ty2)     <- distillSpine entries (vt :<: vty) spine
>     -- Annotate the term by the type, followed by its spine
>     return $ DType ty1 ::$ (A t1 : e) :<: ty2

If nothing matches, we are unable to distill this term, so we complain
loudly.

> distillInfer _ tm _ =  throwErrorS
>     [ err "distillInfer: can't cope with "
>     , errTm (N tm)
>     ]

Distillation support
--------------------

The `distillSpine` command takes a list of entries in scope, a typed
value and a spine of arguments for the value. It distills the spine,
using `elimTy` to determine the appropriate type to push in at each
step, and returns the distilled spine and the overall type of the
application.

> distillSpine ::  Entries -> (VAL :<: TY) -> Spine {TT} REF ->
>                  ProofStateT INTM (DSPINE, TY)
> distillSpine _        (_ :<: ty)    []         = return ([], ty)
> distillSpine entries  (v :<: C ty)  (a:spine)  = do
>     -- Distill structurally the eliminator |a|
>     (e1, ty1) <- elimTy (distill entries) (v :<: ty) a
>     -- Further distill the spine
>     (es, ty2) <- distillSpine entries (v $$ (fmap valueOf e1) :<: ty1) spine
>     -- Return distilled spine and type of the application
>     return (fmap termOf e1 : es, ty2)
> distillSpine entries  (v :<: ty)    spine      = throwErrorS
>     [ err "distillSpine: cannot cope with"
>     , errTyVal (v :<: ty)
>     , err "which has non-canonical type"
>     , errTyVal (ty :<: SET)
>     , err "applied to spine"
>     , map ErrorElim spine
>     ]

The `toDExTm` helper function will distill a term to produce an |Ex|
representation by applying a type annotation only if necessary.

> toDExTm :: Entries -> (INTM :>: INTM) -> ProofStateT INTM DExTmRN
> toDExTm entries (_ :>: N tm) = do
>     (tm' :<: _) <- distillInfer entries tm []
>     return tm'
> toDExTm entries (ty :>: tm) = do
>     (ty'  :=>: tyv)  <- distill entries (SET :>: ty)
>     (tm'  :=>: _)    <- distill entries (tyv :>: tm)
>     return $ DTY ty' tm'

Distillation interface
----------------------

The `distillHere` command distills a term in the current context.

> distillHere :: (TY :>: INTM) -> ProofState (DInTmRN :=>: VAL)
> distillHere tt = liftErrorState DTIN $ distill B0 tt

The `prettyHere` command distills a term in the current context, then
passes it to the pretty-printer.

> prettyHere :: (TY :>: INTM) -> ProofState Doc
> prettyHere = prettyHereAt maxBound

> prettyHereAt :: Size -> (TY :>: INTM) -> ProofState Doc
> prettyHereAt size tt = do
>     dtm :=>: _ <- distillHere tt
>     return (pretty dtm size)

> reactHere :: (TY :>: INTM) -> ProofState PureReact
> reactHere = reactHereAt

> reactHereAt :: (TY :>: INTM) -> ProofState PureReact
> reactHereAt tt = do
>     dtm :=>: _ <- distillHere tt
>     return $ reactify dtm
