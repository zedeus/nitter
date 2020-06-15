import httpclient, asyncdispatch, options, times, strutils, uri
import packedjson
import types, tokens, consts, parserutils

const rl = "x-rate-limit-"

proc genParams*(pars: openarray[(string, string)] = @[];
                cursor=""): seq[(string, string)] =
  result = timelineParams
  for p in pars:
    result &= p
  if cursor.len > 0:
    result &= ("cursor", cursor)

proc genHeaders*(token: Token = nil): HttpHeaders =
  result = newHttpHeaders({
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
  var
    token = if oldApi: nil else: await getToken()
    client = newAsyncHttpClient(headers=genHeaders(token))

  try:
    let
      resp = await client.get($url)
      body = await resp.body

    if not body.startsWith('{'):
      echo resp.status, ": ", body
      result = newJNull()
    else:
      result = parseJson(body)

    if not oldApi and resp.headers.hasKey(rl & "limit"):
      token.remaining = parseInt(resp.headers[rl & "remaining"])
      token.reset = fromUnix(parseInt(resp.headers[rl & "reset"]))

    if result.getError notin {invalidToken, forbidden, badToken}:
      token.release()
  except Exception:
    echo "error: ", url
    result = newJNull()
  finally:
    try: client.close()
    except: discard
