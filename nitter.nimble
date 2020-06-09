# Package

version       = "0.1.0"
author        = "zedeus"
description   = "An alternative front-end for Twitter"
license       = "AGPL-3.0"
srcDir        = "src"
bin           = @["nitter"]


# Dependencies

requires "nim >= 1.2.0"
requires "jester#7e8df65"
requires "regex#2e32fdc"
requires "nimcrypto >= 0.4.11"
requires "karax >= 1.1.2"
requires "sass"
requires "markdown#head"
requires "https://github.com/zedeus/redis#94bcbf1"
requires "redpool#head"
requires "packedjson"
requires "snappy#d13e2cc"
requires "https://github.com/disruptek/frosty#0.0.6"


# Tasks

task scss, "Generate css":
  exec "nim c --hint[Processing]:off -r tools/gencss"
