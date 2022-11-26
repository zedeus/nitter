# Package

version       = "0.1.0"
author        = "zedeus"
description   = "An alternative front-end for Twitter"
license       = "AGPL-3.0"
srcDir        = "src"
bin           = @["nitter"]


# Dependencies

requires "nim >= 1.4.8"
requires "jester#baca3f"
requires "karax#6abcb77"
requires "sass#e683aa1"
requires "nimcrypto#b41129f"
requires "markdown#a661c26"
requires "packedjson#9e6fbb6"
requires "supersnappy#6c94198"
requires "redpool#8b7c1db"
requires "https://github.com/zedeus/redis#d0a0e6f"
requires "zippy#61922b9"
requires "flatty#9f885d7"
requires "jsony#d0e69bd"


# Tasks

task scss, "Generate css":
  exec "nimble c --hint[Processing]:off -d:danger -r tools/gencss"

task md, "Render md":
  exec "nimble c --hint[Processing]:off -d:danger -r tools/rendermd"
