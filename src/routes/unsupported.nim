# SPDX-License-Identifier: AGPL-3.0-only
import jester

import router_utils
import ../types
import ../views/[general, about]

proc createUnsupportedRouter*(cfg: Config) =
  router unsupported:
    template feature {.dirty.} =
      resp renderMain(renderFeature(cfg), request, cfg, themePrefs())

    get "/about/feature": feature()
    get "/login/?@i?": feature()
    get "/@name/lists/?": feature()

    get "/intent/?@i?": 
      cond @"i" notin ["user"]
      feature()

    get "/i/@i?/?@j?":
      cond @"i" notin ["status", "lists" , "user"]
      feature()
