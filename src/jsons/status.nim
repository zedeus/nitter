# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, strutils, sequtils, uri, options, sugar

import jester, karax/vdom

import list, timeline

import ".."/routes/router_utils
import ".."/[types, formatters, api]
import ../views/[general, status]

proc formatConversationAsJson*(conv: Conversation): JsonNode =
  var beforeTweets = newJArray()
  var afterTweets = newJArray()
  var replies = newJArray()

  # Format tweets before the main tweet
  for tweet in conv.before.content:
    beforeTweets.add(formatTweetAsJson(tweet))

  # Format tweets after the main tweet
  for tweet in conv.after.content:
    afterTweets.add(formatTweetAsJson(tweet))

  # Format reply chains
  for chain in conv.replies.content:
    var chainTweets = newJArray()
    for tweet in chain.content:
      chainTweets.add(formatTweetAsJson(tweet))
    replies.add(%*{
      "tweets": chainTweets,
      "hasMore": chain.hasMore,
      "cursor": chain.cursor
    })

  return %*{
    "tweet": formatTweetAsJson(conv.tweet),
    "before": %*{
      "tweets": beforeTweets
    },
    "after": %*{
      "tweets": afterTweets,
      "hasMore": conv.after.hasMore,
      "cursor": conv.after.cursor
    },
    "replies": %*{
      "beginning": conv.replies.beginning,
      "top": conv.replies.top,
      "bottom": conv.replies.bottom,
      "chains": replies
    }
  }

proc createJsonApiStatusRouter*(cfg: Config) =
  router jsonapi_status:
    get "/@name/status/@id/?":
      cond '.' notin @"name"
      let id = @"id"

      if id.len > 19 or id.any(c => not c.isDigit):
        respJsonError Http404, "Invalid tweet ID"

      let conv = await getTweet(id, getCursor())
      if conv == nil:
        echo "nil conv"

      if conv == nil or conv.tweet == nil or conv.tweet.id == 0:
        var error = "Tweet not found"
        if conv != nil and conv.tweet != nil and conv.tweet.tombstone.len > 0:
          error = conv.tweet.tombstone
        respJsonError error

      respJsonSuccess formatConversationAsJson(conv)

    get "/@name/@s/@id/@m/?@i?":
      cond @"s" in ["status", "statuses"]
      cond @"m" in ["video", "photo"]
      redirect("/api/$1/status/$2" % [@"name", @"id"])

    get "/@name/statuses/@id/?":
      redirect("/api/$1/status/$2" % [@"name", @"id"])

    get "/i/web/status/@id":
      redirect("/api/i/status/" & @"id")

    get "/@name/thread/@id/?":
      redirect("/api/$1/status/$2" % [@"name", @"id"])
