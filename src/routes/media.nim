# SPDX-License-Identifier: AGPL-3.0-only
import uri, strutils, httpclient, os, hashes, base64, re
import asynchttpserver, asyncstreams, asyncfile, asyncnet

import jester

import router_utils
import ".."/[types, formatters, utils]

export asynchttpserver, asyncstreams, asyncfile, asyncnet
export httpclient, os, strutils, asyncstreams, base64, re

const
  m3u8Mime* = "application/vnd.apple.mpegurl"
  mp4Mime* = "video/mp4"
  maxAge* = "max-age=604800"

proc safeFetch*(url: string): Future[string] {.async.} =
  let client = newAsyncHttpClient()
  try: result = await client.getContent(url)
  except: discard
  finally: client.close()

template respond*(req: asynchttpserver.Request; code: HttpCode;
                  headers: seq[(string, string)]) =
  var msg = "HTTP/1.1 " & $code & "\c\L"
  for (k, v) in headers:
    msg.add(k & ": " & v & "\c\L")

  msg.add "\c\L"
  yield req.client.send(msg, flags={})

proc getContentLength(res: AsyncResponse): string =
  result = "0"
  if res.headers.hasKey("content-length"):
    result = $res.contentLength
  elif res.headers.hasKey("content-range"):
    result = res.headers["content-range"]
    result = result[result.find('/') + 1 .. ^1]
    if result == "*":
      result.setLen(0)

proc proxyMedia*(req: jester.Request; url: string): Future[HttpCode] {.async.} =
  result = Http200

  let
    request = req.getNativeReq()
    hashed = $hash(url)

  if request.headers.getOrDefault("If-None-Match") == hashed:
    return Http304

  let c = newAsyncHttpClient(headers=newHttpHeaders({
    "accept": "*/*",
    "range": $req.headers.getOrDefault("range")
  }))

  try:
    var res = await c.get(url)
    if not res.status.startsWith("20"):
      return Http404

    var headers = @{
      "Accept-Ranges": "bytes",
      "Content-Type": res.headers["content-type", 0],
      "Cache-Control": maxAge
    }

    var tries = 0
    while tries <= 10 and res.headers.hasKey("transfer-encoding"):
      await sleepAsync(100 + tries * 200)
      res = await c.get(url)
      tries.inc

    let contentLength = res.getContentLength
    if contentLength.len > 0:
      headers.add ("Content-Length", contentLength)

    if res.headers.hasKey("content-range"):
      headers.add ("Content-Range", $res.headers.getOrDefault("content-range"))
      respond(request, Http206, headers)
    else:
      respond(request, Http200, headers)

    var (hasValue, data) = (true, "")
    while hasValue:
      (hasValue, data) = await res.bodyStream.read()
      if hasValue:
        await request.client.send(data, flags={})
    data.setLen 0
  except OSError: discard
  except ProtocolError, HttpRequestError:
    result = Http404
  finally:
    c.close()

template check*(c): untyped =
  let code = c
  if code != Http200:
    resp code
  else:
    enableRawMode()
    break route

proc decoded*(req: jester.Request; index: int): string =
  let
    based = req.matches[0].len > 1
    encoded = req.matches[index]
  if based: decode(encoded)
  else: decodeUrl(encoded)

proc getPicUrl*(req: jester.Request): string =
  result = decoded(req, 1)
  if "twimg.com" notin result:
    result.insert(twimg)
  if not result.startsWith(https):
    result.insert(https)

proc createMediaRouter*(cfg: Config) =
  router media:
    get "/pic/?":
      resp Http404

    get re"^\/pic\/orig\/(enc)?\/?(.+)":
      let url = getPicUrl(request)
      cond isTwitterUrl(parseUri(url)) == true
      check await proxyMedia(request, url & "?name=orig")

    get re"^\/pic\/(enc)?\/?(.+)":
      let url = getPicUrl(request)
      cond isTwitterUrl(parseUri(url)) == true
      check await proxyMedia(request, url)

    get re"^\/video\/(enc)?\/?(.+)\/(.+)$":
      let url = decoded(request, 2)
      cond "http" in url

      if getHmac(url) != request.matches[1]:
        resp showError("Failed to verify signature", cfg)

      if ".mp4" in url or ".ts" in url or ".m4s" in url:
        check await proxyMedia(request, url)

      var content: string
      if ".vmap" in url:
        let m3u8 = getM3u8Url(await safeFetch(url))
        if m3u8.len > 0:
          content = await safeFetch(url)
        else:
          resp Http404

      if ".m3u8" in url:
        let vid = await safeFetch(url)
        content = proxifyVideo(vid, cookiePref(proxyVideos))

      resp content, m3u8Mime
