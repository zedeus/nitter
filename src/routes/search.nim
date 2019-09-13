import strutils, uri

import jester

import router_utils
import ".."/[query, types, utils, api, agents]
import ../views/[general, search]

export search

proc createSearchRouter*(cfg: Config) =
  router search:
    get "/search":
      if @"text".len == 0 or "." in @"text":
        resp Http404, showError("Please enter a valid username.", cfg.title)

      if @"text".len > 200:
        resp Http400, showError("Search input too long.", cfg.title)

      if "," in @"text":
        redirect("/" & @"text")

      let query = Query(kind: parseEnum[QueryKind](@"kind", custom), text: @"text")

      case query.kind
      of users:
        let users = await getSearch[Profile](query, @"after", getAgent())
        resp renderMain(renderUserSearch(users, Prefs()), Prefs(), path=getPath())
      of custom:
        let tweets = await getSearch[Tweet](query, @"after", getAgent())
        resp renderMain(renderTweetSearch(tweets, Prefs(), getPath()), Prefs(), path=getPath())
      else:
        resp Http404
