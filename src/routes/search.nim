import strutils, sequtils, uri

import jester

import router_utils
import ".."/[query, types, api, agents]
import ../views/[general, search]

export search

proc createSearchRouter*(cfg: Config) =
  router search:
    get "/search/?":
      if @"q".len > 200:
        resp Http400, showError("Search input too long.", cfg)

      let prefs = cookiePrefs()
      let query = initQuery(params(request))

      case query.kind
      of users:
        if "," in @"q":
          redirect("/" & @"q")
        let users = await getSearch[Profile](query, @"max_position", getAgent())
        resp renderMain(renderUserSearch(users, prefs), request, cfg)
      of tweets:
        let tweets = await getSearch[Tweet](query, @"max_position", getAgent())
        let rss = "/search/rss?" & genQueryUrl(query)
        resp renderMain(renderTweetSearch(tweets, prefs, getPath()),
                        request, cfg, rss=rss)
      else:
        resp Http404, showError("Invalid search", cfg)

    get "/hashtag/@hash":
      redirect("/search?q=" & encodeUrl("#" & @"hash"))
