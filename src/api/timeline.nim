import httpclient, asyncdispatch, htmlparser, strformat
import sequtils, strutils, json, uri

import ".."/[types, parser, parserutils, formatters, query]
import utils, consts, media, search

proc getMedia(thread: Chain | Timeline; agent: string) {.async.} =
  await all(getVideos(thread, agent),
            getCards(thread, agent),
            getPolls(thread, agent))

proc finishTimeline*(json: JsonNode; query: Query; after, agent: string;
                     media=true): Future[Timeline] {.async.} =
  result = getResult[Tweet](json, query, after)
  if json == nil: return

  if json["new_latent_count"].to(int) == 0: return
  if not json.hasKey("items_html"): return

  let html = parseHtml(json["items_html"].to(string))
  let timeline = parseChain(html)

  if media: await getMedia(timeline, agent)
  result.content = timeline.content

proc getProfileAndTimeline*(username, agent, after: string; media=true): Future[(Profile, Timeline)] {.async.} =
  var url = base / username
  if after.len > 0:
    url = url ? {"max_position": after}

  let
    headers = genHeaders(agent, base / username, auth=true)
    html = await fetchHtml(url, headers)
    timeline = parseTimeline(html.select("#timeline > .stream-container"), after)
    profile = parseTimelineProfile(html)

  if media: await getMedia(timeline, agent)
  result = (profile, timeline)

proc getTimeline*(username, after, agent: string; media=true): Future[Timeline] {.async.} =
  var params = toSeq({
    "include_available_features": "1",
    "include_entities": "1",
    "include_new_items_bar": "false",
    "reset_error_state": "false"
  })

  if after.len > 0:
    params.add {"max_position": after}

  let headers = genHeaders(agent, base / username, xml=true)
  let json = await fetchJson(base / (timelineUrl % username) ? params, headers)

  result = await finishTimeline(json, Query(), after, agent, media)

proc getMediaTimeline*(username, after, agent: string; media=true): Future[Timeline] {.async.} =
  echo "mediaTimeline"
  var params = toSeq({
    "include_available_features": "1",
    "include_entities": "1",
    "reset_error_state": "false"
  })

  if after.len > 0:
    params.add {"max_position": after}

  let headers = genHeaders(agent, base / username, xml=true)
  let json = await fetchJson(base / (timelineMediaUrl % username) ? params, headers)

  result = await finishTimeline(json, Query(kind: QueryKind.media), after, agent, media)
  result.minId = getLastId(result)
