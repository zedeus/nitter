# SPDX-License-Identifier: AGPL-3.0-only
import std/json
import asyncdispatch, strutils, sequtils, uri, options, times

import options
import times

import jester, karax/vdom

import ".."/routes/[router_utils, timeline]
import ".."/[types, redis_cache, formatters, query, api]

# JSON formatting functions
proc formatUserAsJson*(user: User): JsonNode =
  return %*{
    "id": user.id,
    "username": user.username,
    "fullname": user.fullname,
    "location": user.location,
    "website": user.website,
    "bio": user.bio,
    "userPic": user.userPic,
    "banner": user.banner,
    "pinnedTweet": user.pinnedTweet,
    "following": user.following,
    "followers": user.followers,
    "tweets": user.tweets,
    "likes": user.likes,
    "media": user.media,
    "verifiedType": $user.verifiedType,
    "protected": user.protected,
    "suspended": user.suspended,
    "joinDate": user.joinDate.toTime.toUnix()
  }

proc formatTweetAsJson*(tweet: Tweet): JsonNode =
  return %*{
    "id": $tweet.id,
    "threadId": $tweet.threadId,
    "replyId": $tweet.replyId,
    "user": formatUserAsJson(tweet.user),
    "text": tweet.text,
    "time": tweet.time.toTime.toUnix(),
    "reply": tweet.reply,
    "pinned": tweet.pinned,
    "hasThread": tweet.hasThread,
    "available": tweet.available,
    "tombstone": tweet.tombstone,
    "location": tweet.location,
    "source": tweet.source,
    "stats": %*{
      "replies": tweet.stats.replies,
      "retweets": tweet.stats.retweets,
      "likes": tweet.stats.likes,
      "quotes": tweet.stats.quotes
    },
    "retweet": if tweet.retweet.isSome: formatTweetAsJson(get(
        tweet.retweet)) else: newJNull(),
    "attribution": if tweet.attribution.isSome: formatUserAsJson(get(
        tweet.attribution)) else: newJNull(),
    "mediaTags": if tweet.mediaTags.len > 0: %tweet.mediaTags.map(
        formatUserAsJson) else: newJNull(),
    "quote": if tweet.quote.isSome: formatTweetAsJson(get(
        tweet.quote)) else: newJNull(),
    "card": if tweet.card.isSome: %*get(tweet.card) else: newJNull(),
    "poll": if tweet.poll.isSome: %*get(tweet.poll) else: newJNull(),
    "gif": if tweet.gif.isSome: %*get(tweet.gif) else: newJNull(),
    "video": if tweet.video.isSome: %*get(tweet.video) else: newJNull(),
    "photos": if tweet.photos.len > 0: %tweet.photos else: newJNull()
  }

proc formatTimelineAsJson*(results: Timeline): JsonNode =
  var retweets: seq[int64]
  var timeline = newJArray()

  for thread in results.content:
    if thread.len == 1:
      let tweet = thread[0]
      let retweetId = if tweet.retweet.isSome: get(tweet.retweet).id else: 0

      if retweetId in retweets or tweet.id in retweets:
        continue

      if retweetId != 0 and tweet.retweet.isSome:
        retweets &= retweetId

      timeline.add(formatTweetAsJson(tweet))
    else:
      var threadTimeline = newJArray()
      for tweet in thread:
        threadTimeline.add(formatTweetAsJson(tweet))
      timeline.add(threadTimeline)

  return %*{
    "pagination": %*{
      "beginning": results.beginning,
      "top": results.top,
      "bottom": results.bottom
    },
    "timeline": timeline
  }

proc formatUserName*(username: string): JsonNode =
  return %*{
    "username": username
  }

proc formatProfileAsJson*(profile: Profile): JsonNode =
  return %*{
    "user": formatUserAsJson(profile.user),
    "photoRail": %profile.photoRail,
    "pinned": if profile.pinned.isSome: formatTweetAsJson(get(
        profile.pinned)) else: newJNull()
  }

proc createJsonApiTimelineRouter*(cfg: Config) =
  router jsonapi_timeline:
    get "/api/i/user/@user_id/?":
      cond @"user_id".len > 0
      let username = await getCachedUsername(@"user_id")
      if username.len > 0:
        respJsonSuccess formatUserName(username)
      else:
        respJsonError "User not found"

    get "/api/@name/profile":
      cond @"name" notin ["pic", "gif", "video", "search", "settings", "login",
          "intent", "i"]
      let
        prefs = cookiePrefs()
        names = getNames(@"name")

      var query = request.getQuery("", @"name")
      if names.len != 1:
        query.fromUser = names

      var profile = await fetchProfile("", query, skipRail = false)
      if profile.user.username.len == 0: respJsonError "User not found"

      respJsonSuccess formatProfileAsJson(profile)

    get "/api/@name/?@tab?/?":
      cond '.' notin @"name"
      cond @"name" notin ["pic", "gif", "video", "search", "settings", "login",
          "intent", "i"]
      cond @"tab" in ["with_replies", "media", "search", ""]
      let
        prefs = cookiePrefs()
        after = getCursor()
        names = getNames(@"name")

      var query = request.getQuery(@"tab", @"name")
      if names.len != 1:
        query.fromUser = names

      if query.fromUser.len != 1:
        var timeline = await getGraphTweetSearch(query, after)
        if timeline.content.len == 0: respJsonError "No results found"
        timeline.beginning = true
        respJsonSuccess formatTimelineAsJson(timeline)
      else:
        var profile = await fetchProfile(after, query, skipRail = true)
        if profile.tweets.content.len == 0: respJsonError "User not found"
        profile.tweets.beginning = true
        respJsonSuccess formatTimelineAsJson(profile.tweets)
