\section{Desc}

%if False

> {-# OPTIONS_GHC -F -pgmF she #-}
> {-# LANGUAGE TypeOperators, GADTs, KindSignatures,
>     TypeSynonymInstances, FlexibleInstances, ScopedTypeVariables #-}

> module IDesc where

%endif

> import -> CanConstructors where
>   IDesc   :: t -> Can t
>   IMu     :: Labelled (Id :*: Id) t -> t -> Can t
>   IDone   :: t -> Can t
>   IArg    :: t -> t -> Can t
>   IInd1   :: t -> t -> Can t
>   IInd    :: t -> t -> t -> Can t

> import -> TraverseCan where
>   traverse f (IDesc i) = (|IDesc (f i)|)
>   traverse f (IMu l i) = (|IMu (traverse f l) (f i)|)
>   traverse f (IDone p) = (|IDone (f p)|)
>   traverse f (IArg a d) = (|IArg (f a) (f d)|)
>   traverse f (IInd1 x y) = (|IInd1 (f x) (f y)|)
>   traverse f (IInd x y z) = (|IInd (f x) (f y) (f z)|)

> import -> HalfZipCan where
>   halfZip (IDesc i0) (IDesc i1) = (|(IDesc (i0,i1))|)
>   halfZip (IMu l0 i0) (IMu l1 i1) = (|(\p -> IMu p (i0,i1)) (halfZip l0 l1)|)
>   halfZip (IDone p0) (IDone p1) = (|(IDone (p0,p1))|)
>   halfZip (IArg a0 d0) (IArg a1 d1) = (|(IArg (a0,a1) (d0,d1))|)
>   halfZip (IInd1 x0 y0) (IInd1 x1 y1) = (|(IInd1 (x0,x1) (y0,y1))|)
>   halfZip (IInd x0 y0 z0) (IInd x1 y1 z1) = (|(IInd (x0,x1) (y0,y1) (z0,z1))|)

> import -> CanPats where
>   pattern IDESC i = C (IDesc i)
>   pattern IMU l ii x i = C (IMu (l :?=: (Id ii :& Id x)) i) 
>   pattern IDONE p = C (IDone p) 
>   pattern IARG s d = C (IArg s d) 
>   pattern IIND h hi d = C (IInd h hi d) 
>   pattern IIND1 i d = C (IInd1 i d) 

> import -> DisplayCanPats where
>   pattern DIDESC i = DC (IDesc i)
>   pattern DIMU l ii x i = DC (IMu (l :?=: (Id ii :& Id x)) i) 
>   pattern DIDONE p = DC (IDone p) 
>   pattern DIARG s d = DC (IArg s d) 
>   pattern DIIND h hi d = DC (IInd h hi d) 
>   pattern DIIND1 i d = DC (IInd1 i d) 

> import -> SugarTactics where
>   dmuTac ii t i = can $ IMu (Nothing :?=: (Id ii :& Id t)) i
>   dmuTacL l i = can $ IMu l i
>   idescTac i = can $ IDesc i 
>   ddoneTac p = can $ IDone p 
>   dargTac x y = can $ IArg x y 
>   dindTac x y z = can $ IInd x y z 
>   dind1Tac x y = can $ IInd1 x y 

> import -> CanTyRules where
>   canTy chev (Set :>: IMu (ml :?=: (Id ii :& Id x)) i)  = do
>     iiiiv@(ii :=>: iiv) <- chev (SET :>: ii)
>     mlv <- traverse (chev . (ARR iiv SET :>:)) ml
>     xxv@(x :=>: xv) <- chev (ARR iiv (IDESC iiv) :>: x)
>     iiv <- chev (iiv :>: i)
>     return $ IMu (mlv :?=: (Id iiiiv :& Id xxv)) iiv
>   canTy chev (IMu tt@(_ :?=: (Id ii :& Id x)) i :>: Con y) = do
>     yyv <- chev (descOp @@ [ ii
>                            , x $$ A i 
>                            , L $ HF "i" $ \i -> C (IMu tt i)
>                            ] :>: y)
>     return $ Con yyv
>   canTy chev (Set :>: IDesc ii) = 
>     (|IDesc (chev (SET :>: ii))|)
>   canTy chev (IDesc ii :>: IDone p) =  
>     (|IDone (chev (PROP :>: p))|)
>   canTy chev (IDesc ii :>: IArg a d) = do
>     aav@(a :=>: av) <- chev (SET :>: a)  
>     ddv <- chev (ARR av (IDESC ii) :>: d)
>     (|(IArg aav ddv)|)  
>   canTy chev (IDesc ii :>: IInd1 i d) =
>     (|IInd1 (chev (ii :>: i)) (chev (IDESC ii :>: d))|)  
>   canTy chev (IDesc ii :>: IInd h hi d) = do
>     hhv@(h :=>: hv) <- chev (SET :>: h)
>     hihiv@(hi :=>: hiv) <- chev (ARR hv ii :>: hi)
>     ddv <- chev (IDESC ii :>: d)
>     (|(IInd hhv hihiv ddv)|)  

> import -> CanPretty where
>   pretty (IDesc ii) = parens (text "IDesc" <+> pretty ii)
>   pretty (IMu (Just l   :?=: _) i)  = parens (pretty l <+> pretty i)
>   pretty (IMu (Nothing  :?=: (Id ii :& Id d)) i)  = 
>     parens (text "IMu" <+> pretty ii <+> pretty d <+> pretty i)
>   pretty (IDone p) = parens (text "IDone" <+> pretty p)
>   pretty (IArg a d) = parens (text "IArg" <+> pretty a <+> pretty d)
>   pretty (IInd1 i d) = parens (text "IInd1" <+> pretty i <+> pretty d)
>   pretty (IInd h hi d) = parens (text "IInd" <+> pretty h <+> pretty hi <+> pretty d)

> import -> ElimTyRules where
>   elimTy chev (_ :<: (IMu tt@(_ :?=: (Id ii :& Id x)) i)) Out = 
>     return (Out, descOp @@ [ii , x $$ A i , L $ HF "i" $ \i -> C (IMu tt i)])

> import -> Operators where
>   idescOp :
>   iboxOp :
>   imapBoxOp :
>   ielimOp :

> import -> OpCompile where
>   -- ("elimOp", [d,v,bp,p]) -> App (Var "__elim") [d, p, v]
>   -- ("mapBox", [x,d,bp,p,v]) -> App (Var "__mapBox") [x, p, v]
>   -- ("SwitchD", [e,b,x]) -> App (Var "__switch") [x, b]

> import -> OpCode where
>   idescOp :: Op
>   idescOp = Op
>     { opName = "idescOp"
>     , opArity = 3
>     , opTyTel = idOpTy
>     , opRun = idOpRun
>     , opSimp = \_ _ -> empty
>     } where
>       idOpTy = 
>        "i" :<: SET :-: \i ->
>        "d" :<: IDESC i :-: \d ->
>        "x" :<: ARR i SET :-: \x ->
>        Ret SET
>       idOpRun :: [VAL] -> Either NEU VAL
>       idOpRun [ii,IDONE p,x]    = Right $ PRF p
>       idOpRun [ii,IARG aa d,x] = Right $
>          eval [.ii.aa.d.x. 
>               SIGMA (NV aa) . L $ "" :. [.a.
>               (N (idescOp :@ [NV ii,d $# [a],NV x]))
>               ]] $ B0 :< ii :< aa :< d :< x
>       idOpRun [ii,IIND1 i d,x] = Right (TIMES (x $$ A i) (idescOp @@ [ii,d,x]))
>       idOpRun [ii,IIND h hi d,x] = 
>         Right (TIMES (PI h (L $ HF "h" (\h -> x $$ (A (hi $$ (A h)))))) 
>                      (idescOp @@ [ii,d,x]))
>       idOpRun [_,N x,_]     = Left x

>   iboxOp :: Op
>   iboxOp = Op
>     { opName = "iboxOp"
>     , opArity = 4
>     , opTyTel = iboxOpTy
>     , opRun = iboxOpRun
>     , opSimp = \_ _ -> empty
>     } where
>       iboxOpTy = 
>         "ii" :<: SET :-: \ii ->
>         "d" :<: IDESC ii :-: \d ->
>         "x" :<: ARR ii SET :-: \x ->
>         "v" :<: (descOp @@ [ii,d,x]) :-: \v ->
>         Ret $ IDESC (SIGMA ii (L $ HF "i" (\i -> x $$ A i)))
>       iboxOpRun :: [VAL] -> Either NEU VAL
>       iboxOpRun [ii,IDONE _ ,x,v] = Right (IDONE TRIVIAL)
>       iboxOpRun [ii,IARG a d,x,v] = Right $ 
>         iboxOp @@ [ii,d $$ (A (v $$ Fst)),x,v $$ Snd]
>       iboxOpRun [ii,IIND h hi d,x,v] = Right $
>         IIND h (L (HF "h" $ \hh -> PAIR (hi $$ A hh) (v $$ Fst $$ A hh))) 
>              (iboxOp @@ [ii,d,x,v $$ Snd])
>       iboxOpRun [ii,IIND1 i d,x,v] = Right $ 
>         IIND1 (PAIR i (v $$ Fst)) (iboxOp @@ [ii,d,x,v $$ Snd])
>       iboxOpRun [_,N x    ,_,_] = Left x

>   imapBoxOp :: Op
>   imapBoxOp = Op
>     { opName = "imapBoxOp"
>     , opArity = 6
>     , opTyTel = mapBoxOpTy
>     , opRun = mapBoxOpRun
>     , opSimp = \_ _ -> empty
>     } where
>       mapBoxOpTy = 
>         "ii" :<: SET :-: \ii ->
>         "d" :<: IDESC ii :-: \d ->
>         "x" :<: ARR ii SET :-: \x ->
>         let sigiix = SIGMA ii (L (HF "i" $ \i -> x $$ A i)) in
>           "bp" :<: ARR sigiix SET :-: \bp ->
>           "p" :<: (PI sigiix (L (HF "t" $ \t -> bp $$ A t))) :-: \p ->
>           "v" :<: (idescOp @@ [ii,d,x]) :-: \v ->
>           Ret $ idescOp @@ [sigiix,iboxOp @@ [ii,d,x,v],bp]
>       mapBoxOpRun :: [VAL] -> Either NEU VAL
>       mapBoxOpRun [IDONE _,x,bp,p,v] = Right VOID
>       mapBoxOpRun [IARG a d,x,bp,p,v] = Right $ 
>         imapBoxOp @@ [d $$ (A (v $$ Fst)),x,bp,p,v $$ Snd]
>       mapBoxOpRun [IIND h hi d,x,bp,p,v] = Right $ 
>         PAIR (L (HF "x" $ \x -> p $$ A (PAIR (hi $$ A x) (v $$ Fst $$ A x)))) 
>              (imapBoxOp @@ [d,x,bp,p,v $$ Snd]) 
>       mapBoxOpRun [IIND1 i d,x,bp,p,v] = Right $ 
>         PAIR (p $$ A (PAIR i (v $$ Fst))) (imapBoxOp @@ [d,x,bp,p,v $$ Snd]) 
>       mapBoxOpRun [N d    ,_, _,_,_] = Left d

>   ielimOp :: Op
>   ielimOp = Op
>     { opName = "ielimOp"
>     , opArity = 6
>     , opTyTel = elimOpTy
>     , opRun = elimOpRun
>     , opSimp = \_ _ -> empty
>     } where
>       elimOpTy = 
>         "ii" :<: SET :-: \ii ->
>         "d" :<: (ARR ii (IDESC ii)) :-: \d ->
>         "i" :<: ii :-: \i ->
>         "v" :<: (IMU Nothing ii d i) :-: \v ->
>         "bp" :<: (ARR (SIGMA ii (L (HF "i'" $ \i' -> IMU Nothing ii d i')))
>                       SET) 
>                    :-: \bp ->
>         "m" :<: 
>           (pity ("i'" :<: ii :-: \i' ->
>                  "x" :<: (idescOp @@ 
>                            [ ii , d $$ A i'
>                            , L $ HF "i''" $ \i'' -> IMU Nothing ii d i''
>                            ]) :-: \x ->
>                  "hs" :<: (idescOp @@ 
>                             [ SIGMA ii (L $ HF "i" $ \i -> IMU Nothing ii d i) 
>                             , iboxOp @@
>                                  [ ii , d $$ A i'
>                                  , L $ HF "i''" $ \i'' -> IMU Nothing ii d i''
>                                  , x
>                                  ]
>                             , bp 
>                             ]) :-: \hs ->
>                  Ret (bp $$ A (PAIR i' (CON x))))) :-: \m ->
>          Ret (bp $$ A (PAIR i v))
>       elimOpRun :: [VAL] -> Either NEU VAL
>       elimOpRun [ii,d,i,CON x,bp,m] = Right $ 
>         m $$ A i $$ A x 
>           $$ A (imapBoxOp @@ 
>                   [ ii , d $$ A i , L $ HF "i'" $ \i' -> IMU Nothing ii d i'
>                   , bp , L $ HF "t" $ \t -> 
>                            elimOp @@ [ii,d,t $$ Fst,t $$ Snd,bp,m] 
>                   , x
>                   ])
>       elimOpRun [_,N x, _,_] = Left x

