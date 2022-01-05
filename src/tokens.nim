# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, httpclient, times, sequtils, json, random
import strutils, tables
import zippy
import types, agents, consts, http_pool

const
  maxConcurrentReqs = 5  # max requests at a time per token, to avoid race conditions
  maxAge = 3.hours       # tokens expire after 3 hours
  maxLastUse = 1.hours   # if a token is unused for 60 minutes, it expires
  failDelay = initDuration(minutes=30)

var
  clientPool: HttpPool
  tokenPool: seq[Token]
  lastFailed: Time

proc getPoolJson*: string =
  let list = newJObject()
  for token in tokenPool:
    list[token.tok] = %*{
      "apis": newJObject(),
      "pending": token.pending,
      "init": $token.init,
      "lastUse": $token.lastUse
    }

    for api in token.apis.keys:
      list[token.tok]["apis"][$api] = %token.apis[api]
  return $list

proc rateLimitError*(): ref RateLimitError =
  newException(RateLimitError, "rate limited")

proc fetchToken(): Future[Token] {.async.} =
  if getTime() - lastFailed < failDelay:
    raise rateLimitError()

  let headers = newHttpHeaders({
    "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "accept-encoding": "gzip",
    "accept-language": "en-US,en;q=0.5",
    "connection": "keep-alive",
    "user-agent": getAgent(),
    "authorization": auth
  })

  try:
    let
      resp = clientPool.use(headers): await c.postContent(activate)
      tokNode = parseJson(uncompress(resp))["guest_token"]
      tok = tokNode.getStr($(tokNode.getInt))
      time = getTime()

    return Token(tok: tok, init: time, lastUse: time)
  except Exception as e:
    lastFailed = getTime()
    echo "fetching token failed: ", e.msg

proc expired(token: Token): bool =
  let time = getTime()
  token.init < time - maxAge or token.lastUse < time - maxLastUse

proc isLimited(token: Token; api: Api): bool =
  if token.isNil or token.expired:
    return true

  if api in token.apis:
    let limit = token.apis[api]
    return (limit.remaining <= 10 and limit.reset > epochTime().int)
  else:
    return false

proc isReady(token: Token; api: Api): bool =
  not (token.isNil or token.pending > maxConcurrentReqs or token.isLimited(api))

proc release*(token: Token; used=false; invalid=false) =
  if token.isNil: return
  if invalid or token.expired:
    let idx = tokenPool.find(token)
    if idx > -1: tokenPool.delete(idx)
  elif used:
    dec token.pending
    token.lastUse = getTime()

proc getToken*(api: Api): Future[Token] {.async.} =
  for i in 0 ..< tokenPool.len:
    if result.isReady(api): break
    release(result)
    result = tokenPool.sample()

  if not result.isReady(api):
    release(result)
    result = await fetchToken()
    tokenPool.add result

  if not result.isNil:
    inc result.pending
  else:
    raise rateLimitError()

proc setRateLimit*(token: Token; api: Api; remaining, reset: int) =
  # avoid undefined behavior in race conditions
  if api in token.apis:
    let limit = token.apis[api]
    if limit.reset >= reset and limit.remaining < remaining:
      return

  token.apis[api] = RateLimit(remaining: remaining, reset: reset)

proc poolTokens*(amount: int) {.async.} =
  var futs: seq[Future[Token]]
  for i in 0 ..< amount:
    futs.add fetchToken()

  for token in futs:
    var newToken: Token

    try: newToken = await token
    except: discard

    if not newToken.isNil:
      tokenPool.add newToken

proc initTokenPool*(cfg: Config) {.async.} =
  clientPool = HttpPool()

  while true:
    if tokenPool.countIt(not it.isLimited(Api.timeline)) < cfg.minTokens:
      await poolTokens(min(4, cfg.minTokens - tokenPool.len))
    await sleepAsync(2000)
