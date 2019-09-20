import httpclient, asyncdispatch, htmlparser, strformat
import sequtils, strutils, json, uri

import ".."/[types, parser, parserutils, query]
import utils, consts, timeline, search

proc getListTimeline*(username, list, agent, after: string): Future[Timeline] {.async.} =
  let url = base / (listUrl % [username, list])

  let headers = newHttpHeaders({
    "Accept": jsonAccept,
    "Referer": $url,
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": lang
  })

  var params = toSeq({
    "include_available_features": "1",
    "include_entities": "1",
    "reset_error_state": "false"
  })

  if after.len > 0:
    params.add {"max_position": after}

  let json = await fetchJson(url ? params, headers)
  result = await finishTimeline(json, Query(), after, agent)
  if result.content.len > 0:
    result.minId = result.content[^1].id

proc getListMembers*(username, list, agent: string): Future[Result[Profile]] {.async.} =
  let url = base / (listMembersUrl % [username, list])

  let headers = newHttpHeaders({
    "Accept": htmlAccept,
    "Referer": $(base / &"{username}/lists/{list}/members"),
    "User-Agent": agent,
    "Accept-Language": lang
  })

  let html = await fetchHtml(url, headers)

  result = Result[Profile](
    minId: html.selectAttr(".stream-container", "data-min-position"),
    hasMore: html.select(".has-more-items") != nil,
    beginning: true,
    query: Query(kind: users),
    content: html.selectAll(".account").map(parseListProfile)
  )

proc getListMembersSearch*(username, list, agent, after: string): Future[Result[Profile]] {.async.} =
  let url = base / ((listMembersUrl & "/timeline") % [username, list])

  let headers = newHttpHeaders({
    "Accept": jsonAccept,
    "Referer": $(base / &"{username}/lists/{list}/members"),
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "X-Push-With": "XMLHttpRequest",
    "Accept-Language": lang
  })

  var params = toSeq({
    "include_available_features": "1",
    "include_entities": "1",
    "reset_error_state": "false"
  })

  if after.len > 0:
    params.add {"max_position": after}

  let json = await fetchJson(url ? params, headers)

  result = getResult[Profile](json, Query(kind: users), after)
  if json == nil or not json.hasKey("items_html"): return

  let html = json["items_html"].to(string)
  result.hasMore = html != "\n"
  for p in parseHtml(html).selectAll(".account"):
    result.content.add parseListProfile(p)
