import strutils, sequtils
import ../utils, ../prefs
export utils, prefs

template cookiePrefs*(): untyped {.dirty.} =
  getPrefs(request.cookies.getOrDefault("preferences"), cfg)

template getPath*(): untyped {.dirty.} =
  $(parseUri(request.path) ? filterParams(request.params))

template refPath*(): untyped {.dirty.} =
  if @"referer".len > 0: @"referer" else: "/"

proc getNames*(name: string): seq[string] =
  name.strip(chars={'/'}).split(",").filterIt(it.len > 0)
