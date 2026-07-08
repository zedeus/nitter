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
        prefs = requestPrefs()
        title = "Search" & (if q.len > 0: " (" & q & ")" else: "")

      var query = initQuery(params(request))
      # x.com URL compat: f=user and f=list map to our kind names
      # (f=live already falls back to tweets/Latest; f=media matches natively)
      if @"f" == "user":
        query.kind = users
      elif @"f" == "list":
        query.kind = lists

      # media searches support view modes, defaulting like /user/media
      if query.kind == QueryKind.media and
         query.view notin ["timeline", "grid", "gallery"]:
        query.view = prefs.mediaView.toLowerAscii

      case query.kind
      of users:
        if "," in q:
          redirect("/" & q)
        var users: Result[User]
        try:
          users = await getGraphUserSearch(query, getCursor())
        except InternalError:
          users = Result[User](beginning: true, query: query)
        resp renderMain(renderUserSearch(users, prefs), request, cfg, prefs, title)
      of tweets, top, QueryKind.media:
        let
          tweets = await getGraphTweetSearch(query, getCursor())
          rss = if cfg.enableRSSSearch: "/search/rss?" & genQueryUrl(query) else: ""
        resp renderMain(renderTweetSearch(tweets, prefs, getPath()),
                        request, cfg, prefs, title, rss=rss)
      of lists:
        let listResults = await getGraphListSearch(query, getCursor())
        resp renderMain(renderListSearch(listResults, prefs, getPath()),
                        request, cfg, prefs, title)
      else:
        resp Http404, showError("Invalid search", cfg)

    get "/hashtag/@hash":
      redirect("/search?f=tweets&q=" & encodeUrl("#" & @"hash"))

    get "/opensearch":
      let
        url = getUrlPrefix(cfg) & "/search?f=tweets&q="
        headers = {"Content-Type": "application/opensearchdescription+xml"}
      resp Http200, headers, generateOpenSearchXML(cfg.title, cfg.hostname, url)
