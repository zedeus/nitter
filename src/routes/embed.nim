# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, strutils, strformat, json
import jester, karax/vdom
import ".."/[types, api, formatters]
import ../views/[embed, tweet, general]
include "../views/oembed.nimf"
import router_utils

export api, embed, vdom, tweet, general, router_utils

proc parseTweetPath(path: string): tuple[username, id: string] =
  let parts = path.split('/')
  if parts.len >= 3 and parts[1] in ["status", "statuses"]:
    let tweetId = parts[2].split('?')[0].split('#')[0]
    if tweetId.len > 0 and tweetId.allCharsInSet(Digits):
      return (parts[0], tweetId)
  return ("", "")

proc parseTweetUrl*(url: string; cfg: Config): tuple[username, id: string] =
  var path = url
  if path.startsWith("https://"):
    path = path[8..^1]
  elif path.startsWith("http://"):
    path = path[7..^1]

  const twitterPrefixes = ["twitter.com/", "x.com/", "mobile.twitter.com/",
                           "www.twitter.com/", "www.x.com/"]

  for prefix in twitterPrefixes:
    if path.startsWith(prefix):
      return parseTweetPath(path[prefix.len..^1])

  let nitterPrefix = cfg.hostname & "/"
  if path.startsWith(nitterPrefix):
    return parseTweetPath(path[nitterPrefix.len..^1])

  # Fall back: strip any hostname and try to parse as a tweet path.
  # Handles requests where the URL's host differs from cfg.hostname
  # (e.g. localhost in dev/CI, or a reverse proxy with a different domain).
  let slashPos = path.find('/')
  if slashPos > 0:
    let afterHost = path[slashPos + 1..^1]
    let parsed = parseTweetPath(afterHost)
    if parsed.username.len > 0:
      return parsed

  return ("", "")

proc createEmbedRouter*(cfg: Config) =
  router embed:
    get "/i/videos/tweet/@id":
      let
        id = @"id"
        tweet = await getTweetByRestId(id)
        prefs = requestPrefs()

      if tweet == nil:
        resp renderErrorEmbed("Tweet not found", prefs, cfg, request, tweetId=id)

      if not tweet.hasVideos:
        resp renderErrorEmbed("No video in tweet", prefs, cfg, request,
                              tweetId=id, username=tweet.user.username)

      resp renderVideoEmbed(tweet, cfg, request)

    get "/@user/status/@id/embed":
      let
        id = @"id"
        user = @"user"
        tweet = await getTweetByRestId(id)
        prefs = requestPrefs()
        path = getPath()

      if tweet == nil:
        resp renderErrorEmbed("Tweet not found", prefs, cfg, request,
                              tweetId=id, username=user)

      resp renderTweetEmbed(tweet, path, prefs, cfg, request)

    get "/embed/Tweet.html":
      let id = @"id"

      if id.len > 0:
        redirect(&"/i/status/{id}/embed")
      else:
        resp Http404

    get "/api/oembed":
      responseHeaders().get.add(("Access-Control-Allow-Origin", "*"))

      let
        url = @"url"
        format = @"format"

      if format.len > 0 and format != "json":
        resp Http501, "Only JSON format is supported"

      if url.len == 0:
        resp Http400, "Missing url parameter"

      let (username, tweetId) = parseTweetUrl(url, cfg)
      if username.len == 0 or tweetId.len == 0:
        resp Http400, "Invalid tweet URL"

      let tweet = await getTweetByRestId(tweetId)
      if tweet == nil:
        resp Http404

      let
        maxwidthParam = @"maxwidth"
        maxwidth = if maxwidthParam.len > 0:
                     try: clamp(parseInt(maxwidthParam), 220, 550)
                     except ValueError: 550
                   else: 550
        embedUrl = getUrlPrefix(cfg) & "/" & tweet.user.username & "/status/" & tweetId & "/embed"
        authorUrl = getUrlPrefix(cfg) & "/" & tweet.user.username
        title = stripHtml(tweet.text)

      var response = %*{
        "version": "1.0",
        "type": "rich",
        "provider_name": cfg.title,
        "provider_url": getUrlPrefix(cfg),
        "title": title,
        "author_name": tweet.user.fullname,
        "author_url": authorUrl,
        "url": embedUrl,
        "width": maxwidth,
        "height": newJNull(),
        "cache_age": "3153600000",
        "html": renderOembedIframe(embedUrl, maxwidth)
      }

      if tweet.media.len > 0:
        let thumbUrl = getUrlPrefix(cfg) & getPicUrl(tweet.media[0].getThumb)
        response["thumbnail_url"] = %thumbUrl
        response["thumbnail_width"] = %maxwidth
        response["thumbnail_height"] = %maxwidth

      respJson response
