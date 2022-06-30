# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, tables, asyncfutures, sequtils
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
        path = getPath()
        article = await getGraphArticle(@"id")

      let tweets = article
        .entities
        .filterIt(it.entityType == ArticleEntityType.tweet)
        .mapIt(getTweet(it.tweetId))
        .all
        .await
        .filterIt(it != nil)
        .mapIt((it.tweet.id, it.tweet))
        .toTable

      let note = renderNote(article, tweets, path, prefs)
      resp renderMain(note, request, cfg, prefs, titleText=article.title)
