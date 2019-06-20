import asyncdispatch, times
import types, api

withDb:
  try:
    createTables()
  except DbError:
    discard

var profileCacheTime = initDuration(seconds=60)

proc outdated(profile: Profile): bool =
  getTime() - profile.updated > profileCacheTime

proc getCachedProfile*(username: string; force=false): Future[Profile] {.async.} =
  withDb:
    try:
      result.getOne("username = ?", username)
      doAssert(not result.outdated())
    except:
      if result.id == 0:
        result = await getProfile(username)
        result.insert()
      elif result.outdated():
        let
          profile = await getProfile(username)
          oldId = result.id
        result = profile
        result.id = oldId
        result.update()
