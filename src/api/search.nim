import httpclient, asyncdispatch, htmlparser
import sequtils, strutils, json, xmltree, uri

import ".."/[types, parser, parserutils, formatters, query]
import utils, consts, media, timeline

proc getResult[T](json: JsonNode; query: Query; after: string): Result[T] =
  Result[T](
    hasMore: json["has_more_items"].to(bool),
    maxId: json.getOrDefault("max_position").getStr(""),
    minId: json.getOrDefault("min_position").getStr("").cleanPos(),
    query: query,
    beginning: after.len == 0
  )

proc getSearch*[T](query: Query; after, agent: string): Future[Result[T]] {.async.} =
  let
    kind = if query.kind == users: "users" else: "tweets"
    pos = when T is Tweet: genPos(after) else: after

    param = genQueryParam(query)
    encoded = encodeUrl(param, usePlus=false)

    headers = newHttpHeaders({
      "Accept": jsonAccept,
      "Referer": $(base / ("search?f=$1&q=$2&src=typd" % [kind, encoded])),
      "User-Agent": agent,
      "X-Requested-With": "XMLHttpRequest",
      "Authority": "twitter.com",
      "Accept-Language": lang
    })

    params = {
      "f": kind,
      "vertical": "default",
      "q": param,
      "src": "typd",
      "include_available_features": "1",
      "include_entities": "1",
      "max_position": if pos.len > 0: pos else: "0",
      "reset_error_state": "false"
    }

  let json = await fetchJson(base / searchUrl ? params, headers)
  if json == nil: return Result[T](query: query, beginning: true)

  result = getResult[T](json, query, after)
  if not json.hasKey("items_html"): return
  let html = parseHtml(json["items_html"].to(string))

  when T is Tweet:
    result = await finishTimeline(json, query, after, agent)
  elif T is Profile:
    result.hasMore = json["items_html"].to(string) != "\n"
    for p in html.selectAll(".js-stream-item"):
      result.content.add parsePopupProfile(p, ".ProfileCard")
