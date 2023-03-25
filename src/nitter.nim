# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, strformat, logging
from net import Port
from htmlgen import a
from os import getEnv

import jester

import types, config, prefs, formatters, redis_cache, http_pool, tokens
import views/[general, about]
import routes/[
  preferences, timeline, status, media, search, rss, list, debug,
  unsupported, embed, resolver, router_utils]

const instancesUrl = "https://github.com/zedeus/nitter/wiki/Instances"
const issuesUrl = "https://github.com/zedeus/nitter/issues"

let configPath = getEnv("NITTER_CONF_FILE", "./nitter.conf")
let (cfg, fullCfg) = getConfig(configPath)

if not cfg.enableDebug:
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
setHttpProxy(cfg.proxy, cfg.proxyAuth)
initAboutPage(cfg.staticDir)

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
createDebugRouter(cfg)

settings:
  port = Port(cfg.port)
  staticDir = cfg.staticDir
  bindAddr = cfg.address
  reusePort = true

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
    redirect(replaceUrls(url, cookiePrefs()))

  error Http404:
    resp Http404, showError("Page not found", cfg)

  error InternalError:
    echo error.exc.name, ": ", error.exc.msg
    const link = a("open a GitHub issue", href = issuesUrl)
    resp Http500, showError(
      &"An error occurred, please {link} with the URL you tried to visit.", cfg)

  error BadClientError:
    echo error.exc.name, ": ", error.exc.msg
    resp Http500, showError("Network error occured, please try again.", cfg)

  error RateLimitError:
    const link = a("another instance", href = instancesUrl)
    resp Http429, showError(
      &"Instance has been rate limited.<br>Use {link} or try again later.", cfg)

  extend rss, ""
  extend status, ""
  extend search, ""
  extend timeline, ""
  extend media, ""
  extend list, ""
  extend preferences, ""
  extend resolver, ""
  extend embed, ""
  extend debug, ""
  extend unsupported, ""
