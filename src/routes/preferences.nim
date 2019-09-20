import strutils, uri

import jester

import router_utils
import ".."/[prefs, types]
import ../views/[general, preferences]

export preferences

proc createPrefRouter*(cfg: Config) =
  router preferences:
    template savePrefs(): untyped =
      setCookie("preferences", $prefs.id, daysForward(360), httpOnly=true, secure=cfg.useHttps)

    get "/settings":
      let prefs = cookiePrefs()
      let path = refPath()
      resp renderMain(renderPreferences(prefs, path), prefs, cfg.title, "Preferences", path)

    post "/saveprefs":
      var prefs = cookiePrefs()
      genUpdatePrefs()
      savePrefs()
      redirect(refPath())

    post "/resetprefs":
      var prefs = cookiePrefs()
      resetPrefs(prefs)
      savePrefs()
      redirect($(parseUri("/settings") ? filterParams(request.params)))

    post "/enablehls":
      var prefs = cookiePrefs()
      prefs.hlsPlayback = true
      cache(prefs)
      savePrefs()
      redirect(refPath())
