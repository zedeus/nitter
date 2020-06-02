import asyncdispatch, httpclient, times, sequtils, strutils
import types

var tokenPool: seq[Token]

proc fetchToken(): Future[Token] {.async.} =
  let
    headers = newHttpHeaders({
      "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
      "accept-language": "en-US,en;q=0.5",
      "connection": "keep-alive",
      "user-agent": "Mozilla/5.0 (X11; Linux x86_64; rv:75.0) Gecko/20100101 Firefox/75.0"
    })
    client = newAsyncHttpClient(headers=headers)

  var resp: string

  try:
    resp = await client.getContent("https://twitter.com")
    client.close()
  except:
    echo "fetching token failed"
    return Token()

  let pos = resp.rfind("gt=")
  if pos == -1:
    echo "token parse fail"
    return Token()

  result = Token(tok: resp[pos+3 .. pos+21], remaining: 187,
                 reset: getTime() + 15.minutes, init: getTime())

proc expired(token: Token): bool {.inline.} =
  const expirationTime = 2.hours
  result = token.init < getTime() - expirationTime

proc isLimited(token: Token): bool {.inline.} =
  token == nil or token.remaining <= 1 and token.reset > getTime() or
    token.expired

proc release*(token: Token) =
  if token != nil and not token.expired:
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
  while true:
    if tokenPool.countIt(not it.isLimited) < cfg.minTokens:
      await poolTokens(min(4, cfg.minTokens - tokenPool.len))
    await sleepAsync(2000)
