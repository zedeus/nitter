import asyncdispatch, strformat
from net import Port
from htmlgen import a
from os import getEnv

import jester

import types, config, prefs, formatters, redis_cache, http_pool, tokens
import views/[general, about]
import routes/[
  preferences, timeline, status, media, search, rss, list,
  unsupported, embed, resolver, router_utils]

const instancesUrl = "https://github.com/zedeus/nitter/wiki/Instances"

let configPath = getEnv("NITTER_CONF_FILE", "./nitter.conf")
let (cfg, fullCfg) = getConfig(configPath)

when defined(release):
  import logging
  # Silence Jester's query warning
  addHandler(newConsoleLogger())
  setLogFilter(lvlError)

stdout.write &"Starting Nitter at {getUrlPrefix(cfg)}\n"
stdout.flushFile

updateDefaultPrefs(fullCfg)
setCacheTimes(cfg)
setHmacKey(cfg.hmacKey)
setProxyEncoding(cfg.base64Media)
setMaxHttpConns(cfg.httpMaxConns)

waitFor initRedisPool(cfg)
stdout.write &"Connected to Redis at {cfg.redisHost}:{cfg.redisPort}\n"
stdout.flushFile

asyncCheck initTokenPool(cfg)

createUnsupportedRouter(cfg)
createResolverRouter(cfg)
createPrefRouter(cfg)
createTimelineRouter(cfg)
createListRouter(cfg)
createStatusRouter(cfg)
createSearchRouter(cfg)
createMediaRouter(cfg)
createEmbedRouter(cfg)
createRssRouter(cfg)

settings:
  port = Port(cfg.port)
  staticDir = cfg.staticDir
  bindAddr = cfg.address

routes:
  get "/":
    resp renderMain(renderSearch(), request, cfg, themePrefs())

  get "/about":
    resp renderMain(renderAbout(), request, cfg, themePrefs())

  get "/explore":
    redirect("/about")

  get "/help":
    redirect("/about")

  get "/i/redirect":
    let url = decodeUrl(@"url")
    if url.len == 0: resp Http404
    redirect(replaceUrl(url, cookiePrefs()))

  error Http404:
    resp Http404, showError("Page not found", cfg)

  error RateLimitError:
    echo error.exc.msg
    resp Http429, showError("Instance has been rate limited.<br>Use " &
      a("another instance", href = instancesUrl) &
      " or try again later.", cfg)

  extend unsupported, ""
  extend preferences, ""
  extend resolver, ""
  extend rss, ""
  extend search, ""
  extend timeline, ""
  extend list, ""
  extend status, ""
  extend media, ""
  extend embed, ""
