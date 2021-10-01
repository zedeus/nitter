# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, times, strutils, tables, hashes
import redis, redpool, flatty, supersnappy

import types, api

const redisNil = "\0\0"

var
  pool {.threadvar.}: RedisPool
  baseCacheTime = 60 * 60
  rssCacheTime: int
  listCacheTime*: int

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
        discard await r.del(item)
      await r.setk(key, "true")
      discard await r.flushPipeline()

proc initRedisPool*(cfg: Config) {.async.} =
  try:
    pool = await newRedisPool(cfg.redisConns, cfg.redisMaxConns,
                              host=cfg.redisHost, port=cfg.redisPort,
                              password=cfg.redisPassword)

    await migrate("flatty", "*:*")
    await migrate("snappyRss", "rss:*")
    await migrate("userBuckets", "p:*")
    await migrate("profileDates", "p:*")

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

proc setex(key: string; time: int; data: string) {.async.} =
  pool.withAcquire(r):
    discard await r.setex(key, time, data)

proc cache*(data: List) {.async.} =
  await setex(data.listKey, listCacheTime, compress(toFlatty(data)))

proc cache*(data: PhotoRail; name: string) {.async.} =
  await setex("pr:" & name, baseCacheTime, compress(toFlatty(data)))

proc cache*(data: Recommendations; userId: string) {.async.} =
  await setex("rc:" & userId, listCacheTime, compress(toFlatty(data)))

proc cache*(data: Profile) {.async.} =
  if data.username.len == 0 or data.id.len == 0: return
  let name = toLower(data.username)
  pool.withAcquire(r):
    r.startPipelining()
    discard await r.setex(name.profileKey, baseCacheTime, compress(toFlatty(data)))
    discard await r.setex("i:" & data.id , baseCacheTime, data.username)
    discard await r.hset(name.pidKey, name, data.id)
    discard await r.flushPipeline()

proc cacheProfileId*(username, id: string) {.async.} =
  if username.len == 0 or id.len == 0: return
  let name = toLower(username)
  pool.withAcquire(r):
    discard await r.hset(name.pidKey, name, id)

proc cacheRss*(query: string; rss: Rss) {.async.} =
  let key = "rss:" & query
  pool.withAcquire(r):
    r.startPipelining()
    discard await r.hset(key, "rss", rss.feed)
    discard await r.hset(key, "min", rss.cursor)
    discard await r.expire(key, rssCacheTime)
    discard await r.flushPipeline()

proc getCachedRecommendations*(userId: string): Future[Recommendations] {.async.} =
  if userId.len == 0: return
  let recommendations = await get("rc:" & userId)
  if recommendations != redisNil:
    result = fromFlatty(uncompress(recommendations), Recommendations)
  else:
    result = await getRecommendations(userId)
    await cache(result, userId)

proc getProfileId*(username: string): Future[string] {.async.} =
  let name = toLower(username)
  pool.withAcquire(r):
    result = await r.hget(name.pidKey, name)
    if result == redisNil:
      result.setLen(0)

proc getCachedProfile*(username: string; fetch=true): Future[Profile] {.async.} =
  let prof = await get("p:" & toLower(username))
  if prof != redisNil:
    result = fromFlatty(uncompress(prof), Profile)
  elif fetch:
    result = await getProfile(username)

proc getCachedProfileUsername*(userId: string): Future[string] {.async.} =
  let username = await get("i:" & userId)
  if username != redisNil:
    result = username
  else:
    let profile = await getProfileById(userId)
    result = profile.username
    await cache(profile)

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
    result.cursor = await r.hget(k, "min")
    if result.cursor.len > 2:
      result.feed = await r.hget(k, "rss")
    else:
      result.cursor.setLen 0
