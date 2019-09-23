import strutils, sequtils, uri

import jester

import router_utils
import ".."/[query, types, api, agents]
import ../views/[general, search]

export search

proc createSearchRouter*(cfg: Config) =
  router search:
    get "/search":
      if @"text".len > 200:
        resp Http400, showError("Search input too long.", cfg.title)

      let prefs = cookiePrefs()
      let query = initQuery(params(request))

      case query.kind
      of userSearch:
        if "," in @"text":
          redirect("/" & @"text")
        let users = await getSearch[Profile](query, @"after", getAgent())
        resp renderMain(renderUserSearch(users, prefs), request, cfg.title)
      of custom:
        let tweets = await getSearch[Tweet](query, @"after", getAgent())
        resp renderMain(renderTweetSearch(tweets, prefs, getPath()), request, cfg.title)
      else:
        resp Http404, showError("Invalid search.", cfg.title)

    get "/hashtag/@hash":
      redirect("/search?text=" & encodeUrl("#" & @"hash"))
