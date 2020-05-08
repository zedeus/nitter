import strutils, sequtils, asyncdispatch, httpclient
from jester import Request
import ../utils, ../prefs
export utils, prefs

template savePref*(pref, value: string; req: Request; expire=false): typed =
  if not expire or pref in cookies(req):
    setCookie(pref, value, daysForward(when expire: -10 else: 360),
              httpOnly=true, secure=cfg.useHttps)

template cookiePrefs*(): untyped {.dirty.} =
  getPrefs(cookies(request))

template getPath*(): untyped {.dirty.} =
  $(parseUri(request.path) ? filterParams(request.params))

template refPath*(): untyped {.dirty.} =
  if @"referer".len > 0: @"referer" else: "/"

proc getNames*(name: string): seq[string] =
  name.strip(chars={'/'}).split(",").filterIt(it.len > 0)

proc safeClose*(client: AsyncHttpClient) =
  try: client.close()
  except: discard

proc safeFetch*(url: string): Future[string] {.async.} =
  let client = newAsyncHttpClient()
  try: result = await client.getContent(url)
  except: discard
  finally: client.safeClose()
