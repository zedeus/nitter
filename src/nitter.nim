import asyncdispatch
from net import Port

import jester

import types, config, prefs
import views/[general, about]
import routes/[preferences, timeline, status, media, search, rss, list]

const configPath {.strdefine.} = "./nitter.conf"
let cfg = getConfig(configPath)

createPrefRouter(cfg)
createTimelineRouter(cfg)
createListRouter(cfg)
createStatusRouter(cfg)
createSearchRouter(cfg)
createMediaRouter(cfg)
createRssRouter(cfg)

settings:
  port = Port(cfg.port)
  staticDir = cfg.staticDir
  bindAddr = cfg.address

routes:
  get "/":
    resp renderMain(renderSearch(), request, cfg.title)

  get "/about":
    resp renderMain(renderAbout(), request, cfg.title)

  extend preferences, ""
  extend rss, ""
  extend search, ""
  extend timeline, ""
  extend list, ""
  extend status, ""
  extend media, ""

runForever()
