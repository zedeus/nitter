import httpclient, asyncdispatch, times, strutils, uri

import ".."/[types, parser, parserutils]

import utils, consts

proc getProfileFallback(username: string; headers: HttpHeaders): Future[Profile] {.async.} =
  let url = base / profileIntentUrl ? {"screen_name": username}
  let html = await fetchHtml(url, headers)
  if html == nil: return Profile()

  result = parseIntentProfile(html)

proc getProfile*(username, agent: string): Future[Profile] {.async.} =
  let headers = newHttpHeaders({
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9",
    "Referer": $(base / username),
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": lang
  })

  let
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

proc getProfileFull*(username: string): Future[Profile] {.async.} =
  let headers = newHttpHeaders({
    "authority": "twitter.com",
    "accept": htmlAccept,
    "referer": "https://twitter.com/" & username,
    "accept-language": lang
  })

  let html = await fetchHtml(base / username, headers)
  if html == nil: return
  result = parseTimelineProfile(html)
