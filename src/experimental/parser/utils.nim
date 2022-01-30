# SPDX-License-Identifier: AGPL-3.0-only
import std/[sugar, strutils, times]
import ".."/types/[common, media, tweet]
import ../../utils as uutils

template parseTime(time: string; f: static string; flen: int): DateTime =
  if time.len != flen: return
  parse(time, f, utc())

proc toId*(id: string): int64 =
  if id.len == 0: 0'i64
  else: parseBiggestInt(id)

proc parseIsoDate*(date: string): DateTime =
  date.parseTime("yyyy-MM-dd\'T\'HH:mm:ss\'Z\'", 20)

proc parseTwitterDate*(date: string): DateTime =
  date.parseTime("ddd MMM dd hh:mm:ss \'+0000\' yyyy", 30)

proc getImageUrl*(url: string): string =
  url.dup(removePrefix(twimg), removePrefix(https))

proc getImageUrl*(entity: MediaEntity | Entity): string =
  entity.mediaUrlHttps.getImageUrl

template handleErrors*(body) =
  if json.startsWith("{\"errors"):
    for error {.inject.} in json.fromJson(Errors).errors:
      body
