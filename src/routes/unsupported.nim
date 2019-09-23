import jester

import router_utils
import ../types
import ../views/[general, about]

proc createUnsupportedRouter*(cfg: Config) =
  router unsupported:
    get "/about/feature":
      resp renderMain(renderFeature(), request, cfg.title)

    get "/intent/?@i?":
      resp renderMain(renderFeature(), request, cfg.title)

    get "/login/?@i?":
      resp renderMain(renderFeature(), request, cfg.title)

    get "/i/@i?/?@j?":
      cond @"i" != "status"
      resp renderMain(renderFeature(), request, cfg.title)
