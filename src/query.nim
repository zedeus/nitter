import strutils, strformat, sequtils

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
  commonFilters* = @[
    "media", "videos", "images", "links", "news", "quote"
  ]
  advancedFilters* = @[
    "mentions", "verified", "safe", "twimg", "native_video",
    "consumer_video", "pro_video"
  ]

# Experimental, this might break in the future
# Till then, it results in shorter urls
const
  posPrefix = "thGAVUV0VFVBa"
  posSuffix = "EjUAFQAlAFUAFQAA"

proc initQuery*(filters, includes, excludes, separator, text: string; name=""): Query =
  var sep = separator.strip().toUpper()
  Query(
    kind: custom,
    text: text,
    filters: filters.split(",").filterIt(it in validFilters),
    includes: includes.split(",").filterIt(it in validFilters),
    excludes: excludes.split(",").filterIt(it in validFilters),
    fromUser: @[name],
    sep: if sep in separators: sep else: ""
  )

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

  if query.kind == multi:
    return result & "?"

  if query.kind notin {custom, users}:
    return result & &"/{query.kind}?"

  result &= &"/search?"

  var params = @[&"kind={query.kind}"]
  if query.filters.len > 0:
    params &= "filter=" & query.filters.join(",")
  if query.includes.len > 0:
    params &= "include=" & query.includes.join(",")
  if query.excludes.len > 0:
    params &= "not=" & query.excludes.join(",")
  if query.sep.len > 0:
    params &= "sep=" & query.sep
  if query.text.len > 0:
    params &= "text=" & query.text
  if params.len > 0:
    result &= params.join("&")

proc cleanPos*(pos: string): string =
  pos.multiReplace((posPrefix, ""), (posSuffix, ""))

proc genPos*(pos: string): string =
  posPrefix & pos & posSuffix
