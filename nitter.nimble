# Package

version       = "0.1.0"
author        = "zedeus"
description   = "An alternative front-end for Twitter"
license       = "AGPL-3.0"
srcDir        = "src"
bin           = @["nitter"]


# Dependencies

requires "nim >= 1.2.0"
requires "jester#head"
requires "regex#2d96bab"
requires "nimcrypto >= 0.4.11"
requires "karax >= 1.1.2"
requires "sass"
requires "markdown#head"
requires "https://github.com/zedeus/redis#head"
requires "redpool#head"
requires "packedjson"
requires "snappy#head"
requires "https://github.com/disruptek/frosty#0.0.6"


# Tasks

task scss, "Generate css":
  exec "nim c --hint[Processing]:off -r tools/gencss"
