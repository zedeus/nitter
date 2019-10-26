import httpclient, asyncdispatch, htmlparser, options
import strutils, json, xmltree, uri

import ../types
import consts

proc genHeaders*(headers: openArray[tuple[key: string, val: string]];
                 agent: string; referer: Uri; lang=true;
                 auth=false; xml=false): HttpHeaders =
  result = newHttpHeaders({
    "referer": $referer,
    "user-agent": agent,
    "x-twitter-active-user": "yes",
  })

  if auth: result["authority"] = "twitter.com"
  if lang: result["accept-language"] = consts.lang
  if xml:  result["x-requested-with"] = "XMLHttpRequest"

  for (key, val) in headers:
    result[key] = val

proc genHeaders*(agent: string; referer: Uri; lang=true;
                 auth=false; xml=false): HttpHeaders =
  genHeaders([], agent, referer, lang, auth, xml)

template newClient*() {.dirty.} =
  var client = newAsyncHttpClient()
  defer: client.close()
  client.headers = headers

proc fetchHtml*(url: Uri; headers: HttpHeaders; jsonKey = ""): Future[XmlNode] {.async.} =
  headers["accept"] = htmlAccept
  newClient()

  var resp = ""
  try:
    resp = await client.getContent($url)
  except:
    return nil

  if jsonKey.len > 0:
    resp = parseJson(resp)[jsonKey].str
  return parseHtml(resp)

proc fetchJson*(url: Uri; headers: HttpHeaders): Future[JsonNode] {.async.} =
  headers["accept"] = jsonAccept
  newClient()

  var resp = ""
  try:
    resp = await client.getContent($url)
    result = parseJson(resp)
  except:
    return nil

proc getLastId*(tweets: Result[Tweet]): string =
  if tweets.content.len == 0: return
  let last = tweets.content[^1]
  if last.retweet.isNone:
    $last.id
  else:
    $(get(last.retweet).id)
