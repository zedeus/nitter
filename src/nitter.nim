import asyncdispatch
from net import Port

import jester

import types, config, prefs
import views/[general, about]
import routes/[preferences, timeline, media, rss]

const configPath {.strdefine.} = "./nitter.conf"
let cfg = getConfig(configPath)

createPrefRouter(cfg)
createTimelineRouter(cfg)
createMediaRouter(cfg)
createRssRouter(cfg)

settings:
  port = Port(cfg.port)
  staticDir = cfg.staticDir
  bindAddr = cfg.address

routes:
  get "/":
    resp renderMain(renderSearch(), Prefs(), cfg.title)

  get "/about":
    resp renderMain(renderAbout(), Prefs(), cfg.title)

  post "/search":
    if @"query".len == 0:
      resp Http404, showError("Please enter a username.", cfg.title)
    redirect("/" & @"query")

  extend preferences, ""
  extend rss, ""
  extend timeline, ""
  extend media, ""

runForever()
