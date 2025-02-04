# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, httpclient, uri, strutils, sequtils, sugar
import packedjson
import types, query, formatters, consts, apiutils, parser
import experimental/parser as newParser

proc getGraphUser*(username: string): Future[User] {.async.} =
  if username.len == 0: return
  let
    variables = """{"screen_name": "$1"}""" % username
    params = {"variables": variables, "features": gqlFeatures}
    js = await fetchRaw(graphUser ? params, Api.userScreenName)
  result = parseGraphUser(js)

proc getGraphUserById*(id: string): Future[User] {.async.} =
  if id.len == 0 or id.any(c => not c.isDigit): return
  let
    variables = """{"rest_id": "$1"}""" % id
    params = {"variables": variables, "features": gqlFeatures}
    js = await fetchRaw(graphUserById ? params, Api.userRestId)
  result = parseGraphUser(js)

proc getGraphUserTweets*(id: string; kind: TimelineKind; after=""): Future[Profile] {.async.} =
  if id.len == 0: return
  let
    cursor = if after.len > 0: "\"cursor\":\"$1\"," % after else: ""
    variables = userTweetsVariables % [id, cursor]
    params = {"variables": variables, "features": gqlFeatures}
    (url, apiId) = case kind
                   of TimelineKind.tweets: (graphUserTweets, Api.userTweets)
                   of TimelineKind.replies: (graphUserTweetsAndReplies, Api.userTweetsAndReplies)
                   of TimelineKind.media: (graphUserMedia, Api.userMedia)
    js = await fetch(url ? params, apiId)
  result = parseGraphTimeline(js, "user", after)

proc getGraphListTweets*(id: string; after=""): Future[Timeline] {.async.} =
  if id.len == 0: return
  let
    cursor = if after.len > 0: "\"cursor\":\"$1\"," % after else: ""
    variables = listTweetsVariables % [id, cursor]
    params = {"variables": variables, "features": gqlFeatures}
    js = await fetch(graphListTweets ? params, Api.listTweets)
  result = parseGraphTimeline(js, "list", after).tweets

proc getGraphListBySlug*(name, list: string): Future[List] {.async.} =
  let
    variables = %*{"screenName": name, "listSlug": list}
    params = {"variables": $variables, "features": gqlFeatures}
  result = parseGraphList(await fetch(graphListBySlug ? params, Api.listBySlug))

proc getGraphList*(id: string): Future[List] {.async.} =
  let
    variables = """{"listId": "$1"}""" % id
    params = {"variables": variables, "features": gqlFeatures}
  result = parseGraphList(await fetch(graphListById ? params, Api.list))

proc getGraphListMembers*(list: List; after=""): Future[Result[User]] {.async.} =
  if list.id.len == 0: return
  var
    variables = %*{
      "listId": list.id,
      "withBirdwatchPivots": false,
      "withDownvotePerspective": false,
      "withReactionsMetadata": false,
      "withReactionsPerspective": false
    }
  if after.len > 0:
    variables["cursor"] = % after
  let url = graphListMembers ? {"variables": $variables, "features": gqlFeatures}
  result = parseGraphListMembers(await fetchRaw(url, Api.listMembers), after)

proc getGraphTweetResult*(id: string): Future[Tweet] {.async.} =
  if id.len == 0: return
  let
    variables = """{"rest_id": "$1"}""" % id
    params = {"variables": variables, "features": gqlFeatures}
    js = await fetch(graphTweetResult ? params, Api.tweetResult)
  result = parseGraphTweetResult(js)

proc getGraphTweet(id: string; after=""): Future[Conversation] {.async.} =
  if id.len == 0: return
  let
    cursor = if after.len > 0: "\"cursor\":\"$1\"," % after else: ""
    variables = tweetVariables % [id, cursor]
    params = {"variables": variables, "features": gqlFeatures}
    js = await fetch(graphTweet ? params, Api.tweetDetail)
  result = parseGraphConversation(js, id)

proc getReplies*(id, after: string): Future[Result[Chain]] {.async.} =
  result = (await getGraphTweet(id, after)).replies
  result.beginning = after.len == 0

proc getTweet*(id: string; after=""): Future[Conversation] {.async.} =
  result = await getGraphTweet(id)
  if after.len > 0:
    result.replies = await getReplies(id, after)

proc getGraphTweetSearch*(query: Query; after=""): Future[Timeline] {.async.} =
  let q = genQueryParam(query)
  if q.len == 0 or q == emptyQuery:
    return Timeline(query: query, beginning: true)

  var
    variables = %*{
      "rawQuery": q,
      "count": 20,
      "product": "Latest",
      "withDownvotePerspective": false,
      "withReactionsMetadata": false,
      "withReactionsPerspective": false
    }
  if after.len > 0:
    variables["cursor"] = % after
  let url = graphSearchTimeline ? {"variables": $variables, "features": gqlFeatures}
  result = parseGraphSearch[Tweets](await fetch(url, Api.search), after)
  result.query = query

proc getGraphUserSearch*(query: Query; after=""): Future[Result[User]] {.async.} =
  if query.text.len == 0:
    return Result[User](query: query, beginning: true)

  var
    variables = %*{
      "rawQuery": query.text,
      "count": 20,
      "product": "People",
      "withDownvotePerspective": false,
      "withReactionsMetadata": false,
      "withReactionsPerspective": false
    }
  if after.len > 0:
    variables["cursor"] = % after
    result.beginning = false

  let url = graphSearchTimeline ? {"variables": $variables, "features": gqlFeatures}
  result = parseGraphSearch[User](await fetch(url, Api.search), after)
  result.query = query

proc getPhotoRail*(id: string): Future[PhotoRail] {.async.} =
  if id.len == 0: return
  let
    variables = userTweetsVariables % [id, ""]
    params = {"variables": variables, "features": gqlFeatures}
    url = graphUserMedia ? params
  result = parseGraphPhotoRail(await fetch(url, Api.userMedia))

proc resolve*(url: string; prefs: Prefs): Future[string] {.async.} =
  let client = newAsyncHttpClient(maxRedirects=0)
  try:
    let resp = await client.request(url, HttpHead)
    result = resp.headers["location"].replaceUrls(prefs)
  except:
    discard
  finally:
    client.close()
