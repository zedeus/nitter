# Package

version       = "0.1.0"
author        = "zedeus"
description   = "An alternative front-end for Twitter"
license       = "AGPL-3.0"
srcDir        = "src"
bin           = @["nitter"]


# Dependencies

requires "nim >= 1.4.8"
requires "jester >= 0.5.0"
requires "karax#fa4a2dc"
requires "sass#e683aa1"
requires "nimcrypto#a5742a9"
requires "markdown#abdbe5e"
requires "packedjson#d11d167"
requires "supersnappy#2.1.1"
requires "redpool#8b7c1db"
requires "https://github.com/zedeus/redis#d0a0e6f"
requires "zippy#0.7.3"
requires "flatty#0.2.3"
requires "jsony#d0e69bd"


# Tasks

task scss, "Generate css":
  exec "nimble c --hint[Processing]:off -d:danger -r tools/gencss"

task md, "Render md":
  exec "nimble c --hint[Processing]:off -d:danger -r tools/rendermd"
