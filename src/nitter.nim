import asyncdispatch, mimetypes
from net import Port

import jester

import types, config, prefs, formatters
import views/[general, about]
import routes/[
  preferences, timeline, status, media, search, rss, list, unsupported]

const configPath {.strdefine.} = "./nitter.conf"
let cfg = getConfig(configPath)

createUnsupportedRouter(cfg)
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
    resp renderMain(renderSearch(), request, cfg)

  get "/about":
    resp renderMain(renderAbout(), request, cfg)

  get "/explore":
    redirect("/about")

  get "/help":
    redirect("/about")

  get "/i/redirect":
    let url = decodeUrl(@"url")
    if url.len == 0: halt Http404
    redirect(replaceUrl(url, cookiePrefs()))

  error Http404:
    resp showError("Page not found", cfg)

  extend unsupported, ""
  extend preferences, ""
  extend rss, ""
  extend search, ""
  extend timeline, ""
  extend list, ""
  extend status, ""
  extend media, ""
