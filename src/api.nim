# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, httpclient, uri, strutils, sequtils, sugar
import packedjson
import types, query, formatters, consts, apiutils, parser
import experimental/parser as newParser

proc getGraphUser*(username: string): Future[User] {.async.} =
  if username.len == 0: return
  let
    variables = """{
      "screen_name": "$1",
      "withSafetyModeUserFields": false,
      "withSuperFollowsUserFields": false
    }""" % [username]
    js = await fetchRaw(graphUser ? {"variables": variables}, Api.userScreenName)
  result = parseGraphUser(js)

proc getGraphUserById*(id: string): Future[User] {.async.} =
  if id.len == 0 or id.any(c => not c.isDigit): return
  let
    variables = """{"userId": "$1", "withSuperFollowsUserFields": true}""" % [id]
    js = await fetchRaw(graphUserById ? {"variables": variables}, Api.userRestId)
  result = parseGraphUser(js)

proc getGraphListBySlug*(name, list: string): Future[List] {.async.} =
  let
    variables = %*{"screenName": name, "listSlug": list, "withHighlightedLabel": false}
    url = graphListBySlug ? {"variables": $variables}
  result = parseGraphList(await fetch(url, Api.listBySlug))

proc getGraphList*(id: string): Future[List] {.async.} =
  let
    variables = %*{"listId": id, "withHighlightedLabel": false}
    url = graphList ? {"variables": $variables}
  result = parseGraphList(await fetch(url, Api.list))

proc getGraphListMembers*(list: List; after=""): Future[Result[User]] {.async.} =
  if list.id.len == 0: return
  var
    variables = %*{
      "listId": list.id,
      "withSuperFollowsUserFields": false,
      "withBirdwatchPivots": false,
      "withDownvotePerspective": false,
      "withReactionsMetadata": false,
      "withReactionsPerspective": false,
      "withSuperFollowsTweetFields": false
    }
  if after.len > 0:
    variables["cursor"] = % after
  let url = graphListMembers ? {"variables": $variables}
  result = parseGraphListMembers(await fetchRaw(url, Api.listMembers), after)

proc getListTimeline*(id: string; after=""): Future[Timeline] {.async.} =
  if id.len == 0: return
  let
    ps = genParams({"list_id": id, "ranking_mode": "reverse_chronological"}, after)
    url = listTimeline ? ps
  result = parseTimeline(await fetch(url, Api.timeline), after)

proc getTimeline*(id: string; after=""; replies=false): Future[Timeline] {.async.} =
  if id.len == 0: return
  let
    ps = genParams({"userId": id, "include_tweet_replies": $replies}, after)
    url = timeline / (id & ".json") ? ps
  result = parseTimeline(await fetch(url, Api.timeline), after)

proc getMediaTimeline*(id: string; after=""): Future[Timeline] {.async.} =
  if id.len == 0: return
  let url = mediaTimeline / (id & ".json") ? genParams(cursor=after)
  result = parseTimeline(await fetch(url, Api.timeline), after)

proc getPhotoRail*(name: string): Future[PhotoRail] {.async.} =
  if name.len == 0: return
  let
    ps = genParams({"screen_name": name, "trim_user": "true"},
                   count="18", ext=false)
    url = photoRail ? ps
  result = parsePhotoRail(await fetch(url, Api.timeline))

proc getSearch*[T](query: Query; after=""): Future[Result[T]] {.async.} =
  when T is User:
    const
      searchMode = ("result_filter", "user")
      parse = parseUsers
      fetchFunc = fetchRaw
  else:
    const
      searchMode = ("tweet_search_mode", "live")
      parse = parseTimeline
      fetchFunc = fetch

  let q = genQueryParam(query)
  if q.len == 0 or q == emptyQuery:
    return Result[T](beginning: true, query: query)

  let url = search ? genParams(searchParams & @[("q", q), searchMode], after)
  try:
    result = parse(await fetchFunc(url, Api.search), after)
    result.query = query
  except InternalError:
    return Result[T](beginning: true, query: query)

proc getGraphTweet(id: string; after=""): Future[Conversation] {.async.} =
  if id.len == 0: return
  let
    cursor = if after.len > 0: "\"cursor\":\"$1\"," % after else: ""
    variables = tweetVariables % [id, cursor]
    params = {"variables": variables, "features": tweetFeatures}
    js = await fetch(graphTweet ? params, Api.tweetDetail)
  result = parseGraphConversation(js, id)

proc getReplies*(id, after: string): Future[Result[Chain]] {.async.} =
  result = (await getGraphTweet(id, after)).replies
  result.beginning = after.len == 0

proc getTweet*(id: string; after=""): Future[Conversation] {.async.} =
  result = await getGraphTweet(id)
  if after.len > 0:
    result.replies = await getReplies(id, after)

proc getStatus*(id: string): Future[Tweet] {.async.} =
  let url = status / (id & ".json") ? genParams()
  result = parseStatus(await fetch(url, Api.status))

proc resolve*(url: string; prefs: Prefs): Future[string] {.async.} =
  let client = newAsyncHttpClient(maxRedirects=0)
  try:
    let resp = await client.request(url, HttpHead)
    result = resp.headers["location"].replaceUrls(prefs)
  except:
    discard
  finally:
    client.close()
