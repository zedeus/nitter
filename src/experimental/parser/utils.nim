# SPDX-License-Identifier: AGPL-3.0-only
import std/[sugar, strutils, times]
import ../types/common
import ../../utils as uutils

template parseTime(time: string; f: static string; flen: int): DateTime =
  if time.len != flen: return
  parse(time, f, utc())

proc parseIsoDate*(date: string): DateTime =
  date.parseTime("yyyy-MM-dd\'T\'HH:mm:ss\'Z\'", 20)

proc parseTwitterDate*(date: string): DateTime =
  date.parseTime("ddd MMM dd hh:mm:ss \'+0000\' yyyy", 30)

proc getImageUrl*(url: string): string =
  url.dup(removePrefix(twimg), removePrefix(https))

template handleErrors*(body) =
  if json.startsWith("{\"errors"):
    for error {.inject.} in json.fromJson(Errors).errors:
      body
