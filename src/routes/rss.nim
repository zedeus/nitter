import asyncdispatch, strutils, tables, times, sequtils, hashes, supersnappy

import jester

import router_utils, timeline
import ../query

include "../views/rss.nimf"

export times, hashes, supersnappy

proc timelineRss*(req: Request; cfg: Config; query: Query): Future[Rss] {.async.} =
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
    var q = query
    q.fromUser = names
    timeline = await getSearch[Tweet](q, after)
    # this is kinda dumb
    profile = Profile(
      username: name,
      fullname: names.join(" | "),
      userpic: "https://abs.twimg.com/sticky/default_profile_images/default_profile.png"
    )

  if profile.suspended:
    return Rss(feed: profile.username, cursor: "suspended")

  if profile.fullname.len > 0:
    let rss = compress renderTimelineRss(timeline, profile, cfg, multi=(names.len > 1))
    return Rss(feed: rss, cursor: timeline.bottom)

template respRss*(rss) =
  if rss.cursor.len == 0:
    resp Http404, showError("User \"" & @"name" & "\" not found", cfg)
  elif rss.cursor.len == 9 and rss.cursor == "suspended":
    resp Http404, showError(getSuspended(rss.feed), cfg)

  let headers = {"Content-Type": "application/rss+xml; charset=utf-8",
                 "Min-Id": rss.cursor}
  resp Http200, headers, uncompress rss.feed

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

      var rss = await getCachedRss(key)
      if rss.cursor.len > 0:
        respRss(rss)

      let tweets = await getSearch[Tweet](query, cursor)
      rss.cursor = tweets.bottom
      rss.feed = compress renderSearchRss(tweets.content, query.text,
                                          genQueryUrl(query), cfg)

      await cacheRss(key, rss)
      respRss(rss)

    get "/@name/rss":
      cond '.' notin @"name"
      let
        cursor = getCursor()
        name = @"name"
        key = name & cursor

      var rss = await getCachedRss(key)
      if rss.cursor.len > 0:
        respRss(rss)

      rss = await timelineRss(request, cfg, Query(fromUser: @[name]))

      await cacheRss(key, rss)
      respRss(rss)

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
        key &= $hash(genQueryUrl(query))
      key &= getCursor()

      var rss = await getCachedRss(key)
      if rss.cursor.len > 0:
        respRss(rss)

      rss = await timelineRss(request, cfg, query)

      await cacheRss(key, rss)
      respRss(rss)

    get "/@name/lists/@list/rss":
      cond '.' notin @"name"
      let
        cursor = getCursor()
        key = @"name" & "/" & @"list" & cursor

      var rss = await getCachedRss(key)
      if rss.cursor.len > 0:
        respRss(rss)

      let
        list = await getCachedList(@"name", @"list")
        timeline = await getListTimeline(list.id, cursor)
      rss.cursor = timeline.bottom
      rss.feed = compress renderListRss(timeline.content, list, cfg)

      await cacheRss(key, rss)
      respRss(rss)
