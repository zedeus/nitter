import asyncdispatch, times, strutils
import types, api

dbFromTypes("cache.db", "", "", "", [Profile, Video])

withDb:
  try:
    createTables()
  except DbError:
    discard

var profileCacheTime = initDuration(minutes=10)

proc isOutdated*(profile: Profile): bool =
  getTime() - profile.updated > profileCacheTime

proc cache*(profile: var Profile) =
  withDb:
    try:
      let p = Profile.getOne("lower(username) = ?", toLower(profile.username))
      profile.id = p.id
      profile.update()
    except KeyError:
      if profile.username.len > 0:
        profile.insert()

proc hasCachedProfile*(username: string): Option[Profile] =
  withDb:
    try:
      let p = Profile.getOne("lower(username) = ?", toLower(username))
      doAssert not p.isOutdated
      result = some(p)
    except AssertionError, KeyError:
      result = none(Profile)

proc getCachedProfile*(username, agent: string; force=false): Future[Profile] {.async.} =
  withDb:
    try:
      result.getOne("lower(username) = ?", toLower(username))
      doAssert not result.isOutdated
    except AssertionError, KeyError:
      result = await getProfileFull(username)
      cache(result)

proc setProfileCacheTime*(minutes: int) =
  profileCacheTime = initDuration(minutes=minutes)
