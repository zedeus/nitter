import strutils, strformat, sequtils, tables, uri

import types

const
  separators = @["AND", "OR"]
  validFilters* = @[
    "media", "images", "twimg", "videos",
    "native_video", "consumer_video", "pro_video",
    "links", "news", "quote", "mentions",
    "replies", "retweets", "nativeretweets",
    "verified", "safe"
  ]

template `@`(param: string): untyped =
  if param in pms: pms[param]
  else: ""

proc initQuery*(pms: Table[string, string]; name=""): Query =
  result = Query(
    kind: parseEnum[QueryKind](@"f", tweets),
    text: @"q",
    filters: validFilters.filterIt("f-" & it in pms),
    excludes: validFilters.filterIt("e-" & it in pms),
    since: @"since",
    until: @"until",
    near: @"near"
  )

  if name.len > 0:
    result.fromUser = name.split(",")

  if @"e-nativeretweets".len == 0:
    result.includes.add "nativeretweets"

proc getMediaQuery*(name: string): Query =
  Query(
    kind: media,
    filters: @["twimg", "native_video"],
    fromUser: @[name],
    sep: "OR"
  )

proc getReplyQuery*(name: string): Query =
  Query(
    kind: replies,
    includes: @["nativeretweets"],
    fromUser: @[name]
  )

proc genQueryParam*(query: Query): string =
  var filters: seq[string]
  var param: string

  if query.kind == users:
    return query.text

  # improve no-replies result only when searching for less than 7
  # otherwise multi-timeline limit goes down to 8 users
  let rewriteReplies = "replies" in query.excludes and query.fromUser.len < 7

  for i, user in query.fromUser:
    if rewriteReplies:
      param &= &"(from:{user} AND (to:{user} OR -filter:replies)) "
    else:
      param &= &"from:{user} "

    if i < query.fromUser.high:
      param &= "OR "

  for f in query.filters:
    filters.add "filter:" & f
  for e in query.excludes:
    if rewriteReplies and e == "replies": continue
    filters.add "-filter:" & e
  for i in query.includes:
    filters.add "include:" & i

  result = strip(param & filters.join(&" {query.sep} "))
  if query.since.len > 0:
    result &= " since:" & query.since
  if query.until.len > 0:
    result &= " until:" & query.until
  if query.near.len > 0:
    result &= &" near:\"{query.near}\" within:15mi"
  if query.text.len > 0:
    result &= " " & query.text

proc genQueryUrl*(query: Query): string =
  if query.kind notin {tweets, users}: return

  var params = @[&"f={query.kind}"]
  if query.text.len > 0:
    params.add "q=" & encodeUrl(query.text)
  for f in query.filters:
    params.add "f-" & f & "=on"
  for e in query.excludes:
    params.add "e-" & e & "=on"
  for i in query.includes.filterIt(it != "nativeretweets"):
    params.add "i-" & i & "=on"

  if query.since.len > 0:
    params.add "since=" & query.since
  if query.until.len > 0:
    params.add "until=" & query.until
  if query.near.len > 0:
    params.add "near=" & query.near

  if params.len > 0:
    result &= params.join("&")
