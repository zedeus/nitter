# SPDX-License-Identifier: AGPL-3.0-only
import strutils, uri

import jester

import router_utils
import ".."/[query, types, api, formatters]
import ../views/[general, search]

include "../views/opensearch.nimf"

export search

proc createSearchRouter*(cfg: Config) =
  router search:
    get "/search/?":
      let q = @"q"
      if q.len > 500:
        resp Http400, showError("Search input too long.", cfg)

      let
        prefs = cookiePrefs()
        query = initQuery(params(request))
        title = "Search" & (if q.len > 0: " (" & q & ")" else: "")

      case query.kind
      of users:
        if "," in q:
          redirect("/" & q)
        let users = await getSearch[User](query, getCursor())
        resp renderMain(renderUserSearch(users, prefs), request, cfg, prefs, title)
      of tweets:
        let
          tweets = await getSearch[Tweet](query, getCursor())
          rss = "/search/rss?" & genQueryUrl(query)
        resp renderMain(renderTweetSearch(tweets, prefs, getPath()),
                        request, cfg, prefs, title, rss=rss)
      else:
        resp Http404, showError("Invalid search", cfg)

    get "/hashtag/@hash":
      redirect("/search?q=" & encodeUrl("#" & @"hash"))

    get "/opensearch":
      let url = getUrlPrefix(cfg) & "/search?q="
      resp Http200, {"Content-Type": "application/opensearchdescription+xml"},
                     generateOpenSearchXML(cfg.title, cfg.hostname, url)
