import httpclient, asyncdispatch, times, strutils, uri

import ".."/[types, parser, parserutils]

import utils, consts

proc getProfileFallback(username: string; headers: HttpHeaders): Future[Profile] {.async.} =
  let url = base / profileIntentUrl ? {"screen_name": username}
  let html = await fetchHtml(url, headers)
  if html == nil: return Profile()

  result = parseIntentProfile(html)

proc getProfile*(username, agent: string): Future[Profile] {.async.} =
  let
    headers = genHeaders(agent, base / username, xml=true)

    params = {
      "screen_name": username,
      "wants_hovercard": "true",
      "_": $(epochTime().int)
    }

    url = base / profilePopupUrl ? params
    html = await fetchHtml(url, headers, jsonKey="html")

  if html == nil: return Profile()

  if html.select(".ProfileCard-sensitiveWarningContainer") != nil:
    return await getProfileFallback(username, headers)

  result = parsePopupProfile(html)

proc getProfileFull*(username, agent: string): Future[Profile] {.async.} =
  let
    url = base / username
    headers = genHeaders(agent, url, auth=true, guestId=true)
    html = await fetchHtml(url, headers)

  if html == nil: return
  result = parseTimelineProfile(html)
