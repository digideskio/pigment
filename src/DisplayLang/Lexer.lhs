Lexer {#sec:DisplayLang.Lexer}
=====

The lexical structure is extremely simple. The reason is that Cochon
being an interactive theorem prover, its inputs will be straightforward,
1-dimension terms. Being interactive, our user is also more interested
in knowing where she did a mistake, rather than having the ability to
write terms in 3D.

We want to recognize “valid” identifiers, and keywords, with all of this
structures by brackets. Interestingly, we only consider correctly paired
brackets: we never use left-over brackets, and it is much simpler to
work with well-parenthesized expressions when parsing terms. Brackets
are round, square, or curly, and you can make fancy brackets by wedging
an identifier between open-and-bar, or bar-and-close without whitespace.
Sequences of non-whitespace are identifiers unless they're keywords.

> {-# OPTIONS_GHC -F -pgmF she #-}
> {-# LANGUAGE GADTs, TypeSynonymInstances #-}
> module DisplayLang.Lexer where
> import Control.Applicative
> import Data.List
> import Data.Char
> import Kit.Parsley

What are tokens?
----------------

We lex into tokens, classified as follows.

> data Token
>   =  Identifier String                    -- identifiers
>   |  Keyword Keyword                      -- keywords
>   |  Brackets Bracket [Token]             -- bracketted tokens
>      deriving (Eq, Show)

Brackets are the structuring tokens. We have:

> data Bracket
>   =  Round  | RoundB String    -- `(` or `(foo|`
>   |  Square | SquareB String   -- `[` or `[foo|`
>   |  Curly  | CurlyB String    -- `{` or `{foo|`
>      deriving (Eq, Show)

As we are very likely to look at our tokens all too often, let us
implement a function to crush tokens down to strings.

> crushToken :: Token -> String
> crushToken (Identifier s) = s
> crushToken (Keyword s) = key s
> crushToken (Brackets bra toks) = showOpenB bra ++
>     (intercalate " " (map crushToken toks)) ++ showCloseB bra
>   where
>     showOpenB   Round        = "("
>     showOpenB   Square       = "["
>     showOpenB   Curly        = "{"
>     showOpenB   (RoundB s)   = "(" ++ s ++ "|"
>     showOpenB   (SquareB s)  = "[" ++ s ++ "|"
>     showOpenB   (CurlyB s)   = "{" ++ s ++ "|"
>     showCloseB  Round        = ")"
>     showCloseB  Square       = "]"
>     showCloseB  Curly        = "}"
>     showCloseB  (RoundB s)   = "|" ++ s ++ ")"
>     showCloseB  (SquareB s)  = "|" ++ s ++ "]"
>     showCloseB  (CurlyB s)   = "|" ++ s ++ "}"

Lexer {#lexer}
-----

We implement the tokenizer as a `Parsley` on `Char`s. That's a cheap
solution for what we have to do. The previous implementation was running
other the string of characters, wrapped in a `StateT` monad transformer.

A token is either a bracketted expression, a keyword, or, failing all
that, an identifier. Hence, we can recognize a token with the following
parser:

> parseToken :: Parsley Char Token
> parseToken = (|id parseBrackets
>               |id parseKeyword
>               |id parseIdent
>               |)

Tokenizing an input string then simply consists in matching a bunch of
token separated by spaces. For readability, we are also glutton in
spaces the user may have put before and after the tokens.

> tokenize :: Parsley Char [Token]
> tokenize = spaces *> pSep spaces parseToken <* spaces

In the following, we implement these combinators in turn: `spaces`,
|parseIdent|, `parseKeyword`, and `parseBrackets`.

Lexing spaces

A space is one of the following character:

> space :: String
> space = " \n\r\t"

So, we look for `many` of them:

> spaces :: Parsley Char ()
> spaces = (many $ tokenFilter (flip elem space)) *> pure ()

Parsing words

As an intermediary step before keyword, identifier, and brackets, let us
introduce a parser for words. A word is any non-empty string of
characters that doesn't include a space, a bracketting symbol, or one of
the protected symbols. A protected symbol is, simply, a one-character
symbol which can be prefix or suffix a word, but will not be merged into
the parsed word. For example, “foo,” lexes into first `Idenfitier foo`
then `Keyword ,`. In `Parsley`, this translates to:

> parseWord :: Parsley Char String
> parseWord = (|id (some $ tokenFilter (\t -> not $ elem t $ space ++ bracketChars ++ protected))
>              |(: []) (tokenFilter (flip elem protected))|)
>     where protected = ",`';"

As we are at it, we can test for word equality, that is build a parser
matching a given word:

> wordEq :: String -> Parsley Char ()
> wordEq "" = pure ()
> wordEq word = pFilter filter parseWord
>     where filter s | s == word = Just ()
>                    | otherwise = Nothing

Equipped with `parseWord` and `wordEq`, the following lexers win a level
of abstraction, working on words instead of characters.

Lexing keywords

Keywords are slightly more involved. A keyword is one of the following
things...

> data Keyword where
>     KwMu :: Keyword
>     KwEnum  :: Keyword
>     KwPlus  :: Keyword
>     KwEqBlue :: Keyword
>     KwMonad   :: Keyword
>     KwReturn  :: Keyword
>     KwIMu :: Keyword
>     KwCall      :: Keyword
>     KwLabel     :: Keyword
>     KwLabelEnd  :: Keyword
>     KwRet       :: Keyword
>     KwNu    :: Keyword
>     KwCoIt  :: Keyword
>     KwProb       :: Keyword
>     KwProbLabel  :: Keyword
>     KwPatPi      :: Keyword
>     KwSch        :: Keyword
>     KwSchTy      :: Keyword
>     KwExpPi      :: Keyword
>     KwImpPi      :: Keyword
>     KwProp     :: Keyword
>     KwAbsurd   :: Keyword
>     KwTrivial  :: Keyword
>     KwPrf      :: Keyword
>     KwAnd      :: Keyword
>     KwArr      :: Keyword
>     KwImp      :: Keyword
>     KwAll      :: Keyword
>     KwInh      :: Keyword
>     KwWit      :: Keyword
>     KwQuotient  :: Keyword
>     KwRecord :: Keyword
>     KwRSig :: Keyword
>     KwREmpty :: Keyword
>     KwRCons :: Keyword
>     KwFst  :: Keyword
>     KwSnd  :: Keyword
>     KwSig  :: Keyword
>     KwUId  :: Keyword
>     KwTag  :: Keyword
>     KwAsc         :: Keyword
>     KwComma       :: Keyword
>     KwSemi        :: Keyword
>     KwDefn        :: Keyword
>     KwUnderscore  :: Keyword
>     KwEq          :: Keyword
>     KwBy          :: Keyword
>     KwSet         :: Keyword
>     KwPi          :: Keyword
>     KwLambda      :: Keyword
>     KwCon         :: Keyword
>     KwOut         :: Keyword
>   deriving (Bounded, Enum, Eq, Show)

...and they look like this:

> key :: Keyword -> String
> key KwMu        = "Mu"
> key KwEnum      = "Enum"
> key KwPlus      = "+"
> key KwEqBlue = "=="
> key KwMonad     = "Monad"
> key KwReturn    = "`"  -- rename me
> key KwIMu      = "IMu"
> key KwCall      = "call"
> key KwLabel     = "<"
> key KwLabelEnd  = ">"
> key KwRet       = "return"  -- rename me
> key KwNu        = "Nu"
> key KwCoIt      = "CoIt"
> key KwProb       = "Prob"
> key KwProbLabel  = "ProbLabel"
> key KwPatPi      = "PatPi"
> key KwSch        = "Sch"
> key KwSchTy      = "SchTy"
> key KwExpPi      = "ExpPi"
> key KwImpPi      = "ImpPi"
> key KwProp      = "Prop"
> key KwAbsurd    = "FF"
> key KwTrivial   = "TT"
> key KwPrf       = ":-"
> key KwAnd       = "&&"
> key KwArr       = "->"
> key KwImp       = "=>"
> key KwAll       = "All"
> key KwInh       = "Inh"
> key KwWit       = "wit"
> key KwQuotient  = "Quotient"
> key KwRecord        = "Rec"
> key KwRSig          = "RSig"
> key KwREmpty        = "REmpty"
> key KwRCons         = "RCons"
> key KwFst       = "!"
> key KwSnd       = "-"
> key KwSig       = "Sig"
> key KwUId       = "UId"
> key KwTag       = "'"
> key KwAsc         = ":"
> key KwComma       = ","
> key KwSemi        = ";"
> key KwDefn        = ":="
> key KwUnderscore  = "_"
> key KwEq          = "="
> key KwBy          = "<="

> key KwSet         = "Set"
> key KwPi          = "Pi"
> key KwLambda      = "\\"
> key KwCon         = "con"
> key KwOut         = "%"

    key k = error (“key: missing keyword ” ++ show k)

It is straightforward to make a translation table, `keywords`:

> keywords :: [(String, Keyword)]
> keywords = map (\k -> (key k, k)) (enumFromTo minBound maxBound)

To implement `parseKeyword`, we can simply filter by words that can be
found in the `keywords` list.

> parseKeyword :: Parsley Char Token
> parseKeyword = pFilter (\t -> fmap (Keyword . snd) $ find ((t ==) . fst) keywords) parseWord

Lexing identifiers

Hence, parsing an identifier simply consists in successfully parsing a
word – which is not a keyword – and saying “oh! it's an `Identifier`”.

> parseIdent = (|id (%parseKeyword%) (|)
>               |Identifier parseWord |)

Lexing brackets

Brackets, open and closed, are one of the following.

> openBracket, closeBracket, bracketChars :: String
> openBracket = "([{"
> closeBracket = "}])"
> bracketChars = "|" ++ openBracket ++ closeBracket

Parsing brackets, as you would expect, requires a monad: we're not
context-free my friend. This is slight variation around the |pLoop|
combinator.

First, we use `parseOpenBracket` to match an opening bracket, and get
it's code. Thanks to this code, we can already say that we hold a
|Brackets|. We are left with tokenizing the content of the bracket, up
to parsing the corresponding closing bracket.

Parsing the closing bracket is made slightly more complex by the
presence of fancy brackets: we have to match the fancy name of the
opening bracket with the one of the closing bracket.

> parseBrackets :: Parsley Char Token
> parseBrackets = do
>   bra <- parseOpenBracket
>   (|(Brackets bra)
>      (|id tokenize (%parseCloseBracket bra %) |) |)
>     where parseOpenBracket :: Parsley Char Bracket
>           parseOpenBracket = (|id (% tokenEq '(' %)
>                                     (|RoundB possibleWord (% tokenEq '|' %)
>                                      |Round (% spaces %)|)
>                               |id (% tokenEq '[' %)
>                                     (|SquareB possibleWord (% tokenEq '|' %)
>                                      |Square (% spaces %)|)
>                               |id (% tokenEq '{' %)
>                                     (|CurlyB possibleWord (% tokenEq '|' %)
>                                      |Curly (% spaces %)|)
>                               |)
>           parseCloseBracket :: Bracket -> Parsley Char ()
>           parseCloseBracket Round = tokenEq ')'
>           parseCloseBracket Square = tokenEq ']'
>           parseCloseBracket Curly = tokenEq '}'
>           parseCloseBracket (RoundB s) = matchBracketB s ')'
>           parseCloseBracket (SquareB s) = matchBracketB s ']'
>           parseCloseBracket (CurlyB s) = matchBracketB s '}'
>           parseBracket x = tokenFilter (flip elem x)
>           matchBracketB s bra = (|id ~ () (% tokenEq '|' %)
>                                           (% wordEq s %)
>                                           (% tokenEq bra %) |)
>           possibleWord = parseWord <|> pure ""

Abstracting tokens
------------------

As we are very likely to use these tokens in a parser, let us readily
define parser combinators for them. Hence, looking for a given keyword
is not more difficult than that:

> keyword :: Keyword -> Parsley Token ()
> keyword s = tokenEq (Keyword s)

And we can match any keyword (though we rarely want to) using:

> anyKeyword :: Parsley Token Keyword
> anyKeyword = pFilter filterKeyword nextToken
>     where filterKeyword (Keyword k)  = Just k
>           filterKeyword _            = Nothing

Parsing an identifier or a number is as simple as:

> ident :: Parsley Token String
> ident = pFilter filterIdent nextToken
>     where filterIdent (Identifier s) | not (isDigit $ head s) = Just s
>           filterIdent _ = Nothing

> digits :: Parsley Token String
> digits = pFilter filterInt nextToken
>     where filterInt (Identifier s) | all isDigit s = Just s
>           filterInt _ = Nothing

Occasionally we may want to match a specific identifier:

> identEq :: String -> Parsley Token ()
> identEq s = ident >>= pGuard . (== s)

Finally, we can match a bracketted expression and use a specific parser
for the bracketted tokens:

> bracket :: Bracket -> Parsley Token x -> Parsley Token x
> bracket bra p = pFilter filterBra nextToken
>     where filterBra (Brackets bra' toks) | bra == bra' =
>               either (\_ ->Nothing) Just $ parse p toks
>           filterBra _ = Nothing
