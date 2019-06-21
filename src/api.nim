import httpclient, asyncdispatch, htmlparser, times
import sequtils, strutils, strformat, json, xmltree, uri
import nimquery, regex

import ./types, ./parser

const
  base = parseUri("https://twitter.com/")
  agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36"
  timelineUrl = "i/profiles/show/$1/timeline/tweets?include_available_features=1&include_entities=1&include_new_items_bar=true"
  profilePopupUrl = "i/profiles/popup"
  profileIntentUrl = "intent/user"
  tweetUrl = "i/status/"

proc fetchHtml(url: Uri; headers: HttpHeaders; jsonKey = ""): Future[XmlNode] {.async.} =
  var client = newAsyncHttpClient()
  defer: client.close()

  client.headers = headers

  var resp = ""
  try:
    resp = await client.getContent($url)
  except:
    return nil

  if jsonKey.len > 0:
    let json = parseJson(resp)[jsonKey].str
    return parseHtml(json)
  else:
    return parseHtml(resp)

proc getProfileFallback(username: string; headers: HttpHeaders): Future[Profile] {.async.} =
  let
    url = base / profileIntentUrl ? {"screen_name": username}
    html = await fetchHtml(url, headers)

  result = parseIntentProfile(html)

proc getProfile*(username: string): Future[Profile] {.async.} =
  let headers = newHttpHeaders({
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9",
    "Referer": $(base / username),
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": "en-US,en;q=0.9"
  })

  let
    params = {
      "screen_name": username,
      "wants_hovercard": "true",
      "_": $(epochTime().int)
    }
    url = base / profilePopupUrl ? params
    html = await fetchHtml(url, headers, jsonKey="html")

  if not html.querySelector(".ProfileCard-sensitiveWarningContainer").isNil:
    return await getProfileFallback(username, headers)

  result = parsePopupProfile(html)

proc getTimeline*(username: string; after=""): Future[Tweets] {.async.} =
  let headers = newHttpHeaders({
    "Accept": "application/json, text/javascript, */*; q=0.01",
    "Referer": $(base / username),
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": "en-US,en;q=0.9"
  })

  var url = timelineUrl % username
  if after.len > 0:
    url &= "&max_position=" & after

  let html = await fetchHtml(base / url, headers, jsonKey="items_html")

  result = parseTweets(html)

proc getTweet*(id: string): Future[Conversation] {.async.} =
  let headers = newHttpHeaders({
    "Accept": "application/json, text/javascript, */*; q=0.01",
    "Referer": $base,
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": "en-US,en;q=0.9",
    "pragma": "no-cache",
    "x-previous-page-name": "profile"
  })

  let
    url = base / tweetUrl / id
    html = await fetchHtml(url, headers)

  result = parseConversation(html)
