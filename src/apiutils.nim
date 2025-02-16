# SPDX-License-Identifier: AGPL-3.0-only
import httpclient, asyncdispatch, options, strutils, uri, times, math, tables
import jsony, packedjson, zippy, oauth1
import types, auth, consts, parserutils, http_pool
import experimental/types/common

const
  rlRemaining = "x-rate-limit-remaining"
  rlReset = "x-rate-limit-reset"
  errorsToSkip = {doesntExist, tweetNotFound, timeout, unauthorized, badRequest}

var pool: HttpPool

proc getOauthHeader(url, oauthToken, oauthTokenSecret: string): string =
  let
    encodedUrl = url.replace(",", "%2C").replace("+", "%20")
    params = OAuth1Parameters(
      consumerKey: consumerKey,
      signatureMethod: "HMAC-SHA1",
      timestamp: $int(round(epochTime())),
      nonce: "0",
      isIncludeVersionToHeader: true,
      token: oauthToken
    )
    signature = getSignature(HttpGet, encodedUrl, "", params, consumerSecret, oauthTokenSecret)

  params.signature = percentEncode(signature)

  return getOauth1RequestHeader(params)["authorization"]

proc genHeaders*(url, oauthToken, oauthTokenSecret: string): HttpHeaders =
  let header = getOauthHeader(url, oauthToken, oauthTokenSecret)

  result = newHttpHeaders({
    "connection": "keep-alive",
    "authorization": header,
    "content-type": "application/json",
    "x-twitter-active-user": "yes",
    "authority": "api.x.com",
    "accept-encoding": "gzip",
    "accept-language": "en-US,en;q=0.9",
    "accept": "*/*",
    "DNT": "1"
  })

template fetchImpl(result, fetchBody) {.dirty.} =
  once:
    pool = HttpPool()

  var session = await getSession(api)
  if session.oauthToken.len == 0:
    echo "[sessions] Empty oauth token, session: ", session.id
    raise rateLimitError()

  try:
    var resp: AsyncResponse
    pool.use(genHeaders($url, session.oauthToken, session.oauthSecret)):
      template getContent =
        resp = await c.get($url)
        result = await resp.body

      getContent()

      if resp.status == $Http503:
        badClient = true
        raise newException(BadClientError, "Bad client")

    if resp.headers.hasKey(rlRemaining):
      let
        remaining = parseInt(resp.headers[rlRemaining])
        reset = parseInt(resp.headers[rlReset])
      session.setRateLimit(api, remaining, reset)

    if result.len > 0:
      if resp.headers.getOrDefault("content-encoding") == "gzip":
        result = uncompress(result, dfGzip)

      if result.startsWith("{\"errors"):
        let errors = result.fromJson(Errors)
        if errors notin errorsToSkip:
          echo "Fetch error, API: ", api, ", errors: ", errors
          if errors in {expiredToken, badToken, locked}:
            invalidate(session)
            raise rateLimitError()
          elif errors in {rateLimited}:
            # rate limit hit, resets after 24 hours
            setLimited(session, api)
            raise rateLimitError()
      elif result.startsWith("429 Too Many Requests"):
        echo "[sessions] 429 error, API: ", api, ", session: ", session.id
        session.apis[api].remaining = 0
        # rate limit hit, resets after the 15 minute window
        raise rateLimitError()

    fetchBody

    if resp.status == $Http400:
      echo "ERROR 400, ", api, ": ", result
      raise newException(InternalError, $url)
  except InternalError as e:
    raise e
  except BadClientError as e:
    raise e
  except OSError as e:
    raise e
  except Exception as e:
    let id = if session.isNil: "null" else: $session.id
    echo "error: ", e.name, ", msg: ", e.msg, ", sessionId: ", id, ", url: ", url
    raise rateLimitError()
  finally:
    release(session)

template retry(bod) =
  try:
    bod
  except RateLimitError:
    echo "[sessions] Rate limited, retrying ", api, " request..."
    bod

proc fetch*(url: Uri; api: Api): Future[JsonNode] {.async.} =
  retry:
    var body: string
    fetchImpl body:
      if body.startsWith('{') or body.startsWith('['):
        result = parseJson(body)
      else:
        echo resp.status, ": ", body, " --- url: ", url
        result = newJNull()

      let error = result.getError
      if error != null and error notin errorsToSkip:
        echo "Fetch error, API: ", api, ", error: ", error
        if error in {expiredToken, badToken, locked}:
          invalidate(session)
          raise rateLimitError()

proc fetchRaw*(url: Uri; api: Api): Future[string] {.async.} =
  retry:
    fetchImpl result:
      if not (result.startsWith('{') or result.startsWith('[')):
        echo resp.status, ": ", result, " --- url: ", url
        result.setLen(0)
