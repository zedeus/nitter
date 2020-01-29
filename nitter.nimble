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
requires "https://github.com/zedeus/jester#asyncify-temp"
requires "regex >= 0.11.2"
requires "q >= 0.0.7"
requires "nimcrypto >= 0.3.9"
requires "karax#f6bda9a"
requires "sass"
requires "markdown"


# Tasks

task scss, "Generate css":
  exec "nim c --hint[Processing]:off -r tools/gencss"
