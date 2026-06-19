# SPDX-License-Identifier: AGPL-3.0-only
import uri, strutils, httpclient, os, hashes, base64, re
import asynchttpserver, asyncstreams, asyncfile, asyncnet
import asyncdispatch

import jester

import router_utils
import ".."/[types, formatters, utils]

export asynchttpserver, asyncstreams, asyncfile, asyncnet
export httpclient, os, strutils, asyncstreams, base64, re

const
  m3u8Mime* = "application/vnd.apple.mpegurl"
  maxAge* = "max-age=604800"

proc safeFetch*(url: string): Future[string] {.async.} =
  # maxRedirects=0: the caller already validated the host, so never follow a
  # redirect off the allowlisted host (would re-open the #1411 SSRF).
  let client = newAsyncHttpClient(maxRedirects = 0)
  try: result = await client.getContent(url)
  except: discard
  finally: client.close()

template respond*(req: asynchttpserver.Request; headers) =
  var msg = "HTTP/1.1 200 OK\c\L"
  for k, v in headers:
    msg.add(k & ": " & v & "\c\L")

  msg.add "\c\L"
  yield req.client.send(msg)

proc proxyMedia*(req: jester.Request; url: string): Future[HttpCode] {.async.} =
  result = Http200
  let request = req.getNativeReq()

  for attempt in 0 .. 2:
    let client = newAsyncHttpClient(maxRedirects = 0)
    var shouldRetry = false
    try:
      let resFut = client.get(url)
      let completed = await withTimeout(resFut, 5000)
      if not completed:
        if attempt < 2:
          echo "[media] Retry $1/2, timeout after 5s, url: $2" % [$(attempt + 1), url]
          shouldRetry = true
        else:
          echo "[media] Proxying timeout after 5s, url: $1" % [url]
          return Http504
      else:
        let res = resFut.read()
        if res.status != "200 OK":
          if res.status == "404 Not Found":
            return Http404
          if attempt < 2:
            echo "[media] Retry $1/2, status: $2, url: $3" % [$(attempt + 1), res.status, url]
            shouldRetry = true
          else:
            echo "[media] Proxying failed, status: $1, url: $2" % [res.status, url]
            return Http404
        else:
          let hashed = $hash(url)
          if request.headers.getOrDefault("If-None-Match") == hashed:
            return Http304

          let contentLength =
            if res.headers.hasKey("content-length"):
              res.headers["content-length", 0]
            else:
              ""

          let headers = newHttpHeaders({
            "content-type": res.headers["content-type", 0],
            "content-length": contentLength,
            "cache-control": maxAge,
            "etag": hashed
          })

          respond(request, headers)

          var (hasValue, data) = (true, "")
          while hasValue:
            (hasValue, data) = await res.bodyStream.read()
            if hasValue:
              await request.client.send(data)
          data.setLen 0
          return Http200
    except CatchableError:
      if attempt < 2:
        echo "[media] Retry $1/2, error: $2, url: $3" % [$(attempt + 1), getCurrentExceptionMsg(), url]
        shouldRetry = true
      else:
        echo "[media] Proxying exception, error: $1, url: $2" % [getCurrentExceptionMsg(), url]
        result = Http404
    finally:
      client.close()
    if not shouldRetry:
      break

template check*(code): untyped =
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

proc normalizeImgUrl*(url: var string) =
  if not url.startsWith("http"):
    if "twimg.com" notin url:
      url.insert(twimg)
    url.insert(https)

proc createMediaRouter*(cfg: Config) =
  router media:
    get "/pic/?":
      resp Http404

    get re"^\/pic\/orig\/(enc)?\/?(.+)":
      var url = decoded(request, 1)
      cond "/amplify_video/" notin url
      normalizeImgUrl(url)
      url.add("?name=orig")

      let uri = parseUri(url)
      cond isTwitterUrl(uri) == true

      let code = await proxyMedia(request, url)
      check code

    get re"^\/pic\/(enc)?\/?(.+)":
      var url = decoded(request, 1)
      cond "/amplify_video/" notin url
      normalizeImgUrl(url)

      let uri = parseUri(url)
      cond isTwitterUrl(uri) == true

      let code = await proxyMedia(request, url)
      check code

    get re"^\/video\/(enc)?\/?(.+)\/(.+)$":
      let url = decoded(request, 2)
      cond isTwitterUrl(url)

      if getHmac(url) != request.matches[1]:
        resp Http403, showError("Failed to verify signature", cfg)

      if ".mp4" in url or ".ts" in url or ".m4s" in url or ".aac" in url:
        let code = await proxyMedia(request, url)
        check code

      var content: string
      if ".vmap" in url:
        let m3u8 = getM3u8Url(await safeFetch(url))
        if m3u8.len > 0:
          content = await safeFetch(url)
        else:
          resp Http404

      if ".m3u8" in url:
        let vid = await safeFetch(url)
        content = proxifyVideo(vid, requestPrefs().proxyVideos, url)

      resp content, m3u8Mime
