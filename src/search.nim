import asyncdispatch, strutils, strformat, uri, tables

import types

const
  separators = @["AND", "OR"]
  validFilters = @[
    "media", "images", "twimg",
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

proc initQuery*(filters, includes, excludes, separator: string; name=""): Query =
  var sep = separator.strip().toUpper()
  Query(
    queryType: custom,
    filters: filters.split(",").filterIt(it in validFilters),
    includes: includes.split(",").filterIt(it in validFilters),
    excludes: excludes.split(",").filterIt(it in validFilters),
    fromUser: name,
    sep: if sep in separators: sep else: ""
  )

proc getMediaQuery*(name: string): Query =
  Query(
    queryType: media,
    filters: @["twimg", "native_video"],
    fromUser: name,
    sep: "OR"
  )

proc getReplyQuery*(name: string): Query =
  Query(
    queryType: replies,
    includes: @["nativeretweets"],
    fromUser: name
  )

proc genQueryParam*(query: Query): string =
  var filters: seq[string]
  var param: string

  if query.fromUser.len > 0:
    param = &"from:{query.fromUser} "

  for f in query.filters:
    filters.add "filter:" & f
  for i in query.includes:
    filters.add "include:" & i
  for e in query.excludes:
    filters.add "-filter:" & e

  return strip(param & filters.join(&" {query.sep} "))

proc genQueryUrl*(query: Query): string =
  result = &"/{query.queryType}?"
  if query.queryType != custom: return

  var params: seq[string]
  if query.filters.len > 0:
    params &= "filter=" & query.filters.join(",")
  if query.includes.len > 0:
    params &= "include=" & query.includes.join(",")
  if query.excludes.len > 0:
    params &= "not=" & query.excludes.join(",")
  if query.sep.len > 0:
    params &= "sep=" & query.sep
  if params.len > 0:
    result &= params.join("&") & "&"

proc cleanPos*(pos: string): string =
  pos.multiReplace((posPrefix, ""), (posSuffix, ""))

proc genPos*(pos: string): string =
  posPrefix & pos & posSuffix

proc tabClass*(timeline: Timeline; tab: string): string =
  result = '"' & "tab-item"
  if timeline.query.isNone:
    if tab == "tweets":
      result &= " active"
  elif $timeline.query.get().queryType == tab:
    result &= " active"
  result &= '"'
