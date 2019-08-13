import asyncdispatch, times
import types, api

withCustomDb("cache.db", "", "", ""):
  try:
    createTables()
  except DbError:
    discard

var profileCacheTime = initDuration(minutes=10)

proc isOutdated*(profile: Profile): bool =
  getTime() - profile.updated > profileCacheTime

proc cache*(profile: var Profile) =
  withCustomDb("cache.db", "", "", ""):
    try:
      let p = Profile.getOne("lower(username) = ?", toLower(profile.username))
      profile.id = p.id
      profile.update()
    except KeyError:
      if profile.username.len > 0:
        profile.insert()

proc hasCachedProfile*(username: string): Option[Profile] =
  withCustomDb("cache.db", "", "", ""):
    try:
      let p = Profile.getOne("lower(username) = ?", toLower(username))
      doAssert not p.isOutdated
      result = some(p)
    except AssertionError, KeyError:
      result = none(Profile)

proc getCachedProfile*(username, agent: string; force=false): Future[Profile] {.async.} =
  withCustomDb("cache.db", "", "", ""):
    try:
      result.getOne("lower(username) = ?", toLower(username))
      doAssert not result.isOutdated
    except AssertionError, KeyError:
      result = await getProfileFull(username)
      cache(result)

proc setProfileCacheTime*(minutes: int) =
  profileCacheTime = initDuration(minutes=minutes)
