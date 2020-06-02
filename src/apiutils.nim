import httpclient, asyncdispatch, options, times, strutils, uri
import packedjson
import types, agents, tokens, consts, parserutils

proc genParams*(pars: openarray[(string, string)] = @[];
                cursor=""): seq[(string, string)] =
  result = timelineParams
  for p in pars:
    result &= p
  if cursor.len > 0:
    result &= ("cursor", cursor)

proc genHeaders*(token: Token): HttpHeaders =
  result = newHttpHeaders({
    "DNT": "1",
    "authorization": auth,
    "content-type": "application/json",
    "user-agent": getAgent(),
    "x-guest-token": if token == nil: "" else: token.tok,
    "x-twitter-active-user": "yes",
    "authority": "api.twitter.com",
    "accept-language": "en-US,en;q=0.9",
    "accept": "*/*",
  })

proc fetch*(url: Uri; retried=false; oldApi=false): Future[JsonNode] {.async.} =
  var
    token = await getToken()
    keepToken = true
    proxy: Proxy = when defined(proxy): newProxy(prox) else: nil
    client = newAsyncHttpClient(proxy=proxy, headers=genHeaders(token))

  try:
    let
      resp = await client.get($url)
      body = await resp.body

    const rl = "x-rate-limit-"
    if not oldApi and resp.headers.hasKey(rl & "limit"):
      token.remaining = parseInt(resp.headers[rl & "remaining"])
      token.reset = fromUnix(parseInt(resp.headers[rl & "reset"]))

    if resp.status != $Http200:
      if "Bad guest token" in body:
        keepToken = false
        return newJNull()
      elif not body.startsWith('{'):
        echo resp.status, " ", body
        return newJNull()

    result = parseJson(body)

    if result{"errors"}.notNull and result.getError == forbidden:
      keepToken = false
      echo "bad token"
  except:
    echo "error: ", url
    result = newJNull()
  finally:
    if keepToken:
      token.release()

    try: client.close()
    except: discard
