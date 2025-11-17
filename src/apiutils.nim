# SPDX-License-Identifier: AGPL-3.0-only
import httpclient, asyncdispatch, options, strutils, uri, times, math, tables
import jsony, packedjson, zippy, oauth1
import types, auth, consts, parserutils, http_pool
import experimental/types/common

const
  rlRemaining = "x-rate-limit-remaining"
  rlReset = "x-rate-limit-reset"
  rlLimit = "x-rate-limit-limit"
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

proc getCookieHeader(authToken, ct0: string): string =
  "auth_token=" & authToken & "; ct0=" & ct0

proc genHeaders*(session: Session, url: string): HttpHeaders =
  result = newHttpHeaders({
    "connection": "keep-alive",
    "content-type": "application/json",
    "x-twitter-active-user": "yes",
    "x-twitter-client-language": "en",
    "authority": "api.x.com",
    "accept-encoding": "gzip",
    "accept-language": "en-US,en;q=0.9",
    "accept": "*/*",
    "DNT": "1",
    "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
  })

  case session.kind
  of SessionKind.oauth:
    result["authorization"] = getOauthHeader(url, session.oauthToken, session.oauthSecret)
  of SessionKind.cookie:
    result["authorization"] = "Bearer AAAAAAAAAAAAAAAAAAAAAFQODgEAAAAAVHTp76lzh3rFzcHbmHVvQxYYpTw%3DckAlMINMjmCwxUcaXbAN4XqJVdgMJaHqNOFgPMK0zN1qLqLQCF"
    result["x-twitter-auth-type"] = "OAuth2Session"
    result["x-csrf-token"] = session.ct0
    result["cookie"] = getCookieHeader(session.authToken, session.ct0)

proc getAndValidateSession*(api: Api): Future[Session] {.async.} =
  result = await getSession(api)
  case result.kind
  of SessionKind.oauth:
    if result.oauthToken.len == 0:
      echo "[sessions] Empty oauth token, session: ", result.pretty
      raise rateLimitError()
  of SessionKind.cookie:
    if result.authToken.len == 0 or result.ct0.len == 0:
      echo "[sessions] Empty cookie credentials, session: ", result.pretty
      raise rateLimitError()

template fetchImpl(result, fetchBody) {.dirty.} =
  once:
    pool = HttpPool()

  try:
    var resp: AsyncResponse
    pool.use(genHeaders(session, $url)):
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
        limit = parseInt(resp.headers[rlLimit])
      session.setRateLimit(api, remaining, reset, limit)

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
        echo "[sessions] 429 error, API: ", api, ", session: ", session.pretty
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
    let s = session.pretty
    echo "error: ", e.name, ", msg: ", e.msg, ", session: ", s, ", url: ", url
    raise rateLimitError()
  finally:
    release(session)

template retry(bod) =
  try:
    bod
  except RateLimitError:
    echo "[sessions] Rate limited, retrying ", api, " request..."
    bod

proc fetch*(url: Uri | SessionAwareUrl; api: Api): Future[JsonNode] {.async.} =
  retry:
    var 
      body: string
      session = await getAndValidateSession(api)

    when url is SessionAwareUrl:
      let url = case session.kind
        of SessionKind.oauth: url.oauthUrl
        of SessionKind.cookie: url.cookieUrl

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

proc fetchRaw*(url: Uri | SessionAwareUrl; api: Api): Future[string] {.async.} =
  retry:
    var session = await getAndValidateSession(api)

    when url is SessionAwareUrl:
      let url = case session.kind
        of SessionKind.oauth: url.oauthUrl
        of SessionKind.cookie: url.cookieUrl

    fetchImpl result:
      if not (result.startsWith('{') or result.startsWith('[')):
        echo resp.status, ": ", result, " --- url: ", url
        result.setLen(0)
