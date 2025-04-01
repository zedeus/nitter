# SPDX-License-Identifier: AGPL-3.0-only
import options
import packedjson
import times

import ".."/[types]


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
  let result = %*{
    "id": tweet.id,
    "threadId": tweet.threadId,
    "replyId": tweet.replyId,
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
    "retweet": if tweet.retweet.isSome: formatTweetAsJson(get(tweet.retweet)) else: JsonTree(newJNull()),
    "attribution": if tweet.attribution.isSome: formatUserAsJson(get(tweet.attribution)) else: JsonTree(newJNull()),
    "quote": if tweet.quote.isSome: formatTweetAsJson(get(tweet.quote)) else: JsonTree(newJNull()),
    "poll": if tweet.poll.isSome: %*get(tweet.poll) else: JsonTree(newJNull()),
    "gif": if tweet.gif.isSome: %*get(tweet.gif) else: JsonTree(newJNull()),
    "video": if tweet.video.isSome: %*get(tweet.video) else: JsonTree(newJNull()),
    "photos": if tweet.photos.len > 0: %tweet.photos else: JsonTree(newJNull())
  }
  return result

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
      for tweet in thread:
        timeline.add(formatTweetAsJson(tweet))
      timeline.add(timeline)

  return %*{
    "list": %*{
      "beginning": results.beginning,
      "top": results.top,
      "bottom": results.bottom
    },
    "timeline": timeline
  }

proc formatUsersAsJson*(results: Result[User]): JsonNode =
  var users = newJArray()

  for user in results.content:
    users.add(formatUserAsJson(user))

  return %*{
    "list": %*{
      "beginning": results.beginning,
      "top": results.top,
      "bottom": results.bottom,
    },
    "users": users
  }

