import httpclient, asyncdispatch, htmlparser, times
import sequtils, strutils, strformat, json, xmltree, uri
import nimquery, regex

import ./types, ./parser

const base = parseUri("https://twitter.com/")
const agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36"

const timelineUrl = "i/profiles/show/$1/timeline/tweets?include_available_features=1&include_entities=1&include_new_items_bar=true"
const profileUrl = "i/profiles/popup"
const tweetUrl = "i/status/"

proc getProfile*(username: string): Future[Profile] {.async.} =
  let client = newAsyncHttpClient()
  defer: client.close()

  client.headers = newHttpHeaders({
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9",
    "Referer": $(base / username),
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": "en-US,en;q=0.9"
  })

  let params = {
    "screen_name": username,
    "wants_hovercard": "true",
    "_": $(epochTime().int)
  }

  let url = base / profileUrl ? params
  var resp = ""

  try:
    resp = await client.getContent($url)
  except:
    return Profile()

  let
    json = parseJson(resp)["html"].str
    html = parseHtml(json)

  result = parseProfile(html)

proc getTimeline*(username: string; after=""): Future[Tweets] {.async.} =
  let client = newAsyncHttpClient()
  defer: client.close()

  client.headers = newHttpHeaders({
    "Accept": "application/json, text/javascript, */*; q=0.01",
    "Referer": $(base / username),
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": "en-US,en;q=0.9"
  })

  var url = timelineUrl % username
  if after != "":
    url &= "&max_position=" & after

  var resp = ""
  try:
    resp = await client.getContent($(base / url))
  except:
    return

  var json: string = ""
  var html: XmlNode
  json = parseJson(resp)["items_html"].str
  html = parseHtml(json)

  writeFile("epic.html", $html)

  result = parseTweets(html)

proc getTweet*(id: string): Future[Conversation] {.async.} =
  let client = newAsyncHttpClient()
  defer: client.close()

  client.headers = newHttpHeaders({
    "Accept": "application/json, text/javascript, */*; q=0.01",
    "Referer": $base,
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": "en-US,en;q=0.9",
    "pragma": "no-cache",
    "x-previous-page-name": "profile"
  })

  let url = base / tweetUrl / id

  var resp: string = ""
  try:
    resp = await client.getContent($url)
  except:
    return Conversation()

  var html: XmlNode
  html = parseHtml(resp)

  result = parseConversation(html)
