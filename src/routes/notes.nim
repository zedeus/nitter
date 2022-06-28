# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch
import jester, karax/vdom
import ".."/[types, api]
import ../views/[notes, tweet, general]
import router_utils

export api, notes, vdom, tweet, general, router_utils

proc createNotesRouter*(cfg: Config) =
  router notes:
    get "/i/notes/@id":
      let
        prefs = cookiePrefs()
        article = await getGraphArticle(@"id")
        note = renderNote(article, prefs)
      resp renderMain(note, request, cfg, prefs, titleText=article.title)
