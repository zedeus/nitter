#i hate begging for this too em SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, times, json, random, strutils, tables
import types

# max requests at a time per account to avoid race conditions
const
  maxConcurrentReqs = 2
  dayInSeconds = 24 * 60 * 60

var
  accountPool: seq[GuestAccount]
  enableLogging = false

template log(str) =
  if enableLogging: echo "[accounts] ", str

proc getPoolJson*(): JsonNode =
  var
    list = newJObject()
    totalReqs = 0
    totalPending = 0
    totalLimited = 0
    reqsPerApi: Table[string, int]

  let now = epochTime().int

  for account in accountPool:
    totalPending.inc(account.pending)
    list[account.id] = %*{
      "apis": newJObject(),
      "pending": account.pending,
    }

    for api in account.apis.keys:
      let
        apiStatus = account.apis[api]
        obj = %*{}

      if apiStatus.limited:
        obj["limited"] = %true
        inc totalLimited

      if apiStatus.reset > now.int:
        obj["remaining"] = %apiStatus.remaining

      if "remaining" notin obj and not apiStatus.limited:
        continue

      list[account.id]["apis"][$api] = obj

      let
        maxReqs =
          case api
          of Api.search: 50
          of Api.tweetDetail: 150
          of Api.photoRail: 180
          of Api.userTweets, Api.userTweetsAndReplies, Api.userMedia,
             Api.userRestId, Api.userScreenName, Api.tweetResult,
             Api.list, Api.listTweets, Api.listMembers, Api.listBySlug: 500
          of Api.userSearch: 900
        reqs = maxReqs - apiStatus.remaining

      reqsPerApi[$api] = reqsPerApi.getOrDefault($api, 0) + reqs
      totalReqs.inc(reqs)

  return %*{
    "amount": accountPool.len,
    "limited": totalLimited,
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
      log "resetting limit, api: " & $api & ", id: " & $account.id

    return limit.limited or (limit.remaining <= 10 and limit.reset > epochTime().int)
  else:
    return false

proc isReady(account: GuestAccount; api: Api): bool =
  not (account.isNil or account.pending > maxConcurrentReqs or account.isLimited(api))

proc release*(account: GuestAccount; used=false; invalid=false) =
  if account.isNil: return
  if invalid:
    log "discarding invalid account: " & account.id

    let idx = accountPool.find(account)
    if idx > -1: accountPool.delete(idx)
  elif used:
    dec account.pending

proc getGuestAccount*(api: Api): Future[GuestAccount] {.async.} =
  for i in 0 ..< accountPool.len:
    if result.isReady(api): break
    release(result)
    result = accountPool.sample()

  if not result.isNil and result.isReady(api):
    inc result.pending
  else:
    log "no accounts available for API: " & $api
    raise rateLimitError()

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
