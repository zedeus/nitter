# Package

version       = "0.1.0"
author        = "zedeus"
description   = "An alternative front-end for Twitter"
license       = "AGPL-3.0"
srcDir        = "src"
bin           = @["nitter"]


# Dependencies

requires "nim >= 0.19.9"
requires "regex", "nimcrypto", "norm", "jester", "nimquery#head"
