# SPDX-License-Identifier: AGPL-3.0-only
import jester
import router_utils
import json
import ".."/[types, redis_cache, formatters, query, api]

proc getUserProfileJson*(username: string): JsonNode {.async.} = 
  let user = await getGraphUser(username)
  return %*{ "user": user }

proc getUserTweetsJson*(id: string): JsonNode {.async.} = 
  let tweets = await getGraphUserTweets(id, TimelineKind.tweets)
  let replies = await getGraphUserTweets(id, TimelineKind.replies)
  let media = await getGraphUserTweets(id, TimelineKind.media)
  return %*{ "tweets": tweets, "replies": replies, "media": media }

proc createTwitterApiRouter*(cfg: Config) =
  router debug:
    get "/api/user/@username":
      let username = @"username"
      let response = await getUserProfileJson(username)
      resp Http200, {"Content-Type": "application/json"}, response

    get "/api/user/@id/tweets":
      let id = @"id"
      let response = await getUserTweetsJson(id)    
      resp Http200, {"Content-Type": "application/json"}, response
