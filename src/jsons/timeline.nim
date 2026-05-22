# SPDX-License-Identifier: AGPL-3.0-only
import json, asyncdispatch, strutils, sequtils, uri, options, times

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

proc formatMediaAsJson*(m: Media): JsonNode =
  case m.kind
  of photoMedia:
    return %*{"type": "photo", "url": m.photo.url, "altText": m.photo.altText}
  of videoMedia:
    var variants = newJArray()
    for v in m.video.variants:
      variants.add %*{
        "contentType": $v.contentType,
        "url": v.url,
        "bitrate": v.bitrate,
        "resolution": v.resolution
      }
    return %*{
      "type": "video",
      "durationMs": m.video.durationMs,
      "url": m.video.url,
      "thumb": m.video.thumb,
      "available": m.video.available,
      "reason": m.video.reason,
      "title": m.video.title,
      "description": m.video.description,
      "variants": variants
    }
  of gifMedia:
    return %*{"type": "gif", "url": m.gif.url, "thumb": m.gif.thumb, "altText": m.gif.altText}

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
      "quotes": tweet.stats.quotes,
      "views": tweet.stats.views
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
    "media": (if tweet.media.len > 0: %tweet.media.map(formatMediaAsJson) else: newJNull()),
    "history": (if tweet.history.len > 0: %tweet.history else: newJNull()),
    "note": (if tweet.note.len > 0: %tweet.note else: newJNull()),
    "isAd": %tweet.isAd,
    "isAI": %tweet.isAI
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
    get "/api/i/user/@user_id":
      cond @"user_id".len > 0
      let username = await getCachedUsername(@"user_id")
      if username.len > 0:
        respJsonSuccess formatUserName(username)
      else:
        respJsonError("User not found", "not_found", Http404)

    get "/api/@name/profile":
      cond @"name" notin ["pic", "gif", "video", "search", "settings", "login",
          "intent", "i"]
      let
        prefs = requestPrefs()
        names = getNames(@"name")

      var query = request.getQuery("", @"name", prefs)
      if names.len != 1:
        query.fromUser = names

      var profile = await fetchProfile("", query, skipRail = false)
      if profile.user.username.len == 0: respJsonError("User not found", "not_found", Http404)

      respJsonSuccess formatProfileAsJson(profile)

    get "/api/@name/?@tab?/?":
      cond '.' notin @"name"
      cond @"name" notin ["pic", "gif", "video", "search", "settings", "login", "intent", "i"]
      cond @"name".allCharsInSet({'a'..'z', 'A'..'Z', '0'..'9', '_', ','})
      cond @"tab" in ["with_replies", "media", "search", ""]
      let
        prefs = requestPrefs()
        after = getCursor()
        names = getNames(@"name")

      var query = request.getQuery(@"tab", @"name", prefs)
      if names.len != 1:
        query.fromUser = names

      if query.fromUser.len != 1:
        var timeline = await getGraphTweetSearch(query, after)
        if timeline.content.len == 0: respJsonError("No results found", "no_results", Http200)
        timeline.beginning = true
        respJsonSuccess formatTimelineAsJson(timeline)
      else:
        var profile = await fetchProfile(after, query, skipRail = true)
        if profile.tweets.content.len == 0: respJsonError("User not found", "not_found", Http404)
        profile.tweets.beginning = true
        respJsonSuccess formatTimelineAsJson(profile.tweets)
