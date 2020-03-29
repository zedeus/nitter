import asyncdispatch, strutils, sequtils, uri, options

import jester

import router_utils
import ".."/[api, types, formatters, agents]
import ../views/[general, status]

export uri, sequtils, options
export router_utils
export api, formatters, agents
export status

proc createStatusRouter*(cfg: Config) =
  router status:
    get "/@name/status/@id":
      cond '.' notin @"name"
      let prefs = cookiePrefs()

      let conversation = await getTweet(@"name", @"id", @"max_position", getAgent())
      if conversation == nil or conversation.tweet.id == 0:
        var error = "Tweet not found"
        if conversation != nil and conversation.tweet.tombstone.len > 0:
          error = conversation.tweet.tombstone
        resp Http404, showError(error, cfg)

      var
        title = pageTitle(conversation.tweet)
        desc = conversation.tweet.text
        images = conversation.tweet.photos
        video = ""

      if conversation.tweet.video.isSome():
        images = @[get(conversation.tweet.video).thumb]
        video = getVideoEmbed(cfg, conversation.tweet.id)
      elif conversation.tweet.gif.isSome():
        images = @[get(conversation.tweet.gif).thumb]
        video = getGifUrl(get(conversation.tweet.gif).url)

      let html = renderConversation(conversation, prefs, getPath() & "#m")
      resp renderMain(html, request, cfg, title, desc, images=images, video=video)

    get "/@name/@s/@id/@m/?@i?":
      cond @"s" in ["status", "statuses"]
      cond @"m" in ["video", "photo"]
      redirect("/$1/status/$2" % [@"name", @"id"])

    get "/@name/statuses/@id":
      redirect("/$1/status/$2" % [@"name", @"id"])

    get "/i/web/status/@id":
      redirect("/i/status/" & @"id")
