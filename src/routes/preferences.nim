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
    get "/settings":
      let
        prefs = cookiePrefs()
        html = renderPreferences(prefs, refPath(), findThemes(cfg.staticDir))
      resp renderMain(html, request, cfg, prefs, "Preferences")

    get "/settings/@i?":
      redirect("/settings")

    post "/saveprefs":
      genUpdatePrefs()
      redirect(refPath())

    post "/resetprefs":
      genResetPrefs()
      redirect($(parseUri("/settings") ? filterParams(request.params)))

    post "/enablehls":
      savePref("hlsPlayback", "on", request)
      redirect(refPath())

