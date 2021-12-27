# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, strutils, options
import jester
import ".."/[types, api], ../views/embed

export api, embed

proc createEmbedRouter*(cfg: Config) =
  router embed:
    get "/i/videos/tweet/@id":
      let convo = await getTweet(@"id")
      if convo == nil or convo.tweet == nil or convo.tweet.video.isNone:
        resp Http404

      resp renderVideoEmbed(cfg, convo.tweet)
