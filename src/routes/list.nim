import strutils

import jester

import router_utils
import ".."/[query, types, api, agents]
import ../views/[general, timeline, list]
export getListTimeline, getListMembers

template respList*(list, timeline: typed) =
  if list.minId.len == 0:
    resp Http404, showError("List \"" & @"list" & "\" not found", cfg)
  let html = renderList(timeline, list.query, @"name", @"list")
  let rss = "/$1/lists/$2/rss" % [@"name", @"list"]
  resp renderMain(html, request, cfg, rss=rss)

proc createListRouter*(cfg: Config) =
  router list:
    get "/@name/lists/@list":
      cond '.' notin @"name"
      let list = await getListTimeline(@"name", @"list", @"max_position", getAgent())
      respList(list, renderTimelineTweets(list, cookiePrefs(), request.path))

    get "/@name/lists/@list/members":
      cond '.' notin @"name"
      let list = await getListMembers(@"name", @"list", @"max_position", getAgent())
      respList(list, renderTimelineUsers(list, cookiePrefs(), request.path))
