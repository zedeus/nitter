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
    raise rateLimitError()

  let headers = genHeaders(token)
  try:
    var resp: AsyncResponse
    let body = pool.use(headers):
      resp = await c.get($url)
      await resp.body

    if body.startsWith('{') or body.startsWith('['):
      result = parseJson(body)
    else:
      echo resp.status, ": ", body
      result = newJNull()

    if not oldApi and resp.headers.hasKey(rl & "reset"):
      let time = fromUnix(parseInt(resp.headers[rl & "reset"]))
      if token.reset != time:
        token.remaining = parseInt(resp.headers[rl & "limit"])
      token.reset = time

    if result.getError notin {invalidToken, forbidden, badToken}:
      token.lastUse = getTime()
    else:
      echo "fetch error: ", result.getError
      release(token, true)
      raise rateLimitError()
  except Exception as e:
    echo "error: ", e.msg, ", token: ", token[], ", url: ", url
    if "length" notin e.msg and "descriptor" notin e.msg:
      release(token, true)
    raise rateLimitError()
