import asyncdispatch, strutils

import jester

import router_utils, timeline
import ".."/[cache, agents, query]
import ../views/general

include "../views/rss.nimf"

proc showRss*(name: string; query: Option[Query]): Future[string] {.async.} =
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
      respRss(await showRss(@"name", none(Query)))

    get "/@name/replies/rss":
      cond '.' notin @"name"
      respRss(await showRss(@"name", some(getReplyQuery(@"name"))))

    get "/@name/media/rss":
      cond '.' notin @"name"
      respRss(await showRss(@"name", some(getMediaQuery(@"name"))))
