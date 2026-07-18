# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, strutils, strformat, json
import jester, karax/vdom
import ".."/[types, api, formatters]
import ../views/[embed, tweet, general]
include "../views/oembed.nimf"
import router_utils

export api, embed, vdom, tweet, general, router_utils

proc parseTweetUrl*(url: string): tuple[username, id: string] =
  var path = url
  if path.startsWith("https://"):
    path = path[8..^1]
  elif path.startsWith("http://"):
    path = path[7..^1]

  const prefixes = ["twitter.com/", "x.com/", "mobile.twitter.com/",
                    "www.twitter.com/", "www.x.com/"]
  for prefix in prefixes:
    if path.startsWith(prefix):
      path = path[prefix.len..^1]
      let parts = path.split('/')
      if parts.len >= 3 and parts[1] == "status":
        let tweetId = parts[2].split('?')[0].split('#')[0]
        if tweetId.len > 0 and tweetId.allCharsInSet(Digits):
          return (parts[0], tweetId)
      break
  return ("", "")

proc createEmbedRouter*(cfg: Config) =
  router embed:
    get "/i/videos/tweet/@id":
      let
        tweet = await getGraphTweetResult(@"id")
        prefs = requestPrefs()

      if tweet == nil:
        resp renderErrorEmbed("Tweet not found", prefs, cfg, request)

      if not tweet.hasVideos:
        resp renderErrorEmbed("No video in tweet", prefs, cfg, request)

      resp renderVideoEmbed(tweet, cfg, request)

    get "/@user/status/@id/embed":
      let
        tweet = await getGraphTweetResult(@"id")
        prefs = requestPrefs()
        path = getPath()

      if tweet == nil:
        resp renderErrorEmbed("Tweet not found", prefs, cfg, request)

      resp renderTweetEmbed(tweet, path, prefs, cfg, request)

    get "/embed/Tweet.html":
      let id = @"id"

      if id.len > 0:
        redirect(&"/i/status/{id}/embed")
      else:
        resp Http404

    get "/api/oembed":
      let url = @"url"
      if url.len == 0:
        resp Http400, "Missing url parameter"

      let (username, tweetId) = parseTweetUrl(url)
      if username.len == 0 or tweetId.len == 0:
        resp Http400, "Invalid tweet URL"

      let tweet = await getGraphTweetResult(tweetId)
      if tweet == nil:
        resp Http404

      let
        embedUrl = getUrlPrefix(cfg) & "/" & username & "/status/" & tweetId & "/embed"
        authorUrl = getUrlPrefix(cfg) & "/" & tweet.user.username

      responseHeaders().get.add(("Access-Control-Allow-Origin", "*"))
      respJson %*{
        "version": "1.0",
        "type": "rich",
        "provider_name": cfg.title,
        "provider_url": getUrlPrefix(cfg),
        "author_name": tweet.user.fullname,
        "author_url": authorUrl,
        "url": embedUrl,
        "width": 550,
        "height": nil,
        "cache_age": "3153600000",
        "html": renderOembedIframe(embedUrl)
      }
