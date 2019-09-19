import httpclient, asyncdispatch, htmlparser
import sequtils, strutils, json, xmltree, uri

import ".."/[types, parser, parserutils, formatters, query]
import utils, consts, media

proc finishTimeline*(json: JsonNode; query: Query; after, agent: string): Future[Timeline] {.async.} =
  if json == nil: return Timeline()

  result = Timeline(
    hasMore: json["has_more_items"].to(bool),
    maxId: json.getOrDefault("max_position").getStr(""),
    minId: json.getOrDefault("min_position").getStr("").cleanPos(),
    query: query,
    beginning: after.len == 0
  )

  if json["new_latent_count"].to(int) == 0: return
  if not json.hasKey("items_html"): return

  let
    html = parseHtml(json["items_html"].to(string))
    thread = parseThread(html)
    vidsFut = getVideos(thread, agent)
    pollFut = getPolls(thread, agent)
    cardFut = getCards(thread, agent)

  await all(vidsFut, pollFut, cardFut)
  result.content = thread.content

proc getTimeline*(username, after, agent: string): Future[Timeline] {.async.} =
  let headers = newHttpHeaders({
    "Accept": jsonAccept,
    "Referer": $(base / username),
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": lang
  })

  var params = toSeq({
    "include_available_features": "1",
    "include_entities": "1",
    "include_new_items_bar": "false",
    "reset_error_state": "false"
  })

  if after.len > 0:
    params.add {"max_position": after}

  let json = await fetchJson(base / (timelineUrl % username) ? params, headers)
  result = await finishTimeline(json, Query(), after, agent)

proc getProfileAndTimeline*(username, agent, after: string): Future[(Profile, Timeline)] {.async.} =
  let headers = newHttpHeaders({
    "authority": "twitter.com",
    "accept": htmlAccept,
    "referer": "https://twitter.com/" & username,
    "accept-language": lang
  })

  var url = base / username
  if after.len > 0:
    url = url ? {"max_position": after}

  let
    html = await fetchHtml(url, headers)
    timeline = parseTimeline(html.select("#timeline > .stream-container"), after)
    profile = parseTimelineProfile(html)

    vidsFut = getVideos(timeline, agent)
    pollFut = getPolls(timeline, agent)
    cardFut = getCards(timeline, agent)

  await all(vidsFut, pollFut, cardFut)
  result = (profile, timeline)
