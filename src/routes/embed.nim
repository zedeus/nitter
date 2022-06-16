# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, strutils, strformat, options
import jester, karax/vdom
import ".."/[types, api]
import ../views/[embed, tweet, general]
import router_utils

export api, embed, vdom, tweet, general, router_utils

proc createEmbedRouter*(cfg: Config) =
  router embed:
    get "/i/videos/tweet/@id":
      let convo = await getTweet(@"id")
      if convo == nil or convo.tweet == nil or convo.tweet.video.isNone:
        resp Http404

      resp renderVideoEmbed(convo.tweet, cfg, request)

    get "/@user/status/@id/embed":
      let
        convo = await getTweet(@"id")
        prefs = cookiePrefs()
        path = getPath()

      if convo == nil or convo.tweet == nil:
        resp Http404

      resp renderTweetEmbed(convo.tweet, path, prefs, cfg, request)

    get "/embed/Tweet.html":
      let id = @"id"

      if id.len > 0:
        redirect(&"/i/status/{id}/embed")
      else:
        resp Http404
