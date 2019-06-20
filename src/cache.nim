import sharedtables, times, hashes
import types, api

# var
#   profileCache: SharedTable[int, Profile]
#   profileCacheTime = initDuration(seconds=10)

# profileCache.init()

proc getCachedProfile*(username: string; force=false): Profile =
  return getProfile(username)
  # let index = username.hash

  # try:
  #   result = profileCache.mget(index)
  #   # if force or getTime() - result.lastUpdated > profileCacheTime:
  #   #   result = getProfile(username)
  #   #   profileCache[username.hash] = deepCopy(result)
  #   #   return
  # except KeyError:
  #   # result = getProfile(username)
  #   # profileCache.add(username.hash, deepCopy(result))



  #   var profile: Profile
  #   profileCache.withKey(index) do (k: int, v: var Profile, pairExists: var bool):
  #     v = getProfile(username)
  #     profile = v
  #     echo v
  #     pairExists = true
  #   echo profile.username
  #   return profile

  # profileCache.withValue(hash(username), value) do:
  #   if getTime() - value.lastUpdated > profileCacheTime or force:
  #     result = getProfile(username)
  #     value = result
  #   else:
  #     result = value
  # do:
  #   result = getProfile(username)
  #   value = result

  # var profile: Profile

  # profileCache.withKey(username.hash) do (k: int, v: var Profile, pairExists: var bool):
  #   if pairExists and getTime() - v.lastUpdated < profileCacheTime and not force:
  #     profile = deepCopy(v)
  #     echo "cached"
  #   else:
  #     profile = getProfile(username)
  #     v = deepCopy(profile)
  #     pairExists = true
  #     echo "fetched"

  # return profile

  # try:
  #   result = profileCache.mget(username.hash)
  #   if force or getTime() - result.lastUpdated > profileCacheTime:
  #     result = getProfile(username)
  #     profileCache[username.hash] = deepCopy(result)
  #     return
  # except KeyError:
  #   result = getProfile(username)
  #   profileCache.add(username.hash, deepCopy(result))

  # if not result.isNil or force or
  #   getTime() - result.lastUpdated > profileCacheTime:
  #   result = getProfile(username)
  #   profileCache[username] = result
    # return

