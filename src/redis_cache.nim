# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, times, strutils, tables, hashes
import redis, redpool, flatty, supersnappy

import types, api

const
  redisNil = "\0\0"
  baseCacheTime = 60 * 60

var
  pool: RedisPool
  rssCacheTime: int
  listCacheTime*: int

template dawait(future) =
  discard await future

# flatty can't serialize DateTime, so we need to define this
proc toFlatty*(s: var string, x: DateTime) =
  s.toFlatty(x.toTime().toUnix())

proc fromFlatty*(s: string, i: var int, x: var DateTime) =
  var unix: int64
  s.fromFlatty(i, unix)
  x = fromUnix(unix).utc()

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
        dawait r.del(item)
      await r.setk(key, "true")
      dawait r.flushPipeline()

proc initRedisPool*(cfg: Config) {.async.} =
  try:
    pool = await newRedisPool(cfg.redisConns, cfg.redisMaxConns,
                              host=cfg.redisHost, port=cfg.redisPort,
                              password=cfg.redisPassword)

    await migrate("flatty", "*:*")
    await migrate("snappyRss", "rss:*")
    await migrate("userBuckets", "p:*")
    await migrate("profileDates", "p:*")
    await migrate("profileStats", "p:*")

    pool.withAcquire(r):
      # optimize memory usage for profile ID buckets
      await r.configSet("hash-max-ziplist-entries", "1000")

  except OSError:
    stdout.write "Failed to connect to Redis.\n"
    stdout.flushFile
    quit(1)

template pidKey(name: string): string = "pid:" & $(hash(name) div 1_000_000)
template profileKey(name: string): string = "p:" & name
template listKey(l: List): string = "l:" & l.id

proc get(query: string): Future[string] {.async.} =
  pool.withAcquire(r):
    result = await r.get(query)

proc setEx(key: string; time: int; data: string) {.async.} =
  pool.withAcquire(r):
    dawait r.setEx(key, time, data)

proc cache*(data: List) {.async.} =
  await setEx(data.listKey, listCacheTime, compress(toFlatty(data)))

proc cache*(data: PhotoRail; name: string) {.async.} =
  await setEx("pr:" & toLower(name), baseCacheTime, compress(toFlatty(data)))

proc cache*(data: Profile) {.async.} =
  if data.username.len == 0: return
  let name = toLower(data.username)
  pool.withAcquire(r):
    dawait r.setEx(name.profileKey, baseCacheTime, compress(toFlatty(data)))
    if data.id.len > 0:
      dawait r.hSet(name.pidKey, name, data.id)

proc cacheProfileId(username, id: string) {.async.} =
  if username.len == 0 or id.len == 0: return
  let name = toLower(username)
  pool.withAcquire(r):
    dawait r.hSet(name.pidKey, name, id)

proc cacheRss*(query: string; rss: Rss) {.async.} =
  let key = "rss:" & query
  pool.withAcquire(r):
    dawait r.hSet(key, "rss", rss.feed)
    dawait r.hSet(key, "min", rss.cursor)
    dawait r.expire(key, rssCacheTime)

proc getProfileId*(username: string): Future[string] {.async.} =
  let name = toLower(username)
  pool.withAcquire(r):
    result = await r.hGet(name.pidKey, name)
    if result == redisNil:
      result.setLen(0)

proc getCachedProfile*(username: string; fetch=true): Future[Profile] {.async.} =
  let prof = await get("p:" & toLower(username))
  if prof != redisNil:
    result = fromFlatty(uncompress(prof), Profile)
  elif fetch:
    result = await getProfile(username)
    await cacheProfileId(result.username, result.id)
    if result.suspended:
      await cache(result)

proc getCachedProfileUsername*(userId: string): Future[string] {.async.} =
  let
    key = "i:" & userId
    username = await get(key)

  if username != redisNil:
    result = username
  else:
    let profile = await getProfileById(userId)
    result = profile.username
    await setEx(key, baseCacheTime, result)

proc getCachedPhotoRail*(name: string): Future[PhotoRail] {.async.} =
  if name.len == 0: return
  let rail = await get("pr:" & toLower(name))
  if rail != redisNil:
    result = fromFlatty(uncompress(rail), PhotoRail)
  else:
    result = await getPhotoRail(name)
    await cache(result, name)

proc getCachedList*(username=""; slug=""; id=""): Future[List] {.async.} =
  let list = if id.len == 0: redisNil
             else: await get("l:" & id)

  if list != redisNil:
    result = fromFlatty(uncompress(list), List)
  else:
    if id.len > 0:
      result = await getGraphList(id)
    else:
      result = await getGraphListBySlug(username, slug)
    await cache(result)

proc getCachedRss*(key: string): Future[Rss] {.async.} =
  let k = "rss:" & key
  pool.withAcquire(r):
    result.cursor = await r.hGet(k, "min")
    if result.cursor.len > 2:
      result.feed = await r.hGet(k, "rss")
    else:
      result.cursor.setLen 0
