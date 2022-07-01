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

      var tweetFutures: seq[Future[Conversation]]
      for e in article.entities:
        if e.entityType == ArticleEntityType.tweet:
          tweetFutures.add getTweet(e.tweetId)

      let convs = await tweetFutures.all

      var tweets = initTable[int64, Tweet]()
      for c in convs:
        if c != nil and c.tweet != nil:
          tweets[c.tweet.id] = c.tweet

      let note = renderNote(article, tweets, path, prefs)
      resp renderMain(note, request, cfg, prefs, titleText=article.title)
