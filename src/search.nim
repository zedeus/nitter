import asyncdispatch, strutils, strformat, uri, tables

import types

const
  separators = @["AND", "OR"]
  validFilters = @[
    "media", "images", "videos", "native_video", "twimg",
    "links", "quote", "replies", "mentions",
    "news", "verified", "safe"
  ]

# Experimental, this might break in the future
# Till then, it results in shorter urls
const
  posPrefix = "thGAVUV0VFVBa"
  posSuffix = "EjUAFQAlAFUAFQAA"

proc initQuery*(filter, separator: string; name=""): Query =
  var sep = separator.strip().toUpper()
  Query(
    filter: filter.split(",").filterIt(it in validFilters),
    sep: if sep in separators: sep else: "AND",
    fromUser: name,
    queryType: custom
  )

proc getMediaQuery*(name: string): Query =
  Query(
    filter: @["twimg", "native_video"],
    sep: "OR",
    fromUser: name,
    queryType: media
  )

proc getReplyQuery*(name: string): Query =
  Query(fromUser: name, queryType: replies)

proc genQueryParam*(query: Query): string =
  var filters: seq[string]
  var param: string

  if query.fromUser.len > 0:
    param = &"from:{query.fromUser} "

  for f in query.filter:
    filters.add "filter:" & f
  for e in query.exclude:
    filters.add "-filter:" & e

  return strip(param & filters.join(&" {query.sep} "))

proc genQueryUrl*(query: Query): string =
  result = &"/{query.queryType}?"
  if query.queryType != custom: return

  var params: seq[string]
  if query.filter.len > 0:
    params &= "filter=" & query.filter.join(",")
  if query.exclude.len > 0:
    params &= "not=" & query.exclude.join(",")
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
