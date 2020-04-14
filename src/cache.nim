import asyncdispatch, times, strutils
import norm/sqlite

import types, api/profile

template safeAddColumn(field: typedesc): untyped =
  try: field.addColumn
  except DbError: discard

dbFromTypes("cache.db", "", "", "", [Profile, Video])

withDb:
  Video.createTable(force=true)
  try: Profile.createTable()
  except DbError: discard

  safeAddColumn Profile.lowername
  safeAddColumn Profile.suspended

var profileCacheTime = initDuration(minutes=10)

proc isOutdated*(profile: Profile): bool =
  getTime() - profile.updated > profileCacheTime

proc cache*(profile: var Profile) =
  withDb:
    try:
      let p = Profile.getOne("lowername = ?", profile.lowername)
      profile.id = p.id
      profile.update()
    except KeyError:
      if profile.username.len > 0:
        profile.insert()

proc hasCachedProfile*(username: string): Option[Profile] =
  withDb:
    try:
      let p = Profile.getOne("lowername = ?", toLower(username))
      doAssert not p.isOutdated
      result = some p
    except AssertionError, KeyError:
      result = none Profile

proc getCachedProfile*(username, agent: string;
                       force=false): Future[Profile] {.async.} =
  withDb:
    try:
      result.getOne("lowername = ?", toLower(username))
      doAssert not result.isOutdated
    except AssertionError, KeyError:
      result = await getProfileFull(username, agent)
      cache(result)

proc setProfileCacheTime*(minutes: int) =
  profileCacheTime = initDuration(minutes=minutes)

proc cache*(video: var Video) =
  withDb:
    try:
      let v = Video.getOne("videoId = ?", video.videoId)
      video.id = v.id
      video.update()
    except KeyError:
      if video.videoId.len > 0:
        video.insert()

proc uncache*(id: int64) =
  withDb:
    try:
      var video = Video.getOne("videoId = ?", $id)
      video.delete()
    except:
      discard

proc getCachedVideo*(id: int64): Option[Video] =
  withDb:
    try:
      return some Video.getOne("videoId = ?", $id)
    except KeyError:
      return none Video

proc cacheCleaner*() {.async.} =
  while true:
    await sleepAsync(profileCacheTime.inMilliseconds.int)
    withDb:
      let up = "updated<" & $toUnix(getTime() - profileCacheTime)
      var profiles = Profile.getMany(10000, cond=up)
      var videos = Video.getMany(10000, cond=up)
      transaction:
        for p in profiles.mitems: delete(p)
        for v in videos.mitems: delete(v)
