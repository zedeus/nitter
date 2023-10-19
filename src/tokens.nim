#SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, times, json, random, strutils, tables, sets
import types

# max requests at a time per account to avoid race conditions
const
  maxConcurrentReqs = 2
  dayInSeconds = 24 * 60 * 60

var
  accountPool: seq[GuestAccount]
  enableLogging = false

template log(str: varargs[string, `$`]) =
  if enableLogging: echo "[accounts] ", str.join("")

proc getPoolJson*(): JsonNode =
  var
    list = newJObject()
    totalReqs = 0
    totalPending = 0
    limited: HashSet[string]
    reqsPerApi: Table[string, int]

  let now = epochTime().int

  for account in accountPool:
    totalPending.inc(account.pending)

    var includeAccount = false
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
        limited.incl account.id

      accountJson{"apis", $api} = obj
      includeAccount = true

      let
        maxReqs =
          case api
          of Api.search: 50
          of Api.tweetDetail: 150
          of Api.photoRail: 180
          of Api.userTweets, Api.userTweetsAndReplies, Api.userMedia,
             Api.userRestId, Api.userScreenName,
             Api.tweetResult,
             Api.list, Api.listTweets, Api.listMembers, Api.listBySlug: 500
        reqs = maxReqs - apiStatus.remaining

      reqsPerApi[$api] = reqsPerApi.getOrDefault($api, 0) + reqs
      totalReqs.inc(reqs)

    if includeAccount:
      list[account.id] = accountJson

  return %*{
    "amount": accountPool.len,
    "limited": limited.card,
    "requests": totalReqs,
    "pending": totalPending,
    "apis": reqsPerApi,
    "accounts": list
  }

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

proc initAccountPool*(cfg: Config; accounts: JsonNode) =
  enableLogging = cfg.enableDebug

  for account in accounts:
    accountPool.add GuestAccount(
      id: account{"user", "id_str"}.getStr,
      oauthToken: account{"oauth_token"}.getStr,
      oauthSecret: account{"oauth_token_secret"}.getStr,
    )
