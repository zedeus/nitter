# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, times, strformat, strutils, tables, hashes
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
    await migrate("userType", "p:*")
    await migrate("verifiedType", "p:*")

    pool.withAcquire(r):
      # optimize memory usage for user ID buckets
      await r.configSet("hash-max-ziplist-entries", "1000")

  except OSError:
    stdout.write "Failed to connect to Redis.\n"
    stdout.flushFile
    quit(1)

template uidKey(name: string): string = "pid:" & $(hash(name) div 1_000_000)
template userKey(name: string): string = "p:" & name
template listKey(l: List): string = "l:" & l.id
template tweetKey(id: int64): string = "t:" & $id

proc get(query: string): Future[string] {.async.} =
  pool.withAcquire(r):
    result = await r.get(query)

proc setEx(key: string; time: int; data: string) {.async.} =
  pool.withAcquire(r):
    dawait r.setEx(key, time, data)

proc cacheUserId(username, id: string) {.async.} =
  if username.len == 0 or id.len == 0: return
  let name = toLower(username)
  pool.withAcquire(r):
    dawait r.hSet(name.uidKey, name, id)

proc cache*(data: List) {.async.} =
  await setEx(data.listKey, listCacheTime, compress(toFlatty(data)))

proc cache*(data: PhotoRail; name: string) {.async.} =
  await setEx("pr:" & toLower(name), baseCacheTime * 2, compress(toFlatty(data)))

proc cache*(data: User) {.async.} =
  if data.username.len == 0: return
  let name = toLower(data.username)
  await cacheUserId(name, data.id)
  pool.withAcquire(r):
    dawait r.setEx(name.userKey, baseCacheTime, compress(toFlatty(data)))

proc cache*(data: Tweet) {.async.} =
  if data.isNil or data.id == 0: return
  pool.withAcquire(r):
    dawait r.setEx(data.id.tweetKey, baseCacheTime, compress(toFlatty(data)))

proc cacheRss*(query: string; rss: Rss) {.async.} =
  let key = "rss:" & query
  pool.withAcquire(r):
    dawait r.hSet(key, "min", rss.cursor)
    if rss.cursor != "suspended":
      dawait r.hSet(key, "rss", compress(rss.feed))
    dawait r.expire(key, rssCacheTime)

template deserialize(data, T) =
  try:
    result = fromFlatty(uncompress(data), T)
  except:
    echo "Decompression failed($#): '$#'" % [astToStr(T), data]

proc getUserId*(username: string): Future[string] {.async.} =
  let name = toLower(username)
  pool.withAcquire(r):
    result = await r.hGet(name.uidKey, name)
    if result == redisNil:
      let user = await getGraphUser(username)
      if user.suspended:
        return "suspended"
      else:
        await all(cacheUserId(name, user.id), cache(user))
        return user.id

proc getCachedUser*(username: string; fetch=true): Future[User] {.async.} =
  let prof = await get("p:" & toLower(username))
  if prof != redisNil:
    prof.deserialize(User)
  elif fetch:
    result = await getGraphUser(username)
    await cache(result)

proc getCachedUsername*(userId: string): Future[string] {.async.} =
  let
    key = "i:" & userId
    username = await get(key)

  if username != redisNil:
    result = username
  else:
    let user = await getGraphUserById(userId)
    result = user.username
    await setEx(key, baseCacheTime, result)
    if result.len > 0 and user.id.len > 0:
      await all(cacheUserId(result, user.id), cache(user))

# proc getCachedTweet*(id: int64): Future[Tweet] {.async.} =
#   if id == 0: return
#   let tweet = await get(id.tweetKey)
#   if tweet != redisNil:
#     tweet.deserialize(Tweet)
#   else:
#     result = await getGraphTweetResult($id)
#     if not result.isNil:
#       await cache(result)

proc getCachedPhotoRail*(name: string): Future[PhotoRail] {.async.} =
  if name.len == 0: return
  let rail = await get("pr:" & toLower(name))
  if rail != redisNil:
    rail.deserialize(PhotoRail)
  else:
    result = await getPhotoRail(name)
    await cache(result, name)

proc getCachedList*(username=""; slug=""; id=""): Future[List] {.async.} =
  let list = if id.len == 0: redisNil
             else: await get("l:" & id)

  if list != redisNil:
    list.deserialize(List)
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
      if result.cursor != "suspended":
        let feed = await r.hGet(k, "rss")
        if feed.len > 0 and feed != redisNil:
          try: result.feed = uncompress feed
          except: echo "Decompressing RSS failed: ", feed
    else:
      result.cursor.setLen 0
