import std/asyncfutures
import std/asyncdispatch
import std/os
import std/strutils
import std/httpcore
import std/httpclient
import std/math
import std/times
import std/monotimes
import std/hashes
import std/deques
import std/locks

when not compileOption("threads"):
  {.error: "tokens now require threads".}

const
  watermark* = 0.80                          ## watermark (%) at which to grow
  window* = initDuration(minutes = 15)       ## after which the rate resets
  windowRate* = 187                          ## rate per window of token uses
  lifetime* = initDuration(hours = 2)        ## maximum lifetime of a token
  minPoolSize* = 1                           ## smallest possible pool
  maxPoolSize* = 2048                        ## largest possible pool
  defaultPoolSize* = 8                       ## default pool size, obvs
  fetchDelay = initDuration(seconds = 2)     ## pause between token fetches
  asyncSpin = initDuration(milliseconds = 1) ## delay while waiting for pool

type
  UseCount = range[0 .. windowRate]
  PoolSize = range[minPoolSize .. maxPoolSize]
  Token = object
    uses: UseCount                          # number of uses in this period
    birth: MonoTime                         # when we created the token
    last: Duration                          # age of token at last fetch
    key: string                             # token value

  Pool[T] = object
    size: PoolSize                          # pool size range
    q: Deque[T]                             # pool contents
    busy: Lock                              # lock on pool
    hungry: Cond                            # pool needs food
    rate: UseCount                          # usage estimate
    fetcher: TokenThread

  Payload = object
    delay: Duration

  TokenThread = Thread[Payload]

proc fetch(): Token =
  let
    headers = newHttpHeaders({
      "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
      "accept-language": "en-US,en;q=0.5",
      "connection": "keep-alive",
      "user-agent": "Mozilla/5.0 (X11; Linux x86_64; rv:75.0) Gecko/20100101 Firefox/75.0"
    })
  var client = newHttpClient(headers = headers)
  try:
    let reply = client.getContent("https://twitter.com")
    let pos = reply.rfind("gt=")
    if pos == -1:
      raise newException(ValueError, "token parse fail")
    result = Token(key: reply[pos+3 .. pos+21], birth: getMonoTime())
  finally:
    client.close()

proc `$`*(t: Token): string =
  ## a convenience at best
  result = t.repr

proc hash*(t: Token): Hash =
  ## a unique hash value for the token
  var h: Hash = 0
  h = h !& hash(t.key)
  result = !$h

proc age(t: Token): Duration =
  ## the age of the token
  result = getMonoTime() - t.birth

proc ready(t: Token): bool =
  ## true if the token is suitable for use
  result = t.uses < UseCount.high and t.age < lifetime

proc `=destroy`[T](p: var Pool[T]) =
  ## prep a pool for freedom
  acquire p.busy               # make sure we are in control
  try:
    joinThreads(p.fetcher)     # shut down the token fetcher
  except Exception as e:
    echo "ignoring token thread error: " & e.msg
  finally:
    deinitCond p.hungry          # cleanup the condition variable
    clear p.q                    # clear the tokens cache
    deinitLock p.busy            # cleanup the busy lock

proc fetching(payload: Payload) {.thread.} =
  while true:
    let token = fetch()
    sleep(payload.delay.inMilliseconds.int)
    # XXX: stuff it in pool

proc init*(p: var Pool) =
  ## (re)initialize a previously-created pool
  initLock p.busy
  initCond p.hungry
  try:
    createThread(p.fetcher, fetching, Payload(delay: fetchDelay))
  finally:
    discard "it can throw and it's up to you to catch it"

proc newPool*[T](initialSize = defaultPoolSize): Pool[T] =
  ## create a new pool object
  result = Pool[T](size: initialSize.nextPowerOfTwo)
  result.q = initDeque[T](initialSize = result.size)

proc setLen*(p: var Pool; size: PoolSize) =
  ## set the maximum size of the pool
  p.size = size

proc len*(p: Pool): int =
  ## the number of members in the pool
  len(p.q)

proc period(d: Duration): int =
  ## an index into the period of the token
  result = d.inSeconds.int div window.inSeconds.int

proc newRate(p: var Pool; t: Token): UseCount =
  ## assess the latest usage rate for tokens
  # if a rate already exists
  if p.rate > 0 and len(p) > 0:
    # compute a new average using the token
    result = (p.rate div len(p)) * (len(p) - 1) + (t.uses div len(p))
  # otherwise, this token's usage is the rate
  if result == 0:
    result = t.uses

proc kill*(t: var Token) =
  ## force a token to die for whatever reason
  t.birth = t.birth - lifetime

proc usage*(p: var Pool): string =
  ## a string that conveys the current usage level
  result = $(p.rate / windowRate)

proc push*[T](p: var Pool[T]; t: var T; uses = 0) =
  ## add a token to the pool

  withLock p.busy:                          # grab the lock
    if t.age < lifetime:                    # the token yet lives!
      if t.last != default(Duration):       # is it a used token?
        if period(t.age) != period(t.last): # has the token been reset since?
          t.uses = UseCount.low             # okay; reset the use-count and
      t.uses = max(t.uses, uses)            # note any  hint as to uses, and
      addLast(p.q, t)                       # add the token to the pool
      p.rate = newRate(p, t)                # record new rate of usage

    block:
      if len(p) >= p.size:                       # if we've enough tokens and
        if p.rate < int(windowRate * watermark): # the rate is low enough,
          break                                  # then we're done

      # we need tokens!
      signal(p.hungry)                           # ask for another token
      echo "pool size $1; avg rate: $2" %        # and announce the fact
           [ $len(p), $p.usage ]

proc tryPop*[T](p: var Pool[T]; t: var T): bool =
  ## `true` if we were able to pop into `t`
  withLock p.busy:
    while len(p) > 0 and not result:
      t = popFirst(p.q)   # pop a token;
      if t.ready:         # if it's ready to go,
        result = true     # then we're done.
      else:               # otherwise,
        push(p, t)        # recycle it and continue

  if result:              # burnish a successful pop
    inc t.uses            # increment the use counter
    t.last = t.age        # record the age at last use

proc pop*[T](p: var Pool[T]): T =
  ## retrieve a member from the pool
  while true:
    if len(p) == 0:              # if there are no tokens,
      signal(p.hungry)           # ask for another token, then
      wait(p.hungry, p.busy)     # wait for a token to arrive
    else:                        # otherwise,
      if tryPop(p, result):      # if we can pop a token,
        break                    # we're done.

proc popAsync*[T](p: var Pool[T]): Future[T] {.async.} =
  ## an asynchronous pop from the pool
  while true:
    if tryPop(p, result):
      break
    await sleepAsync asyncSpin.inMilliseconds.int

#
# nitter api below
#

var tokenPool* = newPool[Token]()                ## global token pool

template withToken*(body: untyped): untyped =
  ## execute the body with an injected `token`.
  try:                                           # try to
    var token {.inject.} = popAsync(tokenPool)   # pop and inject a token,
    body                                         # run the provided body,
  finally:                                       # and finally,
    push(tokenPool, token)                       # return the token

proc getToken*(): Future[Token] {.async.} =
  result = await popAsync(tokenPool)
