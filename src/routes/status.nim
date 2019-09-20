import asyncdispatch, strutils, sequtils, uri

import jester

import router_utils
import ".."/[api, prefs, types, formatters, agents]
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

      let conversation = await getTweet(@"name", @"id", getAgent())
      if conversation == nil or conversation.tweet.id.len == 0:
        if conversation != nil and conversation.tweet.tombstone.len > 0:
          resp Http404, showError(conversation.tweet.tombstone, cfg.title)
        else:
          resp Http404, showError("Tweet not found", cfg.title)

      let path = getPath()
      let title = pageTitle(conversation.tweet.profile)
      let desc = conversation.tweet.text
      let html = renderConversation(conversation, prefs, path)

      if conversation.tweet.video.isSome():
        let thumb = get(conversation.tweet.video).thumb
        let vidUrl = getVideoEmbed(conversation.tweet.id)
        resp renderMain(html, prefs, cfg.title, title, desc, path, images = @[thumb],
                        `type`="video", video=vidUrl)
      elif conversation.tweet.gif.isSome():
        let thumb = get(conversation.tweet.gif).thumb
        let vidUrl = getVideoEmbed(conversation.tweet.id)
        resp renderMain(html, prefs, cfg.title, title, desc, path, images = @[thumb],
                        `type`="video", video=vidUrl)
      else:
        resp renderMain(html, prefs, cfg.title, title, desc, path,
                        images=conversation.tweet.photos, `type`="photo")

    get "/@name/status/@id/photo/1":
      redirect("/$1/status/$2" % [@"name", @"id"])

    get "/i/web/status/@id":
      redirect("/i/status/" & @"id")
