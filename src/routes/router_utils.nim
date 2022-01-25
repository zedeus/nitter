# SPDX-License-Identifier: AGPL-3.0-only
import strutils, sequtils, uri, tables, json
from jester import Request, cookies

import ../views/general
import ".."/[utils, prefs, types]
export utils, prefs, types, uri

template savePref*(pref, value: string; req: Request; expire=false) =
  if not expire or pref in cookies(req):
    setCookie(pref, value, daysForward(when expire: -10 else: 360),
              httpOnly=true, secure=cfg.useHttps, sameSite=None)

template cookiePrefs*(): untyped {.dirty.} =
  getPrefs(cookies(request))

template cookiePref*(pref): untyped {.dirty.} =
  getPref(cookies(request), pref)

template themePrefs*(): Prefs =
  var res = defaultPrefs
  res.theme = cookiePref(theme)
  res

template showError*(error: string; cfg: Config): string =
  renderMain(renderError(error), request, cfg, themePrefs(), "Error")

template getPath*(): untyped {.dirty.} =
  $(parseUri(request.path) ? filterParams(request.params))

template refPath*(): untyped {.dirty.} =
  if @"referer".len > 0: @"referer" else: "/"

template getCursor*(): string =
  let cursor = @"cursor"
  decodeUrl(if cursor.len > 0: cursor else: @"max_position", false)

template getCursor*(req: Request): string =
  let cursor = req.params.getOrDefault("cursor")
  decodeUrl(if cursor.len > 0: cursor
            else: req.params.getOrDefault("max_position"), false)

proc getNames*(name: string): seq[string] =
  name.strip(chars={'/'}).split(",").filterIt(it.len > 0)

template respJson*(node: JsonNode) =
  resp $node, "application/json"
