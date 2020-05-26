# Package

version       = "0.1.0"
author        = "zedeus"
description   = "An alternative front-end for Twitter"
license       = "AGPL-3.0"
srcDir        = "src"
bin           = @["nitter"]


# Dependencies

requires "nim >= 0.19.9"
requires "norm#head"
requires "jester#head"
requires "regex == 0.13.1"
requires "q >= 0.0.7"
requires "nimcrypto >= 0.4.11"
requires "karax >= 1.1.2"
requires "sass"
requires "markdown#head"


# Tasks

task scss, "Generate css":
  exec "nim c --hint[Processing]:off -r tools/gencss"
