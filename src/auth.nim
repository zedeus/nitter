#SPDX-License-Identifier: AGPL-3.0-only
import std/[asyncdispatch, times, json, random, sequtils, strutils, tables, packedsets, os]
import types
import experimental/parser/guestaccount

# max requests at a time per account to avoid race conditions
const
  maxConcurrentReqs = 2
  dayInSeconds = 24 * 60 * 60
  apiMaxReqs: Table[Api, int] = {
    Api.search: 50,
    Api.tweetDetail: 150,
    Api.photoRail: 180,
    Api.userTweets: 500,
    Api.userTweetsAndReplies: 500,
    Api.userMedia: 500,
    Api.userRestId: 500,
    Api.userScreenName: 500,
    Api.tweetResult: 500,
    Api.list: 500,
    Api.listTweets: 500,
    Api.listMembers: 500,
    Api.listBySlug: 500
  }.toTable

var
  accountPool: seq[GuestAccount]
  enableLogging = false

template log(str: varargs[string, `$`]) =
  if enableLogging: echo "[accounts] ", str.join("")

proc snowflakeToEpoch(flake: int64): int64 =
  int64(((flake shr 22) + 1288834974657) div 1000)

proc hasExpired(account: GuestAccount): bool =
  let
    created = snowflakeToEpoch(account.id)
    now = epochTime().int64
    daysOld = int(now - created) div dayInSeconds
  return daysOld > 30

proc getAccountPoolHealth*(): JsonNode =
  let now = epochTime().int

  var
    totalReqs = 0
    limited: PackedSet[int64]
    reqsPerApi: Table[string, int]
    oldest = now.int64
    newest = 0'i64
    average = 0'i64

  for account in accountPool:
    let created = snowflakeToEpoch(account.id)
    if created > newest:
      newest = created
    if created < oldest:
      oldest = created
    average += created

    for api in account.apis.keys:
      let
        apiStatus = account.apis[api]
        reqs = apiMaxReqs[api] - apiStatus.remaining

      if apiStatus.limited:
        limited.incl account.id

      # no requests made with this account and endpoint since the limit reset
      if apiStatus.reset < now:
        continue

      reqsPerApi.mgetOrPut($api, 0).inc reqs
      totalReqs.inc reqs

  if accountPool.len > 0:
    average = average div accountPool.len
  else:
    oldest = 0
    average = 0

  return %*{
    "accounts": %*{
      "total": accountPool.len,
      "limited": limited.card,
      "oldest": $fromUnix(oldest),
      "newest": $fromUnix(newest),
      "average": $fromUnix(average)
    },
    "requests": %*{
      "total": totalReqs,
      "apis": reqsPerApi
    }
  }

proc getAccountPoolDebug*(): JsonNode =
  let now = epochTime().int
  var list = newJObject()

  for account in accountPool:
    let accountJson = %*{
      "apis": newJObject(),
      "pending": account.pending,
    }

    for api in account.apis.keys:
      let
        apiStatus = account.apis[api]
        obj = %*{}

      if apiStatus.reset > now.int:
        obj["remaining"] = %apiStatus.remaining

      if "remaining" notin obj and not apiStatus.limited:
        continue

      if apiStatus.limited:
        obj["limited"] = %true

      accountJson{"apis", $api} = obj
      list[$account.id] = accountJson

  return %list

proc rateLimitError*(): ref RateLimitError =
  newException(RateLimitError, "rate limited")

proc isLimited(account: GuestAccount; api: Api): bool =
  if account.isNil:
    return true

  if api in account.apis:
    let limit = account.apis[api]

    if limit.limited and (epochTime().int - limit.limitedAt) > dayInSeconds:
      account.apis[api].limited = false
      log "resetting limit, api: ", api, ", id: ", account.id

    return limit.limited or (limit.remaining <= 10 and limit.reset > epochTime().int)
  else:
    return false

proc isReady(account: GuestAccount; api: Api): bool =
  not (account.isNil or account.pending > maxConcurrentReqs or account.isLimited(api))

proc invalidate*(account: var GuestAccount) =
  if account.isNil: return
  log "invalidating expired account: ", account.id

  # TODO: This isn't sufficient, but it works for now
  let idx = accountPool.find(account)
  if idx > -1: accountPool.delete(idx)
  account = nil

proc release*(account: GuestAccount) =
  if account.isNil: return
  dec account.pending

proc getGuestAccount*(api: Api): Future[GuestAccount] {.async.} =
  for i in 0 ..< accountPool.len:
    if result.isReady(api): break
    result = accountPool.sample()

  if not result.isNil and result.isReady(api):
    inc result.pending
  else:
    log "no accounts available for API: ", api
    raise rateLimitError()

proc setLimited*(account: GuestAccount; api: Api) =
  account.apis[api].limited = true
  account.apis[api].limitedAt = epochTime().int
  log "rate limited, api: ", api, ", reqs left: ", account.apis[api].remaining, ", id: ", account.id

proc setRateLimit*(account: GuestAccount; api: Api; remaining, reset: int) =
  # avoid undefined behavior in race conditions
  if api in account.apis:
    let limit = account.apis[api]
    if limit.reset >= reset and limit.remaining < remaining:
      return
    if limit.reset == reset and limit.remaining >= remaining:
      account.apis[api].remaining = remaining
      return

  account.apis[api] = RateLimit(remaining: remaining, reset: reset)

proc initAccountPool*(cfg: Config; path: string) =
  enableLogging = cfg.enableDebug

  let jsonlPath = if path.endsWith(".json"): (path & 'l') else: path

  if fileExists(jsonlPath):
    log "Parsing JSONL guest accounts file: ", jsonlPath
    for line in jsonlPath.lines:
      accountPool.add parseGuestAccount(line)
  elif fileExists(path):
    log "Parsing JSON guest accounts file: ", path
    accountPool = parseGuestAccounts(path)
  else:
    echo "[accounts] ERROR: ", path, " not found. This file is required to authenticate API requests."
    quit 1

  let accountsPrePurge = accountPool.len
  #accountPool.keepItIf(not it.hasExpired)

  log "Successfully added ", accountPool.len, " valid accounts."
  if accountsPrePurge > accountPool.len:
    log "Purged ", accountsPrePurge - accountPool.len, " expired accounts."
