import asyncdispatch, strutils, sequtils, uri, options
import jester
import ".."/[types, api], ../views/embed

export embed

proc createEmbedRouter*(cfg: Config) =
  router embed:
    get "/i/videos/tweet/@id":
      let convo = await getTweet(@"id")
      if convo == nil or convo.tweet == nil or convo.tweet.video.isNone:
        resp Http404

      resp renderVideoEmbed(cfg, convo.tweet)
