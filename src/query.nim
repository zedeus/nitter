# SPDX-License-Identifier: AGPL-3.0-only
import strutils, strformat, sequtils, tables, uri

import types

const
  validFilters* = @[
    "media", "images", "twimg", "videos",
    "native_video", "consumer_video", "spaces",
    "links", "news", "quote", "mentions",
    "replies", "retweets", "nativeretweets"
  ]

  emptyQuery* = "include:nativeretweets"

template `@`(param: string): untyped =
  if param in pms: pms[param]
  else: ""

proc validateNumber(value: string): string =
  if value.anyIt(not it.isDigit):
    return ""
  return value

proc initQuery*(pms: Table[string, string]; name=""): Query =
  result = Query(
    kind: parseEnum[QueryKind](@"f", tweets),
    text: @"q",
    filters: validFilters.filterIt("f-" & it in pms),
    excludes: validFilters.filterIt("e-" & it in pms),
    since: @"since",
    until: @"until",
    minLikes: validateNumber(@"min_faves")
  )

  if name.len > 0:
    result.fromUser = name.split(",")

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
    fromUser: @[name]
  )

proc genQueryParam*(query: Query): string =
  var
    filters: seq[string]
    param: string

  if query.kind == users:
    return query.text

  for i, user in query.fromUser:
    param &= &"from:{user} "
    if i < query.fromUser.high:
      param &= "OR "

  if query.fromUser.len > 0 and query.kind in {posts, media}:
    param &= "filter:self_threads OR -filter:replies "

  if "nativeretweets" notin query.excludes:
    param &= "include:nativeretweets "

  for f in query.filters:
    filters.add "filter:" & f
  for e in query.excludes:
    if e == "nativeretweets": continue
    filters.add "-filter:" & e
  for i in query.includes:
    filters.add "include:" & i

  result = strip(param & filters.join(&" {query.sep} "))
  if query.since.len > 0:
    result &= " since:" & query.since
  if query.until.len > 0:
    result &= " until:" & query.until
  if query.minLikes.len > 0:
    result &= " min_faves:" & query.minLikes
  if query.text.len > 0:
    if result.len > 0:
      result &= " " & query.text
    else:
      result = query.text

proc genQueryUrl*(query: Query): string =
  if query.kind notin {tweets, users}: return

  var params = @[&"f={query.kind}"]
  if query.text.len > 0:
    params.add "q=" & encodeUrl(query.text)
  for f in query.filters:
    params.add &"f-{f}=on"
  for e in query.excludes:
    params.add &"e-{e}=on"
  for i in query.includes.filterIt(it != "nativeretweets"):
    params.add &"i-{i}=on"

  if query.since.len > 0:
    params.add "since=" & query.since
  if query.until.len > 0:
    params.add "until=" & query.until
  if query.minLikes.len > 0:
    params.add "min_faves=" & query.minLikes

  if params.len > 0:
    result &= params.join("&")
