import jester

import router_utils
import ../types
import ../views/[general, about]

proc createUnsupportedRouter*(cfg: Config) =
  router unsupported:
    get "/about/feature":
      resp renderMain(renderFeature(), request, cfg)

    get "/intent/?@i?":
      resp renderMain(renderFeature(), request, cfg)

    get "/login/?@i?":
      resp renderMain(renderFeature(), request, cfg)

    get "/i/@i?/?@j?":
      cond @"i" notin ["status", "lists"]
      resp renderMain(renderFeature(), request, cfg)
