# SPDX-License-Identifier: AGPL-3.0-only
import httpclient, asyncdispatch, options, strutils, uri, times, math, tables
import jsony, packedjson, zippy, oauth1
import types, auth, consts, parserutils, http_pool, tid
import experimental/types/common

const
  rlRemaining = "x-rate-limit-remaining"
  rlReset = "x-rate-limit-reset"
  rlLimit = "x-rate-limit-limit"
  errorsToSkip = {null, doesntExist, tweetNotFound, timeout, unauthorized, badRequest}

var 
  pool: HttpPool
  disableTid: bool
  apiProxy: string

proc setDisableTid*(disable: bool) =
  disableTid = disable

proc setApiProxy*(url: string) =
  if url.len > 0:
    apiProxy = url.strip(chars={'/'}) & "/"
    if "http" notin apiProxy:
      apiProxy = "http://" & apiProxy

proc toUrl(req: ApiReq; sessionKind: SessionKind): Uri =
  case sessionKind
  of oauth:  
    let o = req.oauth
    parseUri("https://api.x.com/graphql")   / o.endpoint ? o.params
  of cookie: 
    let c = req.cookie
    parseUri("https://x.com/i/api/graphql") / c.endpoint ? c.params

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

proc genHeaders*(session: Session, url: Uri): Future[HttpHeaders] {.async.} =
  result = newHttpHeaders({
    "accept": "*/*",
    "accept-encoding": "gzip",
    "accept-language": "en-US,en;q=0.9",
    "connection": "keep-alive",
    "content-type": "application/json",
    "origin": "https://x.com",
    "user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36",
    "x-twitter-active-user": "yes",
    "x-twitter-client-language": "en",
    "priority": "u=1, i"
  })

  case session.kind
  of SessionKind.oauth:
    result["authorization"] = getOauthHeader($url, session.oauthToken, session.oauthSecret)
  of SessionKind.cookie:
    result["x-twitter-auth-type"] = "OAuth2Session"
    result["x-csrf-token"] = session.ct0
    result["cookie"] = getCookieHeader(session.authToken, session.ct0)
    result["sec-ch-ua"] = """"Google Chrome";v="142", "Chromium";v="142", "Not A(Brand";v="24""""
    result["sec-ch-ua-mobile"] = "?0"
    result["sec-ch-ua-platform"] = "Windows"
    result["sec-fetch-dest"] = "empty"
    result["sec-fetch-mode"] = "cors"
    result["sec-fetch-site"] = "same-site"
    if disableTid:
      result["authorization"] = bearerToken2
    else:
      result["authorization"] = bearerToken
      result["x-client-transaction-id"] = await genTid(url.path)

proc getAndValidateSession*(req: ApiReq): Future[Session] {.async.} =
  result = await getSession(req)
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
    pool.use(await genHeaders(session, url)):
      template getContent =
        # TODO: this is a temporary simple implementation
        if apiProxy.len > 0:
          resp = await c.get(($url).replace("https://", apiProxy))
        else:
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
      session.setRateLimit(req, remaining, reset, limit)

    if result.len > 0:
      if resp.headers.getOrDefault("content-encoding") == "gzip":
        result = uncompress(result, dfGzip)

      if result.startsWith("{\"errors"):
        let errors = result.fromJson(Errors)
        if errors notin errorsToSkip:
          echo "Fetch error, API: ", url.path, ", errors: ", errors
          if errors in {expiredToken, badToken, locked}:
            invalidate(session)
            raise rateLimitError()
          elif errors in {rateLimited}:
            # rate limit hit, resets after 24 hours
            setLimited(session, req)
            raise rateLimitError()
      elif result.startsWith("429 Too Many Requests"):
        echo "[sessions] 429 error, API: ", url.path, ", session: ", session.pretty
        raise rateLimitError()

    fetchBody

    if resp.status == $Http400:
      echo "ERROR 400, ", url.path, ": ", result
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
    echo "[sessions] Rate limited, retrying ", req.cookie.endpoint, " request..."
    bod

proc fetch*(req: ApiReq): Future[JsonNode] {.async.} =
  retry:
    var 
      body: string
      session = await getAndValidateSession(req)

    let url = req.toUrl(session.kind)

    fetchImpl body:
      if body.startsWith('{') or body.startsWith('['):
        result = parseJson(body)
      else:
        echo resp.status, ": ", body, " --- url: ", url
        result = newJNull()

      let error = result.getError
      if error != null and error notin errorsToSkip:
        echo "Fetch error, API: ", url.path, ", error: ", error
        if error in {expiredToken, badToken, locked}:
          invalidate(session)
          raise rateLimitError()

proc fetchRaw*(req: ApiReq): Future[string] {.async.} =
  retry:
    var session = await getAndValidateSession(req)
    let url = req.toUrl(session.kind)

    fetchImpl result:
      if not (result.startsWith('{') or result.startsWith('[')):
        echo resp.status, ": ", result, " --- url: ", url
        result.setLen(0)
