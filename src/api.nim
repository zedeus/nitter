# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, httpclient, strutils, sequtils, sugar
import packedjson
import types, query, formatters, consts, apiutils, parser
import experimental/parser as newParser

# Helper to generate params object for GraphQL requests
proc genParams(variables: string; fieldToggles = ""): seq[(string, string)] =
  result.add ("variables", variables)
  result.add ("features", gqlFeatures)
  if fieldToggles.len > 0:
    result.add ("fieldToggles", fieldToggles)

proc apiUrl(endpoint, variables: string; fieldToggles = ""): ApiUrl =
  return ApiUrl(endpoint: endpoint, params: genParams(variables, fieldToggles))

proc apiReq(endpoint, variables: string; fieldToggles = ""): ApiReq =
  let url = apiUrl(endpoint, variables, fieldToggles)
  return ApiReq(cookie: url, oauth: url)

proc mediaUrl(id: string; cursor: string): ApiReq =
  result = ApiReq(
    cookie: apiUrl(graphUserMedia, userMediaVars % [id, cursor]),
    oauth: apiUrl(graphUserMediaV2, restIdVars % [id, cursor])
  )

proc userTweetsUrl(id: string; cursor: string): ApiReq =
  result = ApiReq(
    # cookie: apiUrl(graphUserTweets, userTweetsVars % [id, cursor], userTweetsFieldToggles),
    oauth: apiUrl(graphUserTweetsV2, restIdVars % [id, cursor])
  )
  # might change this in the future pending testing
  result.cookie = result.oauth

proc userTweetsAndRepliesUrl(id: string; cursor: string): ApiReq =
  let cookieVars = userTweetsAndRepliesVars % [id, cursor]
  result = ApiReq(
    cookie: apiUrl(graphUserTweetsAndReplies, cookieVars, userTweetsFieldToggles),
    oauth: apiUrl(graphUserTweetsAndRepliesV2, restIdVars % [id, cursor])
  )

proc tweetDetailUrl(id: string; cursor: string): ApiReq =
  let cookieVars = tweetDetailVars % [id, cursor]
  result = ApiReq(
    # cookie: apiUrl(graphTweetDetail, cookieVars, tweetDetailFieldToggles),
    cookie: apiUrl(graphTweet, tweetVars % [id, cursor]),
    oauth: apiUrl(graphTweet, tweetVars % [id, cursor])
  )

proc userUrl(username: string): ApiReq =
  let cookieVars = """{"screen_name":"$1","withGrokTranslatedBio":false}""" % username
  result = ApiReq(
    cookie: apiUrl(graphUser, cookieVars, tweetDetailFieldToggles),
    oauth: apiUrl(graphUserV2, """{"screen_name": "$1"}""" % username)
  )

proc getGraphUser*(username: string): Future[User] {.async.} =
  if username.len == 0: return
  let js = await fetchRaw(userUrl(username))
  result = parseGraphUser(js)

proc getGraphUserById*(id: string): Future[User] {.async.} =
  if id.len == 0 or id.any(c => not c.isDigit): return
  let
    url = apiReq(graphUserById, """{"rest_id": "$1"}""" % id)
    js = await fetchRaw(url)
  result = parseGraphUser(js)

proc getGraphUserTweets*(id: string; kind: TimelineKind; after=""): Future[Profile] {.async.} =
  if id.len == 0: return
  let
    cursor = if after.len > 0: "\"cursor\":\"$1\"," % after else: ""
    url = case kind
      of TimelineKind.tweets: userTweetsUrl(id, cursor)
      of TimelineKind.replies: userTweetsAndRepliesUrl(id, cursor)
      of TimelineKind.media: mediaUrl(id, cursor)
    js = await fetch(url)
  result = parseGraphTimeline(js, after)

proc getGraphListTweets*(id: string; after=""): Future[Timeline] {.async.} =
  if id.len == 0: return
  let
    cursor = if after.len > 0: "\"cursor\":\"$1\"," % after else: ""
    url = apiReq(graphListTweets, restIdVars % [id, cursor])
    js = await fetch(url)
  result = parseGraphTimeline(js, after).tweets

proc getGraphListBySlug*(name, list: string): Future[List] {.async.} =
  let
    variables = %*{"screenName": name, "listSlug": list}
    url = apiReq(graphListBySlug, $variables)
    js = await fetch(url)
  result = parseGraphList(js)

proc getGraphList*(id: string): Future[List] {.async.} =
  let 
    url = apiReq(graphListById, """{"listId": "$1"}""" % id)
    js = await fetch(url)
  result = parseGraphList(js)

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
  let 
    url = apiReq(graphListMembers, $variables)
    js = await fetchRaw(url)
  result = parseGraphListMembers(js, after)

proc getGraphTweetResult*(id: string): Future[Tweet] {.async.} =
  if id.len == 0: return
  let
    url = apiReq(graphTweetResult, """{"rest_id": "$1"}""" % id)
    js = await fetch(url)
  result = parseGraphTweetResult(js)

proc getGraphTweet(id: string; after=""): Future[Conversation] {.async.} =
  if id.len == 0: return
  let
    cursor = if after.len > 0: "\"cursor\":\"$1\"," % after else: ""
    js = await fetch(tweetDetailUrl(id, cursor))
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
      "query_source": "typedQuery",
      "count": 20,
      "product": "Latest",
      "withDownvotePerspective": false,
      "withReactionsMetadata": false,
      "withReactionsPerspective": false
    }
  if after.len > 0:
    variables["cursor"] = % after
  let 
    url = apiReq(graphSearchTimeline, $variables)
    js = await fetch(url)
  result = parseGraphSearch[Tweets](js, after)
  result.query = query

proc getGraphUserSearch*(query: Query; after=""): Future[Result[User]] {.async.} =
  if query.text.len == 0:
    return Result[User](query: query, beginning: true)

  var
    variables = %*{
      "rawQuery": query.text,
      "query_source": "typedQuery",
      "count": 20,
      "product": "People",
      "withDownvotePerspective": false,
      "withReactionsMetadata": false,
      "withReactionsPerspective": false
    }
  if after.len > 0:
    variables["cursor"] = % after
    result.beginning = false

  let 
    url = apiReq(graphSearchTimeline, $variables)
    js = await fetch(url)
  result = parseGraphSearch[User](js, after)
  result.query = query

proc getPhotoRail*(id: string): Future[PhotoRail] {.async.} =
  if id.len == 0: return
  let js = await fetch(mediaUrl(id, ""))
  result = parseGraphPhotoRail(js)

proc resolve*(url: string; prefs: Prefs): Future[string] {.async.} =
  let client = newAsyncHttpClient(maxRedirects=0)
  try:
    let resp = await client.request(url, HttpHead)
    result = resp.headers["location"].replaceUrls(prefs)
  except:
    discard
  finally:
    client.close()
