import asyncdispatch, times, strutils, options, tables
import redis, redpool, msgpack4nim
export redpool, msgpack4nim

import types, api

const redisNil = "\0\0"

var
  pool: RedisPool
  baseCacheTime = 60 * 60
  rssCacheTime: int
  listCacheTime*: int

proc setCacheTimes*(cfg: Config) =
  rssCacheTime = cfg.rssCacheTime * 60
  listCacheTime = cfg.listCacheTime * 60

proc initRedisPool*(cfg: Config) =
  try:
    pool = waitFor newRedisPool(cfg.redisConns, maxConns=cfg.redisMaxConns,
                                host=cfg.redisHost, port=cfg.redisPort)
  except OSError:
    echo "Failed to connect to Redis."
    quit(1)

template toKey(p: Profile): string = "p:" & toLower(p.username)
template toKey(v: Video): string = "v:" & v.videoId
template toKey(c: Card): string = "c:" & c.id
template toKey(l: List): string = toLower("l:" & l.username & '/' & l.name)
template toKey(t: Token): string = "t:" & t.tok

template to(s: string; typ: typedesc): untyped =
  var res: typ
  if s.len > 0:
    s.unpack(res)
  res

proc get(query: string): Future[string] {.async.} =
  pool.withAcquire(r):
    result = await r.get(query)

proc uncache*(id: int64) {.async.} =
  pool.withAcquire(r):
    discard await r.del("v:" & $id)

proc cache*[T](data: T; time=baseCacheTime) {.async.} =
  pool.withAcquire(r):
    discard await r.setex(data.toKey, time, pack(data))

proc cache*(data: PhotoRail; id: string) {.async.} =
  pool.withAcquire(r):
    discard await r.setex("pr:" & id, baseCacheTime, pack(data))

proc cache*(data: Profile; time=baseCacheTime) {.async.} =
  pool.withAcquire(r):
    r.startPipelining()
    discard await r.setex(data.toKey, time, pack(data))
    discard await r.hset("p:", toLower(data.username), data.id)
    discard await r.flushPipeline()

proc cacheRss*(query, rss, cursor: string) {.async.} =
  let key = "rss:" & query
  pool.withAcquire(r):
    r.startPipelining()
    await r.hmset(key, @[("rss", rss), ("min", cursor)])
    discard await r.expire(key, rssCacheTime)
    discard await r.flushPipeline()

proc getProfileId*(username: string): Future[string] {.async.} =
  pool.withAcquire(r):
    result = await r.hget("p:", toLower(username))
    if result == redisNil:
      result.setLen(0)

proc hasCachedProfile*(username: string): Future[Option[Profile]] {.async.} =
  let prof = await get("p:" & toLower(username))
  if prof != redisNil:
    result = some prof.to(Profile)

proc getCachedProfile*(username: string; fetch=true): Future[Profile] {.async.} =
  let prof = await get("p:" & toLower(username))
  if prof != redisNil:
    result = prof.to(Profile)
  else:
    result = await getProfile(username)
    if result.id.len > 0:
      await cache(result)

proc getCachedPhotoRail*(id: string): Future[PhotoRail] {.async.} =
  if id.len == 0: return
  let rail = await get("pr:" & toLower(id))
  if rail != redisNil:
    result = rail.to(PhotoRail)
  else:
    result = await getPhotoRail(id)
    await cache(result, id)

proc getCachedList*(username=""; name=""; id=""): Future[List] {.async.} =
  let list = if id.len > 0: redisNil
             else: await get(toLower("l:" & username & '/' & name))

  if list != redisNil:
    result = list.to(List)
  else:
    if id.len > 0:
      result = await getGraphListById(id)
    else:
      result = await getGraphList(username, name)
    await cache(result, time=listCacheTime)

proc getCachedRss*(key: string): Future[(string, string)] {.async.} =
  var res: Table[string, string]
  pool.withAcquire(r):
    res = await r.hgetall("rss:" & key)

  if "rss" in res:
    result = (res["rss"], res.getOrDefault("min"))
