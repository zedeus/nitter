import asyncdispatch, httpclient, uri, strutils
import packedjson
import types, query, formatters, consts, apiutils, parser

proc getGraphProfile*(username: string): Future[Profile] {.async.} =
  let
    variables = %*{"screen_name": username, "withHighlightedLabel": true}
    js = await fetch(graphUser ? {"variables": $variables})
  result = parseGraphProfile(js, username)

proc getGraphList*(name, list: string): Future[List] {.async.} =
  let
    variables = %*{"screenName": name, "listSlug": list, "withHighlightedLabel": false}
    js = await fetch(graphList ? {"variables": $variables})
  result = parseGraphList(js)

proc getGraphListById*(id: string): Future[List] {.async.} =
  let
    variables = %*{"listId": id, "withHighlightedLabel": false}
    js = await fetch(graphListId ? {"variables": $variables})
  result = parseGraphList(js)

proc getListTimeline*(id: string; after=""): Future[Timeline] {.async.} =
  let
    ps = genParams({"list_id": id, "ranking_mode": "reverse_chronological"}, after)
    url = listTimeline ? ps
  result = parseTimeline(await fetch(url), after)

proc getListMembers*(list: List; after=""): Future[Result[Profile]] {.async.} =
  if list.id.len == 0: return
  let
    ps = genParams({"list_id": list.id}, after)
    url = listMembers ? ps
  result = parseListMembers(await fetch(url, oldApi=true), after)

proc getProfile*(username: string): Future[Profile] {.async.} =
  let
    ps = genParams({"screen_name": username})
    url = userShow ? ps
  result = parseUserShow(await fetch(url, oldApi=true), username)

proc getTimeline*(id: string; after=""; replies=false): Future[Timeline] {.async.} =
  let
    ps = genParams({"userId": id, "include_tweet_replies": $replies}, after)
    url = timeline / (id & ".json") ? ps
  result = parseTimeline(await fetch(url), after)

proc getMediaTimeline*(id: string; after=""): Future[Timeline] {.async.} =
  let url = mediaTimeline / (id & ".json") ? genParams(cursor=after)
  result = parseTimeline(await fetch(url), after)

proc getPhotoRail*(name: string): Future[PhotoRail] {.async.} =
  let
    ps = genParams({"screen_name": name, "trim_user": "true"},
                   count="18", ext=false)
    url = photoRail ? ps
  result = parsePhotoRail(await fetch(url, oldApi=true))

proc getSearch*[T](query: Query; after=""): Future[Result[T]] {.async.} =
  when T is Profile:
    const
      searchMode = ("result_filter", "user")
      parse = parseUsers
  else:
    const
      searchMode = ("tweet_search_mode", "live")
      parse = parseTimeline

  let
    q = genQueryParam(query)
    url = search ? genParams(searchParams & @[("q", q), searchMode], after)
  result = parse(await fetch(url), after)
  result.query = query

proc getTweetImpl(id: string; after=""): Future[Conversation] {.async.} =
  let url = tweet / (id & ".json") ? genParams(cursor=after)
  result = parseConversation(await fetch(url), id)

proc getReplies*(id, after: string): Future[Result[Chain]] {.async.} =
  result = (await getTweetImpl(id, after)).replies
  result.beginning = after.len == 0

proc getTweet*(id: string; after=""): Future[Conversation] {.async.} =
  result = await getTweetImpl(id)
  if after.len > 0:
    result.replies = await getReplies(id, after)

proc resolve*(url: string; prefs: Prefs): Future[string] {.async.} =
  let client = newAsyncHttpClient(maxRedirects=0)
  try:
    let resp = await client.request(url, $HttpHead)
    result = resp.headers["location"].replaceUrl(prefs)
  except:
    discard
  finally:
    client.close()
