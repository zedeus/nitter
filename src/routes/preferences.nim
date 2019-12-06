import strutils, uri, os, algorithm

import jester

import router_utils
import ".."/[types]
import ../views/[general, preferences]

export preferences

proc findThemes*(dir: string): seq[string] =
  for kind, path in walkDir(dir / "css" / "themes"):
    let theme = path.splitFile.name
    result.add theme.capitalizeAscii.replace("_", " ")
  sort(result)

proc createPrefRouter*(cfg: Config) =
  router preferences:
    template savePrefs(): untyped =
      setCookie("preferences", $prefs.id, daysForward(360), httpOnly=true, secure=cfg.useHttps)

    get "/settings":
      let html = renderPreferences(cookiePrefs(), refPath(), findThemes(cfg.staticDir))
      resp renderMain(html, request, cfg, "Preferences")

    get "/settings/@i?":
      redirect("/settings")

    post "/saveprefs":
      var prefs = cookiePrefs()
      genUpdatePrefs()
      savePrefs()
      redirect(refPath())

    post "/resetprefs":
      var prefs = cookiePrefs()
      resetPrefs(prefs, cfg)
      savePrefs()
      redirect($(parseUri("/settings") ? filterParams(request.params)))

    post "/enablehls":
      var prefs = cookiePrefs()
      prefs.hlsPlayback = true
      cache(prefs)
      savePrefs()
      redirect(refPath())

    before:
      if @"theme".len > 0:
        var prefs = cookiePrefs()
        prefs.theme = @"theme".capitalizeAscii.replace("_", " ")
        cache(prefs)
        savePrefs()
