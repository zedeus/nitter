import asyncdispatch, times
import types, api

withDb:
  try:
    createTables()
  except DbError:
    discard

var profileCacheTime = initDuration(minutes=10)

proc outdated(profile: Profile): bool =
  getTime() - profile.updated > profileCacheTime

proc getCachedProfile*(username: string; force=false): Future[Profile] {.async.} =
  withDb:
    try:
      result.getOne("username = ?", username)
      doAssert not result.outdated()
    except AssertionError:
      var profile = await getProfile(username)
      profile.id = result.id
      result = profile
      result.update()
    except KeyError:
      result = await getProfile(username)
      if result.username.len > 0:
        result.insert()
