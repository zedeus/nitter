# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, httpclient, uri, strutils, sequtils, sugar, tables
import packedjson
import types, query, formatters, consts, apiutils, parser
import experimental/parser as newParser

# Helper to generate params object for GraphQL requests
proc genParams(variables: string; fieldToggles = ""): seq[(string, string)] =
  result.add ("variables", variables)
  result.add ("features", gqlFeatures)
  if fieldToggles.len > 0:
    result.add ("fieldToggles", fieldToggles)

proc mediaUrl(id: string; cursor: string): SessionAwareUrl =
  let
    cookieVariables = userMediaVariables % [id, cursor]
    oauthVariables = restIdVariables % [id, cursor]
  result = SessionAwareUrl(
    cookieUrl: graphUserMedia ? genParams(cookieVariables),
    oauthUrl: graphUserMediaV2 ? genParams(oauthVariables)
  )

proc userTweetsUrl(id: string; cursor: string): SessionAwareUrl =
  let
    cookieVariables = userTweetsVariables % [id, cursor]
    oauthVariables = restIdVariables % [id, cursor]
  result = SessionAwareUrl(
    # cookieUrl: graphUserTweets ? genParams(cookieVariables, fieldToggles),
    oauthUrl: graphUserTweetsV2 ? genParams(oauthVariables)
  )
  # might change this in the future pending testing
  result.cookieUrl = result.oauthUrl

proc userTweetsAndRepliesUrl(id: string; cursor: string): SessionAwareUrl =
  let
    cookieVariables = userTweetsAndRepliesVariables % [id, cursor]
    oauthVariables = restIdVariables % [id, cursor]
  result = SessionAwareUrl(
    cookieUrl: graphUserTweetsAndReplies ? genParams(cookieVariables, fieldToggles),
    oauthUrl: graphUserTweetsAndRepliesV2 ? genParams(oauthVariables)
  )

proc tweetDetailUrl(id: string; cursor: string): SessionAwareUrl =
  let
    cookieVariables = tweetDetailVariables % [id, cursor]
    oauthVariables = tweetVariables % [id, cursor]
  result = SessionAwareUrl(
    cookieUrl: graphTweetDetail ? genParams(cookieVariables, tweetDetailFieldToggles),
    oauthUrl: graphTweet ? genParams(oauthVariables)
  )

proc getGraphUser*(username: string): Future[User] {.async.} =
  if username.len == 0: return
  let
    url = graphUser ? genParams("""{"screen_name": "$1"}""" % username)
    js = await fetchRaw(url, Api.userScreenName)
  result = parseGraphUser(js)

proc getGraphUserById*(id: string): Future[User] {.async.} =
  if id.len == 0 or id.any(c => not c.isDigit): return
  let
    url = graphUserById ? genParams("""{"rest_id": "$1"}""" % id)
    js = await fetchRaw(url, Api.userRestId)
  result = parseGraphUser(js)

proc getGraphUserTweets*(id: string; kind: TimelineKind; after=""): Future[Profile] {.async.} =
  if id.len == 0: return
  let
    cursor = if after.len > 0: "\"cursor\":\"$1\"," % after else: ""
    js = case kind
      of TimelineKind.tweets:
        await fetch(userTweetsUrl(id, cursor), Api.userTweets)
      of TimelineKind.replies:
        await fetch(userTweetsAndRepliesUrl(id, cursor), Api.userTweetsAndReplies)
      of TimelineKind.media:
        await fetch(mediaUrl(id, cursor), Api.userMedia)
  result = parseGraphTimeline(js, after)

proc getGraphListTweets*(id: string; after=""): Future[Timeline] {.async.} =
  if id.len == 0: return
  let
    cursor = if after.len > 0: "\"cursor\":\"$1\"," % after else: ""
    url = graphListTweets ? genParams(restIdVariables % [id, cursor])
  result = parseGraphTimeline(await fetch(url, Api.listTweets), after).tweets

proc getGraphListBySlug*(name, list: string): Future[List] {.async.} =
  let
    variables = %*{"screenName": name, "listSlug": list}
    url = graphListBySlug ? genParams($variables)
  result = parseGraphList(await fetch(url, Api.listBySlug))

proc getGraphList*(id: string): Future[List] {.async.} =
  let
    url = graphListById ? genParams("""{"listId": "$1"}""" % id)
  result = parseGraphList(await fetch(url, Api.list))

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
  let url = graphListMembers ? genParams($variables)
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
    js = await fetch(tweetDetailUrl(id, cursor), Api.tweetDetail)
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
  let url = graphSearchTimeline ? genParams($variables)
  result = parseGraphSearch[Tweets](await fetch(url, Api.search), after)
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

  let url = graphSearchTimeline ? genParams($variables)
  result = parseGraphSearch[User](await fetch(url, Api.search), after)
  result.query = query

proc getPhotoRail*(id: string): Future[PhotoRail] {.async.} =
  if id.len == 0: return
  let js = await fetch(mediaUrl(id, ""), Api.userMedia)
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
