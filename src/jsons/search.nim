# SPDX-License-Identifier: AGPL-3.0-only
import strutils, uri

import jester

import timeline, list

import ".."/routes/[router_utils, timeline]
import ".."/[query, types, api, formatters]
import ../views/[general, search]

proc createJsonApiSearchRouter*(cfg: Config) =
  router jsonapi_search:
    get "/api/search?":
      let q = @"q"
      if q.len > 500:
        respJsonError("Search input too long.", "invalid_input", Http400)

      let query = initQuery(params(request))

      case query.kind
      of users:
        if "," in q:
          respJsonError("Invalid search input", "invalid_input", Http400)
        var users: Result[User]
        try:
          users = await getGraphUserSearch(query, getCursor())
        except InternalError:
          users = Result[User](beginning: true, query: query)
        respJsonSuccess formatUsersAsJson(users)
      of tweets:
        let timeline = await getGraphTweetSearch(query, getCursor())
        if timeline.content.len == 0: respJsonError("No results found", "no_results", Http200)
        respJsonSuccess formatTimelineAsJson(timeline)
      else:
        respJsonError("Invalid search", "invalid_input", Http400)

    get "/api/hashtag/@hash":
      redirect("/search?q=" & encodeUrl("#" & @"hash"))
