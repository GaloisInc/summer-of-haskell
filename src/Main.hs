{-# LANGUAGE OverloadedStrings #-}
import           Data.Monoid      ((<>))
import           Hakyll
import           System.FilePath  (joinPath, splitPath, takeBaseName)
import qualified Text.Pandoc      as Pandoc
import qualified Text.Pandoc.Walk as Pandoc.Walk

main :: IO ()
main = hakyllWith sohConfiguration $ do
    match "style/style.css" $ do
        route idRoute
        compile compressCssCompiler

    match "images/*" $ do
        route idRoute
        compile copyFileCompiler

    let simplePages =
            [ "content/index.md"
            , "content/faq.md"
            , "content/contact.md"
            ]

    match (fromList simplePages) $ do
        route $ dropContentRoute `composeRoutes` setExtension "html"
        compile $
            anchorsPandocCompiler >>=
            loadAndApplyTemplate "templates/default.html" defaultContext >>=
            relativizeUrls

    match "content/ideas.html" $ do
        route $ dropContentRoute `composeRoutes` setExtension "html"
        compile $
            getResourceString >>=
            applyAsTemplate ideasContext >>=
            loadAndApplyTemplate "templates/default.html" defaultContext >>=
            relativizeUrls

    match "content/ideas/*" $ compile pandocCompiler

    match "templates/*" $ compile templateCompiler

sohConfiguration :: Configuration
sohConfiguration = defaultConfiguration
    { deployCommand = "rsync --checksum -ave 'ssh -p 2222' \
                      \docs/* jaspervdj@jaspervdj.be:jaspervdj.be/tmp/xeShae1h-soh"
    , destinationDirectory = "docs"
    }

-- | Drop the `content/` part from a route.
dropContentRoute :: Routes
dropContentRoute = customRoute $ \ident ->
    let path0 = toFilePath ident in
    case splitPath path0 of
        "content/" : path1 -> joinPath path1
        _                  -> path0

-- | Our own pandoc compiler which adds anchors automatically.
anchorsPandocCompiler :: Compiler (Item String)
anchorsPandocCompiler =
    pandocCompilerWithTransform Pandoc.def Pandoc.def addAnchors

-- | Modifie a headers to add an extra anchor which links to the header.  This
-- allows you to easily copy an anchor link to a header.
addAnchors :: Pandoc.Pandoc -> Pandoc.Pandoc
addAnchors =
    Pandoc.Walk.walk addAnchor
  where
    addAnchor :: Pandoc.Block -> Pandoc.Block
    addAnchor (Pandoc.Header level attr@(id_, _, _) content) =
        Pandoc.Header level attr $ content ++
            [Pandoc.Link ("", ["anchor"], []) [Pandoc.Str "🔗"] ('#' : id_, "")]
    addAnchor block = block

-- | Context for an individual "idea".
ideaContext :: Context String
ideaContext =
    field "slug" (\item -> do
        return $ takeBaseName $ toFilePath $ itemIdentifier item) <>
    defaultContext

-- | Context for the ideas page.
ideasContext :: Context String
ideasContext =
    listField "ideas" ideaContext (loadAll "content/ideas/*") <>
    defaultContext
