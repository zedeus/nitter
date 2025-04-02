# SPDX-License-Identifier: AGPL-3.0-only
import strutils, uri

import jester

import ".."/routes/[router_utils, timeline]
import ".."/[query, types, api, formatters]
import ../views/[general, search]

proc createJsonApiSearchRouter*(cfg: Config) =
  router jsonapi_search:
    get "/api/search?":
      let q = @"q"
      if q.len > 500:
        respJsonError "Search input too long."

      let
        prefs = cookiePrefs()
        query = initQuery(params(request))
        title = "Search" & (if q.len > 0: " (" & q & ")" else: "")

      case query.kind
      of users:
        if "," in q:
          redirect("/" & q)
        var users: Result[User]
        try:
          users = await getGraphUserSearch(query, getCursor())
        except InternalError:
          users = Result[User](beginning: true, query: query)
        respJsonSuccess formatUsersAsJson(users)
      of tweets:
        let
          tweets = await getGraphTweetSearch(query, getCursor())
        respJsonSuccess formatTweetsAsJson(tweets)
      else:
        respJsonError "Invalid search"

    get "/api/hashtag/@hash":
      redirect("/search?q=" & encodeUrl("#" & @"hash"))
