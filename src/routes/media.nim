import uri, strutils, httpclient, os, hashes
import asynchttpserver, asyncstreams, asyncfile, asyncnet
import base64

import jester, regex

import router_utils
import ".."/[types, formatters, agents, utils]
import ../views/general

export asynchttpserver, asyncstreams, asyncfile, asyncnet
export httpclient, os, strutils, asyncstreams, regex

const
  m3u8Regex* = re"""url="(.+.m3u8)""""
  m3u8Mime* = "application/vnd.apple.mpegurl"
  maxAge* = "max-age=604800"

let mediaAgent* = getAgent()

template respond*(req: asynchttpserver.Request; headers) =
  var msg = "HTTP/1.1 200 OK\c\L"
  for k, v in headers:
    msg.add(k & ": " & v & "\c\L")

  msg.add "\c\L"
  yield req.client.send(msg)

proc proxyMedia*(req: jester.Request; url: string): Future[HttpCode] {.async.} =
  result = Http200
  let
    request = req.getNativeReq()
    client = newAsyncHttpClient(userAgent=mediaAgent)

  try:
    let res = await client.get(url)
    if res.status != "200 OK":
      return Http404

    let hashed = $hash(url)
    if request.headers.getOrDefault("If-None-Match") == hashed:
      return Http304

    let headers = newHttpHeaders({
      "Content-Type": res.headers["content-type", 0],
      "Content-Length": res.headers["content-length", 0],
      "Cache-Control": maxAge,
      "ETag": hashed
    })

    respond(request, headers)

    var (hasValue, data) = (true, "")
    while hasValue:
      (hasValue, data) = await res.bodyStream.read()
      if hasValue:
        await request.client.send(data)
    data.setLen 0
  except HttpRequestError, ProtocolError, OSError:
    result = Http404
  finally:
    client.safeClose()

proc createMediaRouter*(cfg: Config) =
  router media:
    get "/pic/?":
      resp Http404

    get "/pic/@url":
      var url = decodeUrl(@"url")
      if "twimg.com" notin url:
        url.insert(twimg)
      if not url.startsWith(https):
        url.insert(https)

      let uri = parseUri(url)
      cond isTwitterUrl(uri) == true

      enableRawMode()
      let code = await proxyMedia(request, $uri)
      if code == Http200:
        enableRawMode()
        break route
      else:
        resp code

    get "/pic/encoded/@encoded":
      var encodedString = @"encoded"
      var urlString = decode(encodedString)
      var url = decodeUrl(urlString)
      if "twimg.com" notin url:
        url.insert(twimg)
      if not url.startsWith(https):
        url.insert(https)

      let uri = parseUri(url)
      cond isTwitterUrl(uri) == true

      enableRawMode()
      let code = await proxyMedia(request, $uri)
      if code == Http200:
        enableRawMode()
        break route
      else:
        resp code

    get "/video/@sig/@url":
      cond "http" in @"url"
      var url = decodeUrl(@"url")
      let prefs = cookiePrefs()

      if getHmac(url) != @"sig":
        resp showError("Failed to verify signature", cfg)

      if ".mp4" in url or ".ts" in url:
        let code = await proxyMedia(request, url)
        if code == Http200:
          enableRawMode()
          break route
        else:
          resp code

      var content: string
      if ".vmap" in url:
        var m: RegexMatch
        content = await safeFetch(url, mediaAgent)
        if content.find(m3u8Regex, m):
          url = decodeUrl(content[m.group(0)[0]])
          content = await safeFetch(url, mediaAgent)
        else:
          resp Http404

      if ".m3u8" in url:
        let vid = await safeFetch(url, mediaAgent)
        content = proxifyVideo(vid, prefs.proxyVideos)

      resp content, m3u8Mime
