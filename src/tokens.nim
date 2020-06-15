import options, asyncfutures, asyncdispatch, strutils, httpcore,
  httpclient, math, times, std/monotimes, hashes, deques

const
  window* = initDuration(minutes = 15)       ## after which the rate resets
  windowRate* = 187                          ## rate per window of token uses
  watermark* = int(0.80 * windowRate)        ## watermark (%) at which to grow
  lifetime* = initDuration(hours = 3)        ## maximum lifetime of a token
  minPoolSize = 1                            ## smallest possible pool
  maxPoolSize = 4096                         ## largest possible pool
  defaultPoolSize = 8                        ## default pool size, obvs
  fetchDelay = initDuration(seconds = 2)     ## pause between token fetches
  asyncSpin = initDuration(milliseconds = 1) ## delay while waiting for pool

type
  UseCount = range[0 .. windowRate]
  PoolSize = range[minPoolSize .. maxPoolSize]
  Token* = object
    uses: UseCount                          # number of uses in this period
    birth: MonoTime                         # when we created the token
    last: Duration                          # age of token at last fetch
    key: string                             # token value

  Pool = object
    size: PoolSize                          # pool size range
    q: Deque[Token]                         # pool contents
    hungry: bool                            # pool needs food
    rate: UseCount                          # usage estimate

proc `$`*(t: Token): string =
  result = t.key

proc fetch(): Future[Token] {.async.} =
  let
    headers = newHttpHeaders({
      "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
      "accept-language": "en-US,en;q=0.5",
      "connection": "keep-alive",
      "user-agent": "Mozilla/5.0 (X11; Linux x86_64; rv:75.0) Gecko/20100101 Firefox/75.0"
    })
  var client = newAsyncHttpClient(headers = headers)
  try:
    let reply = await client.getContent("https://twitter.com")
    let pos = reply.rfind("gt=")
    if pos == -1:
      raise newException(ValueError, "token parse fail")
    result = Token(key: reply[pos+3 .. pos+21], birth: getMonoTime())
  except Exception as e:
    echo "token fetch: ", e.msg
  finally:
    client.close()

proc kill(t: var Token) =
  ## force a token to die for whatever reason
  t.birth = t.birth - lifetime

proc age(t: Token): Duration =
  ## the age of the token
  result = getMonoTime() - t.birth

proc ready(t: Token): bool =
  ## true if the token is suitable for use
  result = t.uses < UseCount.high and t.age < lifetime

proc newPool(initialSize = defaultPoolSize): Pool =
  ## create a new pool object
  result = Pool(size: initialSize.nextPowerOfTwo)
  result.q = initDeque[Token](initialSize = result.size)

proc len*(p: Pool): int =
  ## the number of members in the pool
  result = len(p.q)

proc period(d: Duration): int =
  ## an index into the period of the token
  result = d.inSeconds.int div window.inSeconds.int

proc newRate(p: Pool; uses: int): UseCount =
  ## assess the latest usage rate for tokens
  # if a rate already exists
  if p.rate > 0 and len(p) > 0:
    # compute a new average using the token
    result = (p.rate div len(p)) * (len(p) - 1) + (uses div len(p))
  # otherwise, the latest usage is the rate
  if result == 0:
    result = uses

proc usage*(p: var Pool): string =
  ## a string that conveys the current usage level
  result = $(100 * (p.rate / windowRate))

var tokenPool = newPool()           ## global token pool

proc push(t: var Token) =
  ## add a token to the pool
  assert len(t.key) > 0
  if len(tokenPool) > maxPoolSize:
    echo "pool is too large at size ", $len(tokenPool)
  else:
    if t.age < lifetime:                    # the token yet lives!
      if t.last != default(Duration):       # is it a used token?
        if period(t.age) != period(t.last): # has the token been reset since?
          t.uses = UseCount.low             # okay; reset the use-count and
      tokenPool.rate = newRate(tokenPool, t.uses) # record new rate of usage
      addLast(tokenPool.q, t)                     # add the token to the pool

  block:
    if len(tokenPool) >= tokenPool.size:    # if we've enough tokens and
      if tokenPool.rate < watermark:        # the rate is low enough,
        break                               # then we're done

    # we need tokens!
    tokenPool.hungry = true                 # ask for another token

    echo "pool $1/$3; avg rate: $2" %   # and announce the fact
         [ $len(tokenPool), $tokenPool.usage, $tokenPool.size ]

proc tryPop(): Option[Token] =
  ## `true` if we were able to pop into `t`
  var t: Token
  while len(tokenPool) > 0 and result.isNone:
    t = popFirst(tokenPool.q)   # pop a token;
    if t.ready:                 # if it's ready to go,
      result = some(t)          # then we're done.
    else:                       # otherwise,
      push(t)                   # recycle it and continue

  if result.isSome:               # burnish a successful pop
    inc t.uses                    # increment the use counter
    t.last = t.age                # record the age at last use
    push(t)                       # recycle it

proc getToken*(): Future[Token] {.async.} =
  ## an asynchronous pop from the pool
  while true:
    var t = tryPop()
    if t.isSome:
      result = get(t)
      break
    await sleepAsync(asyncSpin.inMilliseconds.int)

proc emptyToken*(): Token =
  ## an empty token for the old api
  result = Token(birth: getMonoTime())
  kill result   # empty tokens start off dead and go downhill from there

proc remove*(t: Token) =
  ## remove a token from the pool
  var item: Token
  var count = len(tokenPool)
  while count > 0:                    # we know we'll spin at least this much
    var t = tryPop()                  # pop a token
    if t.isSome:                      # if successful,
      if item.key == get(t).key:      # if the key matches,
        kill item                     # kill the shit out of it
      push(item)                      # push it in any event;
      dec count                       # and decrement the counter
    else:
      break                           # a failure to pop means we're done

proc setTokenPoolSize*(size: int) =
  tokenPool.size = size

proc runTokenPool*() {.async.} =
  if len(tokenPool) < tokenPool.size:    # we will probably start off hungry
    tokenPool.hungry = true
  while true:
    if tokenPool.hungry:                   # if you're hungry,
      var token = await fetch()            # eat
      if token.ready:                      # if it's tasty,
        tokenPool.hungry = false           # hopefully, we're sated
        push(token)                        # stuff it in the queue
    if not tokenPool.hungry:               # now take a nap
      await sleepAsync fetchDelay.inMilliseconds.int
