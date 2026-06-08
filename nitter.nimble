# Package

version       = "0.1.0"
author        = "zedeus"
description   = "An alternative front-end for Twitter"
license       = "AGPL-3.0"
srcDir        = "src"
bin           = @["nitter"]


# Dependencies

requires "nim >= 2.0.0"
requires "jester == 0.6.0"
requires "karax == 1.5.0"
requires "sass == 0.2.0"
requires "nimcrypto == 0.7.3"
requires "markdown == 0.8.8"
requires "packedjson#9e6fbb6"
requires "supersnappy == 2.1.4"
requires "redpool == 0.2.2"
requires "zippy == 0.10.19"
requires "flatty == 0.4.0"
requires "jsony == 1.1.6"
requires "oauth == 0.11"

# Tasks

task scss, "Generate css":
  exec "nim r --hint[Processing]:off tools/gencss"

task md, "Render md":
  exec "nim r --hint[Processing]:off tools/rendermd"
