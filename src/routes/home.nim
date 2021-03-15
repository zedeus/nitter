import jester
import asyncdispatch, strutils, options, router_utils, timeline
import ".."/[prefs, types, utils]
import ../views/[general, home, search]

export home

proc showHome*(request: Request; query: Query; cfg: Config; prefs: Prefs;
                   after: string): Future[string] {.async.} =
  let
    timeline = await getSearch[Tweet](query, after)
    html = renderHome(timeline, prefs, getPath())
  return renderMain(html, request, cfg, prefs)

proc createHomeRouter*(cfg: Config) =
  router home:
    get "/":
      let
        prefs = cookiePrefs()
        after = getCursor()
        names = getNames(prefs.following)

      var query = request.getQuery("", prefs.following)
      query.fromUser = names

      if @"scroll".len > 0:
        var timeline = await getSearch[Tweet](query, after)
        if timeline.content.len == 0: resp Http404
        timeline.beginning = true
        resp $renderHome(timeline, prefs, getPath())

      if names.len == 0:
        resp renderMain(renderSearch(), request, cfg, themePrefs())
      resp (await showHome(request, query, cfg, prefs, after))
