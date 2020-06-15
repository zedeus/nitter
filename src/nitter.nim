import asyncdispatch, logging, strformat
from net import Port

import jester

import types, config, prefs, formatters, redis_cache, tokens
import views/[general, about]
import routes/[
  preferences, timeline, status, media, search, rss, list,
  unsupported, embed, resolver, router_utils]

const configPath {.strdefine.} = "./nitter.conf"
let (cfg, fullCfg) = getConfig(configPath)

when defined(release):
  # Silence Jester's query warning
  addHandler(newConsoleLogger())
  setLogFilter(lvlError)

let http = if cfg.useHttps: "https" else: "http"
stdout.write &"Starting Nitter at {http}://{cfg.hostname}\n"
stdout.flushFile

updateDefaultPrefs(fullCfg)
setCacheTimes(cfg)
setHmacKey(cfg.hmacKey)
setProxyEncoding(cfg.base64Media)

waitFor initRedisPool(cfg)
stdout.write &"Connected to Redis at {cfg.redisHost}:{cfg.redisPort}\n"
stdout.flushFile

setLen(tokenPool, cfg.minTokens)    # (re)set initial size of pool
init tokenPool                      # initialize pool

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
