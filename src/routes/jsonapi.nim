# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch
import json

import jester

import router_utils, timeline
import "../jsons/timeline"

proc createJsonApiRouter*(cfg: Config) =
  router jsonapi:
    get "/hello":
      cond cfg.enableJsonApi
      let headers = {"Content-Type": "application/json; charset=utf-8"}
      resp Http200, headers, """{"message": "Hello, world"}"""

proc createJsonApiListRouter*(cfg: Config) =
  router jsonapi_list:
    get "/api/@name/lists/@slug/?":
      cond cfg.enableJsonApi
      cond '.' notin @"name"
      cond @"name" != "i"
      cond @"slug" != "memberships"
      let
        slug = decodeUrl(@"slug")
        list = await getCachedList(@"name", slug)
      if list.id.len == 0:
        resp Http404, showError(&"""List "{@"slug"}" not found""", cfg)
      redirect(&"/api/i/lists/{list.id}")

    get "/api/i/lists/@id/?":
      cond cfg.enableJsonApi
      cond '.' notin @"id"
      let
          list = await getCachedList(id=(@"id"))
          timeline = await getGraphListTweets(list.id, getCursor())
      resp Http200, headers, $formatTimelineAsJson(timeline)

    get "/api/i/lists/@id/members":
      cond cfg.enableJsonApi
      cond '.' notin @"id"
      let
          list = await getCachedList(id=(@"id"))
          members = await getGraphListMembers(list, getCursor())
      resp Http200, headers, $formatUsersAsJson(members)
