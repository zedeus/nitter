import asyncdispatch, strutils

import jester

import router_utils, timeline
import ".."/[cache, agents, query]
import ../views/general

include "../views/rss.nimf"

proc showRss*(name: string; query: Query): Future[string] {.async.} =
  let (profile, timeline, _) = await fetchSingleTimeline(name, "", getAgent(), query)
  return renderTimelineRss(timeline.content, profile)

template respRss*(rss: typed) =
  if rss.len == 0:
    resp Http404, showError("User \"" & @"name" & "\" not found", cfg.title)
  resp rss, "application/rss+xml;charset=utf-8"

proc createRssRouter*(cfg: Config) =
  router rss:
    get "/@name/rss":
      cond '.' notin @"name"
      respRss(await showRss(@"name", Query()))

    get "/@name/replies/rss":
      cond '.' notin @"name"
      respRss(await showRss(@"name", getReplyQuery(@"name")))

    get "/@name/media/rss":
      cond '.' notin @"name"
      respRss(await showRss(@"name", getMediaQuery(@"name")))

    get "/@name/search/rss":
      cond '.' notin @"name"
      respRss(await showRss(@"name", initQuery(params(request), name=(@"name"))))

    get "/@name/lists/@list/rss":
      cond '.' notin @"name"
      let list = await getListTimeline(@"name", @"list", getAgent(), "")
      respRss(renderListRss(list.content, @"name", @"list"))
