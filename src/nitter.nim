import asyncdispatch
from net import Port

import jester

import types, config, prefs
import views/[general, about]
import routes/[preferences, timeline, status, media, search, rss]

const configPath {.strdefine.} = "./nitter.conf"
let cfg = getConfig(configPath)

createPrefRouter(cfg)
createTimelineRouter(cfg)
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
    resp renderMain(renderSearch(), Prefs(), cfg.title)

  get "/about":
    resp renderMain(renderAbout(), Prefs(), cfg.title)

  extend preferences, ""
  extend rss, ""
  extend search, ""
  extend timeline, ""
  extend status, ""
  extend media, ""

runForever()
