import strutils, sequtils, uri, json

import jester

import router_utils
import rest
import ".."/[query, types, api, restutils]
import ../views/[general, search]

include "../views/opensearch.nimf"

export search
export rest

const
  searchLimit* = 500

proc createSearchRouter*(cfg: Config) =
  router search:
    get "/search/?":
      if @"q".len > searchLimit:
        resp Http400, showError("Search input too long, max limit: " &
            $searchLimit, cfg)

      let
        prefs = cookiePrefs()
        query = initQuery(params(request))

      case query.kind
      of users:
        if "," in @"q":
          redirect("/" & @"q")
        let users = await getSearch[Profile](query, getCursor())
        resp renderMain(renderUserSearch(users, prefs), request, cfg, prefs)
      of tweets:
        let
          tweets = await getSearch[Tweet](query, getCursor())
          rss = "/search/rss?" & genQueryUrl(query)
        resp renderMain(renderTweetSearch(tweets, prefs, getPath()),
                        request, cfg, prefs, rss = rss)
      else:
        resp Http404, showError("Invalid search", cfg)

    get "/api/search/?":
      if @"q".len > searchLimit:
        restError Http400, "Search input too long, max limit: " & $searchLimit
      let
        prefs = cookiePrefs()
        query = initQuery(params(request))

      case query.kind
      of users:
        if "," in @"q":
          redirect("/" & @"q")
        let users = await getSearch[Profile](query, getCursor())
        rest Http200, users, request
      of tweets:
        let
          tweets = await getSearch[Tweet](query, getCursor())
          rss = "/search/rss?" & genQueryUrl(query)
        rest Http200, tweets, request
      else:
        restError Http404, "Invalid search type: " & $query.kind

    get "/hashtag/@hash":
      redirect("/search?q=" & encodeUrl("#" & @"hash"))

    get "/opensearch":
      var url = if cfg.useHttps: "https://" else: "http://"
      url &= cfg.hostname & "/search?q="
      resp Http200, {"Content-Type": "application/opensearchdescription+xml"},
                    generateOpenSearchXML(cfg.title, cfg.hostname, url)
