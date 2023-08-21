# SPDX-License-Identifier: AGPL-3.0-only
import httpclient, asyncdispatch, options, strutils, uri, times, math, tables
import jsony, packedjson, zippy, oauth1
import types, tokens, consts, parserutils, http_pool
import experimental/types/common

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
    result &= ("include_ext_alt_text", "1")
    result &= ("include_ext_media_stats", "1")
    result &= ("include_ext_media_availability", "1")
  if count.len > 0:
    result &= ("count", count)
  if cursor.len > 0:
    # The raw cursor often has plus signs, which sometimes get turned into spaces,
    # so we need to turn them back into a plus
    if " " in cursor:
      result &= ("cursor", cursor.replace(" ", "+"))
    else:
      result &= ("cursor", cursor)

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
    "authority": "api.twitter.com",
    "accept-encoding": "gzip",
    "accept-language": "en-US,en;q=0.9",
    "accept": "*/*",
    "DNT": "1"
  })

template updateAccount() =
  if resp.headers.hasKey(rlRemaining):
    let
      remaining = parseInt(resp.headers[rlRemaining])
      reset = parseInt(resp.headers[rlReset])
    account.setRateLimit(api, remaining, reset)

template fetchImpl(result, fetchBody) {.dirty.} =
  once:
    pool = HttpPool()

  var account = await getGuestAccount(api)
  if account.oauthToken.len == 0:
    raise rateLimitError()

  try:
    var resp: AsyncResponse
    pool.use(genHeaders($url, account.oauthToken, account.oauthSecret)):
      template getContent =
        resp = await c.get($url)
        result = await resp.body

      getContent()

      if resp.status == $Http503:
        badClient = true
        raise newException(BadClientError, "Bad client")

    if result.len > 0:
      if resp.headers.getOrDefault("content-encoding") == "gzip":
        result = uncompress(result, dfGzip)
      else:
        echo "non-gzip body, url: ", url, ", body: ", result

    fetchBody

    release(account, used=true)

    if resp.status == $Http400:
      raise newException(InternalError, $url)
  except InternalError as e:
    raise e
  except BadClientError as e:
    release(account, used=true)
    raise e
  except Exception as e:
    echo "error: ", e.name, ", msg: ", e.msg, ", accountId: ", account.id, ", url: ", url
    if "length" notin e.msg and "descriptor" notin e.msg:
      release(account, invalid=true)
    raise rateLimitError()

proc fetch*(url: Uri; api: Api): Future[JsonNode] {.async.} =
  var body: string
  fetchImpl body:
    if body.startsWith('{') or body.startsWith('['):
      result = parseJson(body)
    else:
      echo resp.status, ": ", body, " --- url: ", url
      result = newJNull()

    updateAccount()

    let error = result.getError
    if error in {invalidToken, badToken}:
      echo "fetch error: ", result.getError
      release(account, invalid=true)
      raise rateLimitError()

    if body.startsWith("{\"errors"):
      let errors = body.fromJson(Errors)
      if errors in {invalidToken, badToken}:
        echo "fetch error: ", errors
        release(account, invalid=true)
        raise rateLimitError()
      elif errors in {rateLimited}:
        account.apis[api].limited = true
        account.apis[api].limitedAt = epochTime().int
        echo "[accounts] rate limited, api: ", api, ", reqs left: ", account.apis[api].remaining, ", id: ", account.id

proc fetchRaw*(url: Uri; api: Api): Future[string] {.async.} =
  fetchImpl result:
    if not (result.startsWith('{') or result.startsWith('[')):
      echo resp.status, ": ", result, " --- url: ", url
      result.setLen(0)

    updateAccount()

    if result.startsWith("{\"errors"):
      let errors = result.fromJson(Errors)
      if errors in {invalidToken, badToken}:
        echo "fetch error: ", errors
        release(account, invalid=true)
        raise rateLimitError()
