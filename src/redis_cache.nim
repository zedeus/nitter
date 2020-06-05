import asyncdispatch, times, strutils, tables
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
template toKey(l: List): string = toLower("l:" & l.username & '/' & l.name)

template to(s: string; typ: typedesc): untyped =
  var res: typ
  if s.len > 0:
    s.unpack(res)
  res

proc get(query: string): Future[string] {.async.} =
  pool.withAcquire(r):
    result = await r.get(query)

proc setex(key: string; time: int; data: string) {.async.} =
  pool.withAcquire(r):
    discard await r.setex(key, time, data)

proc cache*(data: List) {.async.} =
  await setex(data.toKey, listCacheTime, data.pack)

proc cache*(data: PhotoRail; id: string) {.async.} =
  await setex("pr:" & id, baseCacheTime, data.pack)

proc cache*(data: Profile) {.async.} =
  if data.username.len == 0: return
  pool.withAcquire(r):
    r.startPipelining()
    discard await r.setex(data.toKey, baseCacheTime, pack(data))
    discard await r.hset("p:", toLower(data.username), data.id)
    discard await r.flushPipeline()

proc cacheProfileId*(username, id: string) {.async.} =
  if username.len == 0 or id.len == 0: return
  pool.withAcquire(r):
    discard await r.hset("p:", toLower(username), id)

proc cacheRss*(query, rss, cursor: string) {.async.} =
  let key = "rss:" & query
  pool.withAcquire(r):
    r.startPipelining()
    discard await r.hset(key, "rss", rss)
    discard await r.hset(key, "min", cursor)
    discard await r.expire(key, rssCacheTime)
    discard await r.flushPipeline()

proc getProfileId*(username: string): Future[string] {.async.} =
  pool.withAcquire(r):
    result = await r.hget("p:", toLower(username))
    if result == redisNil:
      result.setLen(0)

proc getCachedProfile*(username: string; fetch=true): Future[Profile] {.async.} =
  let prof = await get("p:" & toLower(username))
  if prof != redisNil:
    result = prof.to(Profile)
  elif fetch:
    result = await getProfile(username)

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
    await cache(result)

proc getCachedRss*(key: string): Future[(string, string)] {.async.} =
  var res: Table[string, string]
  pool.withAcquire(r):
    res = await r.hgetall("rss:" & key)

  if "rss" in res:
    result = (res["rss"], res.getOrDefault("min"))
