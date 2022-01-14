# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, strutils, options
import jester, karax/vdom
import ".."/[types, api], ../views/[embed, tweet, general]
import router_utils

export api, embed, vdom
export tweet, general
export router_utils

proc createEmbedRouter*(cfg: Config) =
  router embed:
    get "/i/videos/tweet/@id":
      let convo = await getTweet(@"id")
      if convo == nil or convo.tweet == nil or convo.tweet.video.isNone:
        resp Http404

      resp renderVideoEmbed(cfg, convo.tweet)

    get "/@user/status/@id/embedded":
      let
        tweet = (await getTweet(@"id")).tweet
        prefs = cookiePrefs()
        path = getPath()

      resp $renderEmbeddedTweet(tweet, cfg, prefs, path)
