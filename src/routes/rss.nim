import asyncdispatch, strutils

import jester

import router_utils, timeline
import ".."/[cache, agents, query]
import ../views/general

include "../views/rss.nimf"

proc showRss*(name, hostname: string; query: Query): Future[string] {.async.} =
  let (profile, timeline, _) = await fetchSingleTimeline(name, "", getAgent(), query)
  if timeline != nil:
    return renderTimelineRss(timeline, profile, hostname)

template respRss*(rss: typed) =
  if rss.len == 0:
    resp Http404, showError("User \"" & @"name" & "\" not found", cfg)
  resp rss, "application/rss+xml;charset=utf-8"

proc createRssRouter*(cfg: Config) =
  router rss:
    get "/search/rss":
      if @"q".len > 200:
        resp Http400, showError("Search input too long.", cfg)

      let query = initQuery(params(request))
      if query.kind != tweets:
        resp Http400, showError("Only Tweet searches are allowed for RSS feeds.", cfg)

      let tweets = await getSearch[Tweet](query, "", getAgent())
      respRss(renderSearchRss(tweets.content, query.text, genQueryUrl(query), cfg.hostname))

    get "/@name/rss":
      cond '.' notin @"name"
      respRss(await showRss(@"name", cfg.hostname, Query()))

    get "/@name/with_replies/rss":
      cond '.' notin @"name"
      respRss(await showRss(@"name", cfg.hostname, getReplyQuery(@"name")))

    get "/@name/media/rss":
      cond '.' notin @"name"
      respRss(await showRss(@"name", cfg.hostname, getMediaQuery(@"name")))

    get "/@name/search/rss":
      cond '.' notin @"name"
      respRss(await showRss(@"name", cfg.hostname, initQuery(params(request), name=(@"name"))))

    get "/@name/lists/@list/rss":
      cond '.' notin @"name"
      let list = await getListTimeline(@"name", @"list", getAgent(), "")
      respRss(renderListRss(list.content, @"name", @"list", cfg.hostname))
