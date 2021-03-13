import jester
import asyncdispatch, strutils, options, router_utils, timeline
import ".."/[prefs, types, utils]
import ../views/[general, home, search]

export home

proc createHomeRouter*(cfg: Config) =
  router home:
    get "/":
      let
        prefs = cookiePrefs()
        after = getCursor()
        names = getNames(prefs.following)

      var query = request.getQuery("", prefs.following)
      if names.len != 1:
        query.fromUser = names

      if @"scroll".len > 0:
        if query.fromUser.len != 1:
          var timeline = await getSearch[Tweet](query, after)
          if timeline.content.len == 0: resp Http404
          timeline.beginning = true
          resp $renderTweetSearch(timeline, prefs, getPath())
        else:
          var (_, timeline, _) = await fetchSingleTimeline(after, query, skipRail=true)
          if timeline.content.len == 0: resp Http404
          timeline.beginning = true
          resp $renderTimelineTweets(timeline, prefs, getPath())

      var rss = "/$1/$2/rss" % [@"name", @"tab"]
      if @"tab".len == 0:
        rss = "/$1/rss" % @"name"
      elif @"tab" == "search":
        rss &= "?" & genQueryUrl(query)
      
      if names.len == 0:
        resp renderMain(renderSearch(), request, cfg, themePrefs())
      respTimeline(await showTimeline(request, query, cfg, prefs, rss, after))
