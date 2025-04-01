# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, httpclient, uri, strutils, sequtils, sugar
import packedjson
import jester
import ".."/[types, query, formatters, consts, apiutils, parser]
import "../jsons/timeline"

proc createApiRouter*(cfg: Config) =
  router api:
    get "/api/timeline/@name/?@tab?/?":
      cond '.' notin @"name"
      cond @"name" notin ["pic", "gif", "video", "search", "settings", "login", "intent", "i"]
      cond @"tab" in ["with_replies", "media", "search", ""]
      let
        prefs = cookiePrefs()
        after = getCursor()
        names = getNames(@"name")

      var query = request.getQuery(@"tab", @"name")
      if names.len != 1:
        query.fromUser = names

      if query.fromUser.len != 1:
        var timeline = await getGraphTweetSearch(query, after)
        if timeline.content.len == 0: resp Http404
        resp $formatTimelineAsJson(timeline)
      else:
        var profile = await fetchProfile(after, query, skipRail=true)
        if profile.tweets.content.len == 0: resp Http404
        resp $formatTimelineAsJson(profile.tweets)

    get "/api/users/@name/?":
      cond '.' notin @"name"
      cond @"name" notin ["pic", "gif", "video", "search", "settings", "login", "intent", "i"]
      let
        prefs = cookiePrefs()
        after = getCursor()
        names = getNames(@"name")

      var query = request.getQuery("", @"name")
      if names.len != 1:
        query.fromUser = names

      var results = await getGraphUserSearch(query, after)
      if results.content.len == 0: resp Http404
      resp $formatUsersAsJson(results) 