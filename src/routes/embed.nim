import asyncdispatch, strutils, sequtils, uri, options

import jester

import router_utils
import ".."/[api, types, agents]
import ../views/[embed]

export embed

proc createEmbedRouter*(cfg: Config) =
  router embed:
    get "/i/videos/tweet/@id":
      let tweet = Tweet(id: @"id".parseInt, video: some Video())
      await getVideo(tweet, getAgent(), "")
      resp renderVideoEmbed(cfg, tweet)
