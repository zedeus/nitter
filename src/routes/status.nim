import asyncdispatch, strutils, sequtils, uri

import jester

import router_utils
import ".."/[api, types, formatters, agents]
import ../views/[general, status]

export uri, sequtils
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
        halt Http404, showError(error, cfg)

      let
        title = pageTitle(conversation.tweet.profile)
        desc = conversation.tweet.text
        html = renderConversation(conversation, prefs, getPath())

      if conversation.tweet.video.isSome():
        let thumb = get(conversation.tweet.video).thumb
        let vidUrl = getVideoEmbed(conversation.tweet.id)
        resp renderMain(html, request, cfg, title, desc, images = @[thumb],
                        `type`="video", video=vidUrl)
      elif conversation.tweet.gif.isSome():
        let thumb = get(conversation.tweet.gif).thumb
        let vidUrl = getVideoEmbed(conversation.tweet.id)
        resp renderMain(html, request, cfg, title, desc, images = @[thumb],
                        `type`="video", video=vidUrl)
      else:
        resp renderMain(html, request, cfg, title, desc,
                        images=conversation.tweet.photos, `type`="photo")

    get "/@name/status/@id/photo/@i":
      redirect("/$1/status/$2" % [@"name", @"id"])

    get "/@name/status/@id/video/@i":
      redirect("/$1/status/$2" % [@"name", @"id"])

    get "/@name/statuses/@id":
      redirect("/$1/status/$2" % [@"name", @"id"])

    get "/i/web/status/@id":
      redirect("/i/status/" & @"id")
