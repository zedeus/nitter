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

proc genHeaders*(token: string): HttpHeaders =
  result = newHttpHeaders({
    "authorization": auth,
    "content-type": "application/json",
    "x-guest-token": token,
    "x-twitter-active-user": "yes",
    "authority": "api.twitter.com",
    "accept-language": "en-US,en;q=0.9",
    "accept": "*/*",
    "DNT": "1"
  })

proc fetch(url: Uri; token: Token): Future[JsonNode] {.async.} =
  var
    client = newAsyncHttpClient(headers = genHeaders($token))

  try:
    let
      resp = await client.get($url)
      body = await resp.body

    if not body.startsWith('{'):
      echo resp.status, ": ", body
      result = newJNull()
    else:
      result = parseJson(body)

    when false:
      if resp.headers.hasKey(rl & "limit"):
        token.setUses parseInt(resp.headers[rl & "remaining"])
        token.setReset fromUnix(parseInt(resp.headers[rl & "reset"]))

    if result.getError in {invalidToken, forbidden, badToken}:
      # exceptional cases call for exceptional code
      remove token

  except Exception:
    echo "error: ", url
    result = newJNull()
  finally:
    try: client.close()
    except: discard

proc fetch*(url: Uri): Future[JsonNode] {.async.} =
  ## fetch using a token
  result = await fetch(url, await getToken())

proc fetchOld*(url: Uri): Future[JsonNode] {.async.} =
  ## fetch using the old api; ie. without a token
  #result = await fetch(url, emptyToken())
  result = await fetch(url, await getToken())
