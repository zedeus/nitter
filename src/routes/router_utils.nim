import strutils, sequtils, asyncdispatch, httpclient
import ../utils, ../prefs
export utils, prefs

from net import SslError

template cookiePrefs*(): untyped {.dirty.} =
  getPrefs(request.cookies.getOrDefault("preferences"), cfg)

template getPath*(): untyped {.dirty.} =
  $(parseUri(request.path) ? filterParams(request.params))

template refPath*(): untyped {.dirty.} =
  if @"referer".len > 0: @"referer" else: "/"

proc getNames*(name: string): seq[string] =
  name.strip(chars={'/'}).split(",").filterIt(it.len > 0)

proc safeClose*(client: AsyncHttpClient) =
  try: client.close()
  except SslError: discard

proc safeFetch*(url: string): Future[string] {.async.} =
  let client = newAsyncHttpClient()
  try: result = await client.getContent(url)
  except: discard
  client.safeClose()
