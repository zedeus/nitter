import asyncdispatch, strutils, tables, times, sequtils, hashes

import jester

import router_utils, timeline
import ".."/[redis_cache, query], ../views/general

include "../views/rss.nimf"

export times, hashes

proc showRss*(req: Request; hostname: string; query: Query): Future[(string, string)] {.async.} =
  var profile: Profile
  var timeline: Timeline
  let
    name = req.params.getOrDefault("name")
    after = getCursor(req)
    names = getNames(name)

  if names.len == 1:
    (profile, timeline) =
      await fetchSingleTimeline(after, query, skipRail=true)
  else:
    let multiQuery = query.getMultiQuery(names)
    timeline = await getSearch[Tweet](multiQuery, after)
    # this is kinda dumb
    profile = Profile(
      username: name,
      fullname: names.join(" | "),
      userpic: "https://abs.twimg.com/sticky/default_profile_images/default_profile.png"
    )

  if profile.suspended:
    return (profile.username, "suspended")

  if profile.fullname.len > 0:
    let rss = renderTimelineRss(timeline, profile, hostname, multi=(names.len > 1))
    return (rss, timeline.bottom)

template respRss*(rss, minId) =
  if rss.len == 0:
    resp Http404, showError("User \"" & @"name" & "\" not found", cfg)
  elif minId == "suspended":
    resp Http404, showError(getSuspended(rss), cfg)
  let headers = {"Content-Type": "application/rss+xml; charset=utf-8", "Min-Id": minId}
  resp Http200, headers, rss

proc createRssRouter*(cfg: Config) =
  router rss:
    get "/search/rss":
      if @"q".len > 200:
        resp Http400, showError("Search input too long.", cfg)

      let query = initQuery(params(request))
      if query.kind != tweets:
        resp Http400, showError("Only Tweet searches are allowed for RSS feeds.", cfg)

      let
        cursor = getCursor()
        key = $hash(genQueryUrl(query)) & cursor
        (cRss, cCursor) = await getCachedRss(key)

      if cRss.len > 0:
        respRss(cRss, cCursor)

      let
        tweets = await getSearch[Tweet](query, cursor)
        rss = renderSearchRss(tweets.content, query.text, genQueryUrl(query), cfg.hostname)

      await cacheRss(key, rss, tweets.bottom)
      respRss(rss, tweets.bottom)

    get "/@name/rss":
      cond '.' notin @"name"
      let
        cursor = getCursor()
        name = @"name"
        (cRss, cCursor) = await getCachedRss(name & cursor)

      if cRss.len > 0:
        respRss(cRss, cCursor)

      let (rss, rssCursor) = await showRss(request, cfg.hostname,
                                           Query(fromUser: @[name]))

      await cacheRss(name & cursor, rss, rssCursor)
      respRss(rss, rssCursor)

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

      var key = @"name" & "/" & @"tab"
      if @"tab" == "search":
        key &= hash(genQueryUrl(query))
      key &= getCursor()

      let (cRss, cCursor) = await getCachedRss(key)
      if cRss.len > 0:
        respRss(cRss, cCursor)

      let (rss, rssCursor) = await showRss(request, cfg.hostname, query)
      await cacheRss(key, rss, rssCursor)
      respRss(rss, rssCursor)

    get "/@name/lists/@list/rss":
      cond '.' notin @"name"
      let
        cursor = getCursor()
        key = @"name" & "/" & @"list" & cursor
        (cRss, cCursor) = await getCachedRss(key)

      if cRss.len > 0:
        respRss(cRss, cCursor)

      let
        list = await getCachedList(@"name", @"list")
        timeline = await getListTimeline(list.id, cursor)
        rss = renderListRss(timeline.content, list, cfg.hostname)

      await cacheRss(key, rss, timeline.bottom)
      respRss(rss, timeline.bottom)
