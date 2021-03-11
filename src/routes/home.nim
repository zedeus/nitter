import jester
import asyncdispatch, strutils, options, router_utils
import ".."/[prefs, types, utils]
import ../views/[general, home]

export home

proc createHomeRouter*(cfg: Config) =
  router home:
    get "/":
      resp renderMain(renderHome(), request, cfg, themePrefs())
