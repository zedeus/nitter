import strutils, strformat, sequtils, tables

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

# Experimental, this might break in the future
# Till then, it results in shorter urls
const
  posPrefix = "thGAVUV0VFVBa"
  posSuffix = "EjUAFQAlAFUAFQAA"

template `@`(param: string): untyped =
  if param in pms: pms[param]
  else: ""

proc initQuery*(pms: Table[string, string]; name=""): Query =
  result = Query(
    kind: parseEnum[QueryKind](@"kind", custom),
    text: @"text",
    filters: validFilters.filterIt("f-" & it in pms),
    excludes: validFilters.filterIt("e-" & it in pms),
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

  for i, user in query.fromUser:
    param &= &"from:{user} "
    if i < query.fromUser.high:
      param &= "OR "

  for f in query.filters:
    filters.add "filter:" & f
  for i in query.includes:
    filters.add "include:" & i
  for e in query.excludes:
    filters.add "-filter:" & e

  result = strip(param & filters.join(&" {query.sep} "))
  if query.text.len > 0:
    result &= " " & query.text

proc genQueryUrl*(query: Query): string =
  if query.fromUser.len > 0:
    result = "/" & query.fromUser.join(",")

  if query.fromUser.len > 1:
    return result & "?"

  if query.kind notin {custom, users}:
    return result & &"/{query.kind}?"

  result &= &"/search?"

  var params = @[&"kind={query.kind}"]
  if query.text.len > 0:
    params.add "text=" & query.text
  for f in query.filters:
    params.add "f-" & f & "=on"
  for e in query.excludes:
    params.add "e-" & e & "=on"
  for i in query.excludes:
    params.add "i-" & i & "=on"

  if params.len > 0:
    result &= params.join("&")

proc cleanPos*(pos: string): string =
  pos.multiReplace((posPrefix, ""), (posSuffix, ""))

proc genPos*(pos: string): string =
  posPrefix & pos & posSuffix
