import asyncdispatch, strutils

import jester

import router_utils, timeline
import ".."/[cache, agents, query]
import ../views/general

include "../views/rss.nimf"

proc showRss*(req: Request; hostname: string; query: Query): Future[(string, string)] {.async.} =
  var profile: Profile
  var timeline: Timeline
  let
    name = req.params.getOrDefault("name")
    after = req.params.getOrDefault("max_position")
    names = getNames(name)

  if names.len == 1:
    (profile, timeline) =
      await fetchSingleTimeline(after, getAgent(), query, media=false)
  else:
    let multiQuery = query.getMultiQuery(names)
    timeline = await getSearch[Tweet](multiQuery, after, getAgent(), media=false)
    # this is kinda dumb
    profile = Profile(
      username: name,
      fullname: names.join(" | "),
      userpic: "https://abs.twimg.com/sticky/default_profile_images/default_profile.png"
    )

  if profile.suspended:
    return (profile.username, "suspended")

  if timeline != nil:
    let rss = renderTimelineRss(timeline, profile, hostname, multi=(names.len > 1))
    return (rss, timeline.minId)

template respRss*(rss, minId) =
  if rss.len == 0:
    resp Http404, showError("User \"" & @"name" & "\" not found", cfg)
  elif minId == "suspended":
    resp Http404, showError(getSuspended(rss), cfg)
  let headers = {"Content-Type": "application/rss+xml;charset=utf-8", "Min-Id": minId}
  resp Http200, headers, rss

proc createRssRouter*(cfg: Config) =
  router rss:
    get "/search/rss":
      if @"q".len > 200:
        resp Http400, showError("Search input too long.", cfg)

      let query = initQuery(params(request))
      if query.kind != tweets:
        resp Http400, showError("Only Tweet searches are allowed for RSS feeds.", cfg)

      let tweets = await getSearch[Tweet](query, @"max_position", getAgent(), media=false)
      let rss = renderSearchRss(tweets.content, query.text, genQueryUrl(query), cfg.hostname)
      respRss(rss, tweets.minId)

    get "/@name/rss":
      cond '.' notin @"name"
      let (rss, minId) = await showRss(request, cfg.hostname, Query(fromUser: @[@"name"]))
      respRss(rss, minId)

    get "/@name/@tab/rss":
      cond '.' notin @"name"
      cond @"tab" in ["with_replies", "media", "search"]
      let name = @"name"
      let query =
        case @"tab"
        of "with_replies": getReplyQuery(name)
        of "media": getMediaQuery(name)
        of "search": initQuery(params(request), name=name)
        else: Query(fromUser: @[name])

      let (rss, minId) = await showRss(request, cfg.hostname, query)
      respRss(rss, minId)

    get "/@name/lists/@list/rss":
      cond '.' notin @"name"
      let list = await getListTimeline(@"name", @"list", @"max_position", getAgent(), media=false)
      let rss = renderListRss(list.content, @"name", @"list", cfg.hostname)
      respRss(rss, list.minId)
