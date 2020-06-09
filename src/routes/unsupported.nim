import jester

import router_utils
import ../types
import ../views/[general, about]

proc createUnsupportedRouter*(cfg: Config) =
  router unsupported:
    template feature {.dirty.} =
      resp renderMain(renderFeature(), request, cfg, themePrefs())

    get "/about/feature": feature()
    get "/intent/?@i?": feature()
    get "/login/?@i?": feature()
    get "/@name/lists/?": feature()

    get "/i/@i?/?@j?":
      cond @"i" notin ["status", "lists"]
      feature()
