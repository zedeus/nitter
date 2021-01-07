import strutils

import jester

import router_utils
import ".."/[query, types, redis_cache, api]
import ../views/[general, timeline, list]
export getListTimeline, getGraphList

template respList*(list, timeline, vnode: typed) =
  if list.id.len == 0:
    resp Http404, showError("List \"" & @"list" & "\" not found", cfg)

  let
    html = renderList(vnode, timeline.query, list)
    rss = "/$1/lists/$2/rss" % [@"name", @"list"]

  resp renderMain(html, request, cfg, prefs, rss=rss, banner=list.banner)

proc createListRouter*(cfg: Config) =
  router list:
    get "/@name/lists/@list/?":
      cond '.' notin @"name"
      cond @"name" != "i"
      let
        prefs = cookiePrefs()
        list = await getCachedList(@"name", @"list")
        timeline = await getListTimeline(list.id, getCursor())
        vnode = renderTimelineTweets(timeline, prefs, request.path)
      respList(list, timeline, vnode)

    get "/@name/lists/@list/members":
      cond '.' notin @"name"
      cond @"name" != "i"
      let
        prefs = cookiePrefs()
        list = await getCachedList(@"name", @"list")
        members = await getListMembers(list, getCursor())
      respList(list, members, renderTimelineUsers(members, prefs, request.path))

    get "/i/lists/@id/?":
      cond '.' notin @"id"
      let list = await getCachedList(id=(@"id"))
      if list.id.len == 0:
        resp Http404
      await cache(list)
      redirect("/" & list.username & "/lists/" & list.name)
