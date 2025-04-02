# SPDX-License-Identifier: AGPL-3.0-only
import std/json
import asyncdispatch

import jester

import timeline
import ".."/routes/[router_utils]
import ".."/[types, redis_cache, api]

proc formatListAsJson*(list: List): JsonNode =
  return %*{
    "id": list.id,
    "name": list.name,
    "userId": list.userId,
    "username": list.username,
    "description": list.description,
    "members": list.members,
    "banner": list.banner
  }

proc formatUsersAsJson*(results: Result[User]): JsonNode =
  var users = newJArray()

  for user in results.content:
    users.add(formatUserAsJson(user))

  return %*{
    "pagination": %*{
      "beginning": results.beginning,
      "top": results.top,
      "bottom": results.bottom,
    },
    "users": users
  }

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
      respJson formatListAsJson(list)

    get "/api/i/lists/@id/?":
      cond cfg.enableJsonApi
      cond '.' notin @"id"
      let list = await getCachedList(id=(@"id"))
      respJson formatListAsJson(list)

    get "/api/i/lists/@id/timeline/?":
      cond cfg.enableJsonApi
      cond '.' notin @"id"
      let
          list = await getCachedList(id=(@"id"))
          timeline = await getGraphListTweets(list.id, getCursor())
      respJson formatTimelineAsJson(timeline)

    get "/api/i/lists/@id/members/?":
      cond cfg.enableJsonApi
      cond '.' notin @"id"
      let
          list = await getCachedList(id=(@"id"))
          members = await getGraphListMembers(list, getCursor())
      respJson formatUsersAsJson(members) 
