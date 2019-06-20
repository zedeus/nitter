# Package

version       = "0.1.0"
author        = "Zestyr"
description   = "An alternative front-end for Twitter"
license       = "AGPL-3.0"
srcDir        = "src"
bin           = @["nitter"]


# Dependencies

requires "nim >= 0.19.9"
requires "regex", "nimquery", "nimcrypto", "norm", "jester"
