# SPDX-License-Identifier: AGPL-3.0-only
import options
import json
import times

import ".."/[types]


# JSON formatting functions
proc formatUserAsJson*(user: User): JsonNode =
  result = %*{
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
  result = %*{
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
    }
  }

  if tweet.retweet.isSome:
    result["retweet"] = formatTweetAsJson(get(tweet.retweet))
  if tweet.attribution.isSome:
    result["attribution"] = formatUserAsJson(get(tweet.attribution))
  if tweet.quote.isSome:
    result["quote"] = formatTweetAsJson(get(tweet.quote))
  if tweet.poll.isSome:
    result["poll"] = %*get(tweet.poll)
  if tweet.gif.isSome:
    result["gif"] = %*get(tweet.gif)
  if tweet.video.isSome:
    result["video"] = %*get(tweet.video)
  if tweet.photos.len > 0:
    result["photos"] = %tweet.photos

proc formatTimelineAsJson*(results: Timeline): JsonNode =
  result = %*{
    "beginning": results.beginning,
    "top": results.top,
    "bottom": results.bottom,
    "content": newJArray()
  }

  var retweets: seq[int64]
  for thread in results.content:
    if thread.len == 1:
      let tweet = thread[0]
      let retweetId = if tweet.retweet.isSome: get(tweet.retweet).id else: 0

      if retweetId in retweets or tweet.id in retweets:
        continue

      if retweetId != 0 and tweet.retweet.isSome:
        retweets &= retweetId

      result["content"].add(formatTweetAsJson(tweet))
    else:
      var threadJson = newJArray()
      for tweet in thread:
        threadJson.add(formatTweetAsJson(tweet))
      result["content"].add(threadJson)

proc formatUsersAsJson*(results: Result[User]): JsonNode =
  result = %*{
    "beginning": results.beginning,
    "top": results.top,
    "bottom": results.bottom,
    "content": newJArray()
  }

  for user in results.content:
    result["content"].add(formatUserAsJson(user))
