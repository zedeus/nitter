import strutils, uri

import jester

import router_utils
import ".."/[query, types, utils, api, agents]
import ../views/[general, search]

export search

proc createSearchRouter*(cfg: Config) =
  router search:
    get "/search":
      if @"text".len > 200:
        resp Http400, showError("Search input too long.", cfg.title)

      let kind = parseEnum[QueryKind](@"kind", custom)
      var query = Query(kind: kind, text: @"text")

      if @"retweets".len == 0:
        query.excludes.add "nativeretweets"
      else:
        query.includes.add "nativeretweets"

      if @"replies".len == 0:
        query.excludes.add "replies"
      else:
        query.includes.add "replies"

      for f in validFilters:
        if "f-" & f in params(request):
          query.filters.add f
        if "e-" & f in params(request):
          query.excludes.add f

      case query.kind
      of users:
        if "," in @"text":
          redirect("/" & @"text")
        let users = await getSearch[Profile](query, @"after", getAgent())
        resp renderMain(renderUserSearch(users, Prefs()), Prefs(), path=getPath())
      of custom:
        let tweets = await getSearch[Tweet](query, @"after", getAgent())
        resp renderMain(renderTweetSearch(tweets, Prefs(), getPath()), Prefs(), path=getPath())
      else:
        resp Http404, showError("Invalid search.", cfg.title)
