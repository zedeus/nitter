# SPDX-License-Identifier: AGPL-3.0-only
import json

import renderutils
import ".."/[types]

proc formatListAsJson*(list: List): JsonNode =
  result = %*{
    "id": list.id,
    "name": list.name,
    "userId": list.userId,
    "username": list.username,
    "description": list.description,
    "members": list.members,
    "banner": list.banner
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
      if list.id.len == 0:
        resp Http404, showError(&"""List "{@"slug"}" not found""", cfg)
      redirect(&"/api/i/lists/{list.id}")

    get "/api/i/lists/@id/?":
      cond cfg.enableJsonApi
      cond '.' notin @"id"
      let
          list = await getCachedList(id=(@"id"))
          timeline = await getGraphListTweets(list.id, getCursor())
          json = %*{
            "list": $formatListAsJson(list),
            "timeline": $formatTimelineAsJson(timeline)
          }
      resp Http200, headers, $json

    get "/api/i/lists/@id/members":
      cond cfg.enableJsonApi
      cond '.' notin @"id"
      let
          list = await getCachedList(id=(@"id"))
          members = await getGraphListMembers(list, getCursor())
          json = %*{
            "list": $formatListAsJson(list),
            "members": $formatUsersAsJson(members)
          }
      resp Http200, headers, $json
