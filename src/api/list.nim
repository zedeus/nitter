import httpclient, asyncdispatch, htmlparser
import sequtils, strutils, json, uri

import ".."/[types, parser, parserutils, query]
import utils, consts, timeline, search

proc getListTimeline*(username, list, agent, after: string): Future[Timeline] {.async.} =
  let url = base / (listUrl % [username, list])

  var params = toSeq({
    "include_available_features": "1",
    "include_entities": "1",
    "reset_error_state": "false"
  })

  if after.len > 0:
    params.add {"max_position": after}

  let json = await fetchJson(url ? params, genHeaders(agent, url))
  result = await finishTimeline(json, Query(), after, agent)
  if result.content.len == 0:
    return

  let last = result.content[^1]
  result.minId =
    if last.retweet.isNone: $last.id
    else: $(get(last.retweet).id)

proc getListMembers*(username, list, agent: string): Future[Result[Profile]] {.async.} =
  let
    url = base / (listMembersUrl % [username, list])
    html = await fetchHtml(url, genHeaders(agent, url))

  result = Result[Profile](
    minId: html.selectAttr(".stream-container", "data-min-position"),
    hasMore: html.select(".has-more-items") != nil,
    beginning: true,
    query: Query(kind: userList),
    content: html.selectAll(".account").map(parseListProfile)
  )

proc getListMembersSearch*(username, list, agent, after: string): Future[Result[Profile]] {.async.} =
  let
    referer = base / (listMembersUrl % [username, list])
    url = referer / "timeline"
    headers = genHeaders({"x-push-with": "XMLHttpRequest"}, agent, referer, xml=true)

  var params = toSeq({
    "include_available_features": "1",
    "include_entities": "1",
    "reset_error_state": "false"
  })

  if after.len > 0:
    params.add {"max_position": after}

  let json = await fetchJson(url ? params, headers)

  result = getResult[Profile](json, Query(kind: userList), after)
  if json == nil or not json.hasKey("items_html"): return

  let html = json["items_html"].to(string)
  result.hasMore = html != "\n"
  for p in parseHtml(html).selectAll(".account"):
    result.content.add parseListProfile(p)
