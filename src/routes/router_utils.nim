# SPDX-License-Identifier: AGPL-3.0-only
import strutils, sequtils, uri, tables, json
from jester import Request, cookies

import ../views/general
import ".."/[utils, prefs, types]
export utils, prefs, types, uri

template savePref*(pref, value: string; req: Request; expire=false) =
  if not expire or pref in cookies(req):
    setCookie(pref, value, daysForward(when expire: -10 else: 360),
              httpOnly=true, secure=cfg.useHttps, sameSite=None, path="/")

template requestPrefs*(): untyped {.dirty.} =
  getPrefs(cookies(request), params(request))

template showError*(error: string; cfg: Config): string =
  renderMain(renderError(error), request, cfg, requestPrefs(), "Error")

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

template applyUrlPrefs*() {.dirty.} =
  if @"prefs".len > 0:
    var prefParams = initTable[string, string]()
    for pair in @"prefs".split(','):
      let kv = pair.split('=', maxsplit=1)
      if kv.len == 2:
        prefParams[kv[0]] = kv[1]
      elif kv.len == 1 and kv[0].len > 0:
        prefParams[kv[0]] = ""
    genApplyPrefs(prefParams, request)

    # Rebuild URL without prefs param
    var params: seq[(string, string)]
    for k, v in request.params:
      if k != "prefs":
        params.add (k, v)

    if params.len > 0:
      let cleanUrl = request.getNativeReq.url ? params
      redirect($cleanUrl)
    else:
      redirect(request.path)

template respJson*(node: JsonNode) =
  resp $node, "application/json"
