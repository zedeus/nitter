import httpclient, asyncdispatch, htmlparser
import strutils, json, xmltree, uri

template newClient*() {.dirty.} =
  var client = newAsyncHttpClient()
  defer: client.close()
  client.headers = headers

proc fetchHtml*(url: Uri; headers: HttpHeaders; jsonKey = ""): Future[XmlNode] {.async.} =
  newClient()

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

proc fetchJson*(url: Uri; headers: HttpHeaders): Future[JsonNode] {.async.} =
  newClient()

  var resp = ""
  try:
    resp = await client.getContent($url)
    result = parseJson(resp)
  except:
    return nil
