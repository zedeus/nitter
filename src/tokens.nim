import asyncdispatch, httpclient, times, sequtils, json, math, random
import strutils, strformat
import types, agents, consts, http_pool

const
  expirationTime = 3.hours
  maxLastUse = 1.hours
  resetPeriod = 15.minutes
  failDelay = initDuration(minutes=30)

var
  clientPool {.threadvar.}: HttpPool
  tokenPool {.threadvar.}: seq[Token]
  lastFailed: Time

proc getPoolInfo*: string =
  if tokenPool.len == 0: return "token pool empty"

  let avg = tokenPool.mapIt(it.remaining).sum() div tokenPool.len
  return &"{tokenPool.len} tokens, average remaining: {avg}"

proc rateLimitError*(): ref RateLimitError =
  newException(RateLimitError, "rate limited with " & getPoolInfo())

proc fetchToken(): Future[Token] {.async.} =
  if getTime() - lastFailed < failDelay:
    raise rateLimitError()

  let headers = newHttpHeaders({
    "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "accept-language": "en-US,en;q=0.5",
    "connection": "keep-alive",
    "user-agent": getAgent(),
    "authorization": auth
  })

  var
    resp: string
    tokNode: JsonNode
    tok: string

  try:
    resp = clientPool.use(headers): await c.postContent(activate)
    tokNode = parseJson(resp)["guest_token"]
    tok = tokNode.getStr($(tokNode.getInt))

    let time = getTime()
    result = Token(tok: tok, remaining: 187, reset: time + resetPeriod,
                   init: time, lastUse: time)
  except Exception as e:
    lastFailed = getTime()
    echo "fetching token failed: ", e.msg

template expired(token: Token): untyped =
  let time = getTime()
  token.init < time - expirationTime or
    token.lastUse < time - maxLastUse

template isLimited(token: Token): untyped =
  token == nil or (token.remaining <= 1 and token.reset > getTime()) or
    token.expired

proc release*(token: Token; invalid=false) =
  if token != nil and (invalid or token.expired):
    let idx = tokenPool.find(token)
    if idx > -1: tokenPool.delete(idx)

proc getToken*(): Future[Token] {.async.} =
  for i in 0 ..< tokenPool.len:
    if not result.isLimited: break
    release(result)
    result = tokenPool.sample()

  if result.isLimited:
    release(result)
    result = await fetchToken()
    tokenPool.add result

  if result == nil:
    raise rateLimitError()

  dec result.remaining

proc poolTokens*(amount: int) {.async.} =
  var futs: seq[Future[Token]]
  for i in 0 ..< amount:
    futs.add fetchToken()

  for token in futs:
    var newToken: Token

    try: newToken = await token
    except: discard

    if newToken != nil:
      tokenPool.add newToken

proc initTokenPool*(cfg: Config) {.async.} =
  clientPool = HttpPool()

  while true:
    if tokenPool.countIt(not it.isLimited) < cfg.minTokens:
      await poolTokens(min(4, cfg.minTokens - tokenPool.len))
    await sleepAsync(2000)
