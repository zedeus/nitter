# Package

version       = "0.1.0"
author        = "zedeus"
description   = "An alternative front-end for Twitter"
license       = "AGPL-3.0"
srcDir        = "src"
bin           = @["nitter"]


# Dependencies

requires "nim >= 1.2.0"
requires "jester >= 0.5.0"
requires "karax >= 1.1.2"
requires "sass#e683aa1"
requires "regex#2e32fdc"
requires "nimcrypto >= 0.4.11"
requires "markdown#abdbe5e"
requires "packedjson#d11d167"
requires "supersnappy#1.1.5"
requires "redpool#f880f49"
requires "https://github.com/zedeus/redis#94bcbf1"
requires "https://github.com/disruptek/frosty#0.3.1"


# Tasks

task scss, "Generate css":
  exec "nim c --hint[Processing]:off -r tools/gencss"
