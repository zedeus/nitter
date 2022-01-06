# SPDX-License-Identifier: AGPL-3.0-only
import httpclient, asyncdispatch, options, times, strutils, uri
import packedjson, zippy
import types, tokens, consts, parserutils, http_pool

const
  rlRemaining = "x-rate-limit-remaining"
  rlReset = "x-rate-limit-reset"

var pool: HttpPool

proc genParams*(pars: openArray[(string, string)] = @[]; cursor="";
                count="20"; ext=true): seq[(string, string)] =
  result = timelineParams
  for p in pars:
    result &= p
  if ext:
    result &= ("ext", "mediaStats")
  if count.len > 0:
    result &= ("count", count)
  if cursor.len > 0:
    # The raw cursor often has plus signs, which sometimes get turned into spaces,
    # so we need to them back into a plus
    if " " in cursor:
      result &= ("cursor", cursor.replace(" ", "+"))
    else:
      result &= ("cursor", cursor)

proc genHeaders*(token: Token = nil): HttpHeaders =
  result = newHttpHeaders({
    "connection": "keep-alive",
    "authorization": auth,
    "content-type": "application/json",
    "x-guest-token": if token == nil: "" else: token.tok,
    "x-twitter-active-user": "yes",
    "authority": "api.twitter.com",
    "accept-encoding": "gzip",
    "accept-language": "en-US,en;q=0.9",
    "accept": "*/*",
    "DNT": "1"
  })

proc fetch*(url: Uri; api: Api): Future[JsonNode] {.async.} =
  once:
    pool = HttpPool()

  var token = await getToken(api)
  if token.tok.len == 0:
    raise rateLimitError()

  let headers = genHeaders(token)
  try:
    var resp: AsyncResponse
    var body = pool.use(headers):
      resp = await c.get($url)
      await resp.body

    if body.len > 0:
      if resp.headers.getOrDefault("content-encoding") == "gzip":
        body = uncompress(body, dfGzip)
      else:
        echo "non-gzip body, url: ", url, ", body: ", body

    if body.startsWith('{') or body.startsWith('['):
      result = parseJson(body)
    else:
      echo resp.status, ": ", body
      result = newJNull()

    if api != Api.search and resp.headers.hasKey(rlRemaining):
      let
        remaining = parseInt(resp.headers[rlRemaining])
        reset = parseInt(resp.headers[rlReset])
      token.setRateLimit(api, remaining, reset)

    if result.getError notin {invalidToken, forbidden, badToken}:
      release(token, used=true)
    else:
      echo "fetch error: ", result.getError
      release(token, invalid=true)
      raise rateLimitError()

    if resp.status == $Http400:
      raise newException(InternalError, $url)
  except InternalError as e:
    raise e
  except Exception as e:
    echo "error: ", e.name, ", msg: ", e.msg, ", token: ", token[], ", url: ", url
    if "length" notin e.msg and "descriptor" notin e.msg:
      release(token, invalid=true)
    raise rateLimitError()
