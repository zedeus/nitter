import asyncdispatch, httpclient, times, sequtils, json, math
import strutils, strformat
import types, agents, consts, http_pool

var
  clientPool {.threadvar.}: HttpPool
  tokenPool {.threadvar.}: seq[Token]
  lastFailed: Time
  minFail = initDuration(seconds=10)

proc fetchToken(): Future[Token] {.async.} =
  if getTime() - lastFailed < minFail:
    return Token()

  let headers = newHttpHeaders({
    "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "accept-language": "en-US,en;q=0.5",
    "connection": "keep-alive",
    "user-agent": getAgent(),
    "authorization": auth
  })

  var
    resp: string
    tok: string

  try:
    resp = clientPool.use(headers): await c.postContent(activate)
    tok = parseJson(resp)["guest_token"].getStr

    let time = getTime()
    result = Token(tok: tok, remaining: 187, reset: time + 15.minutes,
                   init: time, lastUse: time)
  except Exception as e:
    lastFailed = getTime()
    result = Token()
    echo "fetching token failed: ", e.msg

proc expired(token: Token): bool {.inline.} =
  const
    expirationTime = 2.hours
    maxLastUse = 1.hours
  let time = getTime()
  result = token.init < time - expirationTime or
           token.lastUse < time - maxLastUse

proc isLimited(token: Token): bool {.inline.} =
  token == nil or (token.remaining <= 1 and token.reset > getTime()) or
    token.expired

proc release*(token: Token) =
  if token != nil and not token.expired:
    token.lastUse = getTime()
    tokenPool.insert(token)

proc getToken*(): Future[Token] {.async.} =
  for i in 0 ..< tokenPool.len:
    if not result.isLimited: break
    result.release()
    result = tokenPool.pop()

  if result.isLimited:
    result.release()
    result = await fetchToken()

proc poolTokens*(amount: int) {.async.} =
  var futs: seq[Future[Token]]
  for i in 0 ..< amount:
    futs.add fetchToken()

  for token in futs:
    release(await token)

proc initTokenPool*(cfg: Config) {.async.} =
  clientPool = HttpPool()

  while true:
    if tokenPool.countIt(not it.isLimited) < cfg.minTokens:
      await poolTokens(min(4, cfg.minTokens - tokenPool.len))
    await sleepAsync(2000)

proc getPoolInfo*: string =
  let avg = tokenPool.mapIt(it.remaining).sum()
  return &"{tokenPool.len} tokens, average remaining: {avg}"
