import std/[strutils, tables, options]
import jsony
import user, tweet, utils, ../types/timeline
from ../../types import Result, User, Tweet

proc parseHook(s: string; i: var int; v: var Slice[int]) =
  var slice: array[2, int]
  parseHook(s, i, slice)
  v = slice[0] ..< slice[1]

proc getId(id: string): string {.inline.} =
  let start = id.rfind("-")
  if start < 0: return id
  id[start + 1 ..< id.len]

proc processTweet(id: string; objects: GlobalObjects;
                  userCache: var Table[string, User]): Tweet =
  let raw = objects.tweets[id]
  result = toTweet raw

  let uid = result.user.id
  if uid.len > 0 and uid in objects.users:
    if uid notin userCache:
      userCache[uid] = toUser objects.users[uid]
    result.user = userCache[uid]

  let rtId = raw.retweetedStatusIdStr
  if rtId.len > 0:
    if rtId in objects.tweets:
      result.retweet = some processTweet(rtId, objects, userCache)
    else:
      result.retweet = some Tweet(id: rtId.toId)

  let qId = raw.quotedStatusIdStr
  if qId.len > 0:
    if qId in objects.tweets:
      result.quote = some processTweet(qId, objects, userCache)
    else:
      result.quote = some Tweet(id: qId.toId)

proc parseCursor[T](e: Entry; result: var Result[T]) =
  let cursor = e.content.operation.cursor
  if cursor.cursorType == "Top":
    result.top = cursor.value
  elif cursor.cursorType == "Bottom":
    result.bottom = cursor.value

proc parseUsers*(json: string; after=""): Result[User] =
  result = Result[User](beginning: after.len == 0)

  let raw = json.fromJson(Search)
  if raw.timeline.instructions.len == 0:
    return

  for e in raw.timeline.instructions[0].addEntries.entries:
    let
      eId = e.entryId
      id = eId.getId

    if eId.startsWith("user") or eId.startsWith("sq-U"):
      if id in raw.globalObjects.users:
        result.content.add toUser raw.globalObjects.users[id]
    elif eId.startsWith("cursor") or eId.startsWith("sq-C"):
      parseCursor(e, result)

proc parseTweets*(json: string; after=""): Result[Tweet] =
  result = Result[Tweet](beginning: after.len == 0)

  let raw = json.fromJson(Search)
  if raw.timeline.instructions.len == 0:
    return

  var userCache: Table[string, User]

  for e in raw.timeline.instructions[0].addEntries.entries:
    let
      eId = e.entryId
      id = eId.getId

    if eId.startsWith("tweet") or eId.startsWith("sq-I-t"):
      if id in raw.globalObjects.tweets:
        result.content.add processTweet(id, raw.globalObjects, userCache)
    elif eId.startsWith("cursor") or eId.startsWith("sq-C"):
      parseCursor(e, result)
