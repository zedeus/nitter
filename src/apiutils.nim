import httpclient, asyncdispatch, options, times, strutils, uri
import packedjson
import types, tokens, consts, parserutils, http_pool

const rl = "x-rate-limit-"

var pool {.threadvar.}: HttpPool

proc genParams*(pars: openarray[(string, string)] = @[]; cursor="";
                count="20"; ext=true): seq[(string, string)] =
  result = timelineParams
  for p in pars:
    result &= p
  if ext:
    result &= ("ext", "mediaStats")
  if cursor.len > 0:
    result &= ("cursor", cursor)
  if count.len > 0:
    result &= ("count", count)

proc genHeaders*(token: Token = nil): HttpHeaders =
  result = newHttpHeaders({
    "connection": "keep-alive",
    "authorization": auth,
    "content-type": "application/json",
    "x-guest-token": if token == nil: "" else: token.tok,
    "x-twitter-active-user": "yes",
    "authority": "api.twitter.com",
    "accept-language": "en-US,en;q=0.9",
    "accept": "*/*",
    "DNT": "1"
  })

proc fetch*(url: Uri; oldApi=false): Future[JsonNode] {.async.} =
  once:
    pool = HttpPool()

  var token = await getToken()
  if token.tok.len == 0:
    result = newJNull()

  let headers = genHeaders(token)
  try:
    let
      resp = pool.use(headers): await c.get($url)
      body = await resp.body

    if body.startsWith('{') or body.startsWith('['):
      result = parseJson(body)
    else:
      echo resp.status, ": ", body
      result = newJNull()

    if not oldApi and resp.headers.hasKey(rl & "limit"):
      token.remaining = parseInt(resp.headers[rl & "remaining"])
      token.reset = fromUnix(parseInt(resp.headers[rl & "reset"]))

    if result.getError notin {invalidToken, forbidden, badToken}:
      token.release()
  except Exception:
    echo "error: ", url
    result = newJNull()
