import asyncdispatch, times, strutils, tables
import redis, redpool, frosty, snappy

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

proc migrate*(key, match: string) {.async.} =
  pool.withAcquire(r):
    let hasKey = await r.get(key)
    if hasKey == redisNil:
      let list = await r.scan(newCursor(0), match, 100000)
      r.startPipelining()
      for item in list:
        if item != "p:":
          discard await r.del(item)
      await r.setk(key, "true")
      discard await r.flushPipeline()

proc initRedisPool*(cfg: Config) {.async.} =
  try:
    pool = await newRedisPool(cfg.redisConns, maxConns=cfg.redisMaxConns,
                              host=cfg.redisHost, port=cfg.redisPort)

    await migrate("snappyRss", "rss:*")
    await migrate("frosty", "*")

  except OSError:
    stdout.write "Failed to connect to Redis.\n"
    stdout.flushFile
    quit(1)

template toKey(p: Profile): string = "p:" & toLower(p.username)
template toKey(l: List): string = toLower("l:" & l.username & '/' & l.name)

proc get(query: string): Future[string] {.async.} =
  pool.withAcquire(r):
    result = await r.get(query)

proc setex(key: string; time: int; data: string) {.async.} =
  pool.withAcquire(r):
    discard await r.setex(key, time, data)

proc cache*(data: List) {.async.} =
  await setex(data.toKey, listCacheTime, compress(freeze(data)))

proc cache*(data: PhotoRail; id: string) {.async.} =
  await setex("pr:" & id, baseCacheTime, compress(freeze(data)))

proc cache*(data: Profile) {.async.} =
  if data.username.len == 0: return
  pool.withAcquire(r):
    r.startPipelining()
    discard await r.setex(data.toKey, baseCacheTime, compress(freeze(data)))
    discard await r.hset("p:", toLower(data.username), data.id)
    discard await r.flushPipeline()

proc cacheProfileId*(username, id: string) {.async.} =
  if username.len == 0 or id.len == 0: return
  pool.withAcquire(r):
    discard await r.hset("p:", toLower(username), id)

proc cacheRss*(query: string; rss: Rss) {.async.} =
  let key = "rss:" & query
  pool.withAcquire(r):
    r.startPipelining()
    discard await r.hset(key, "rss", rss.feed)
    discard await r.hset(key, "min", rss.cursor)
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
    uncompress(prof).thaw(result)
  elif fetch:
    result = await getProfile(username)

proc getCachedPhotoRail*(id: string): Future[PhotoRail] {.async.} =
  if id.len == 0: return
  let rail = await get("pr:" & toLower(id))
  if rail != redisNil:
    uncompress(rail).thaw(result)
  else:
    result = await getPhotoRail(id)
    await cache(result, id)

proc getCachedList*(username=""; name=""; id=""): Future[List] {.async.} =
  let list = if id.len > 0: redisNil
             else: await get(toLower("l:" & username & '/' & name))

  if list != redisNil:
    uncompress(list).thaw(result)
  else:
    if id.len > 0:
      result = await getGraphListById(id)
    else:
      result = await getGraphList(username, name)
    await cache(result)

proc getCachedRss*(key: string): Future[Rss] {.async.} =
  let k = "rss:" & key
  pool.withAcquire(r):
    result.cursor = await r.hget(k, "min")
    if result.cursor.len > 2:
      result.feed = await r.hget(k, "rss")
    else:
      result.cursor.setLen 0
