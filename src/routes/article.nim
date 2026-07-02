# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, tables, strutils
import jester, karax/vdom
import ".."/[types, api]
import ../views/[article, general]
import router_utils

export api, article, vdom, general, router_utils

proc createArticleRouter*(cfg: Config) =
  router articleRoute:
    get "/i/article/@id":
      cond @"id".allCharsInSet(Digits)

      let article = await getGraphArticle(@"id")
      if article == nil:
        resp Http404, showError("Article not found", cfg)

      var tweetIds: seq[string]
      for e in article.entities.values:
        if e.kind == "TWEET":
          tweetIds.add e.tweetId

      var tweets = initTable[int64, Tweet]()
      if tweetIds.len > 0:
        try:
          for t in await getGraphTweetResults(tweetIds):
            tweets[t.id] = t
        except CatchableError:
          discard

      let
        prefs = requestPrefs()
        path = getPath()
        html = renderArticle(article, tweets, path, prefs, @"id")
        twitterUrl = "https://x.com/" & article.user.username & "/article/" & @"id"
      resp renderMain(html, request, cfg, prefs, titleText=article.title,
                      twitterLink=twitterUrl)

    get "/@name/article/@id/?":
      cond '.' notin @"name"
      cond @"id".allCharsInSet(Digits)
      redirect("/i/article/" & @"id")

    get "/@name/status/@id/article":
      cond '.' notin @"name"
      cond @"id".allCharsInSet(Digits)
      redirect("/i/article/" & @"id")
