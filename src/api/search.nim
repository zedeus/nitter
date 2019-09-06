import httpclient, asyncdispatch, htmlparser
import sequtils, strutils, json, xmltree, uri

import ".."/[types, parser, parserutils, formatters, search]
import utils, consts, media, timeline

proc getTimelineSearch*(query: Query; after, agent: string): Future[Timeline] {.async.} =
  let queryParam = genQueryParam(query)
  let queryEncoded = encodeUrl(queryParam, usePlus=false)

  let headers = newHttpHeaders({
    "Accept": jsonAccept,
    "Referer": $(base / ("search?f=tweets&vertical=default&q=$1&src=typd" % queryEncoded)),
    "User-Agent": agent,
    "X-Requested-With": "XMLHttpRequest",
    "Authority": "twitter.com",
    "Accept-Language": lang
  })

  let params = {
    "f": "tweets",
    "vertical": "default",
    "q": queryParam,
    "src": "typd",
    "include_available_features": "1",
    "include_entities": "1",
    "max_position": if after.len > 0: genPos(after) else: "0",
    "reset_error_state": "false"
  }

  let json = await fetchJson(base / searchUrl ? params, headers)
  result = await finishTimeline(json, some(query), after, agent)
