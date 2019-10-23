import asyncdispatch, strutils, sequtils, uri

import jester

import router_utils
import ".."/[api, types, cache, formatters, agents, query]
import ../views/[general, profile, timeline, status, search]

export uri, sequtils
export router_utils
export api, cache, formatters, query, agents
export profile, timeline, status

proc fetchSingleTimeline*(name, after, agent: string; query: Query;
                          media=true): Future[(Profile, Timeline)] {.async.} =
  var timeline: Timeline
  var profile: Profile
  var cachedProfile = hasCachedProfile(name)

  if cachedProfile.isSome:
    profile = get(cachedProfile)

  if query.kind == posts:
    if cachedProfile.isSome:
      timeline = await getTimeline(name, after, agent, media)
    else:
      (profile, timeline) = await getProfileAndTimeline(name, agent, after, media)
      cache(profile)
  else:
    var timelineFut =
      if query.kind == QueryKind.media:
        getMediaTimeline(name, after, agent, media)
      else:
        getSearch[Tweet](query, after, agent, media)
    if cachedProfile.isNone:
      profile = await getCachedProfile(name, agent)
    timeline = await timelineFut

  if profile.username.len == 0: return
  return (profile, timeline)

proc fetchMultiTimeline*(names: seq[string]; after, agent: string;
                         query: Query): Future[Timeline] {.async.} =
  var q = query
  q.fromUser = names
  if q.kind == posts and "replies" notin q.excludes:
    q.excludes.add "replies"
  return await getSearch[Tweet](q, after, agent)

proc get*(req: Request; key: string): string =
  if key in params(req): params(req)[key]
  else: ""

proc showTimeline*(request: Request; query: Query; cfg: Config; rss: string): Future[string] {.async.} =
  let
    agent = getAgent()
    prefs = cookiePrefs()
    name = request.get("name")
    after = request.get("max_position")
    names = name.strip(chars={'/'}).split(",").filterIt(it.len > 0)

  if names.len == 1:
    let
      rail = getPhotoRail(names[0], agent, skip=(query.kind == media))
      (p, t) = await fetchSingleTimeline(names[0], after, agent, query)
      r = await rail
    if p.username.len == 0: return
    let pHtml = renderProfile(p, t, r, prefs, getPath())
    return renderMain(pHtml, request, cfg, pageTitle(p), pageDesc(p),
                      rss=rss, images = @[p.getUserpic("_200x200")])
  else:
    let
      timeline = await fetchMultiTimeline(names, after, agent, query)
      html = renderTweetSearch(timeline, prefs, getPath())
    return renderMain(html, request, cfg, "Multi")

template respTimeline*(timeline: typed) =
  if timeline.len == 0:
    resp Http404, showError("User \"" & @"name" & "\" not found", cfg)
  resp timeline

proc createTimelineRouter*(cfg: Config) =
  setProfileCacheTime(cfg.profileCacheTime)

  router timeline:
    get "/@name/?":
      cond '.' notin @"name"
      let rss = "/$1/rss" % @"name"
      respTimeline(await showTimeline(request, Query(), cfg, rss))

    get "/@name/with_replies":
      cond '.' notin @"name"
      let rss = "/$1/with_replies/rss" % @"name"
      respTimeline(await showTimeline(request, getReplyQuery(@"name"), cfg, rss))

    get "/@name/media":
      cond '.' notin @"name"
      let rss = "/$1/media/rss" % @"name"
      respTimeline(await showTimeline(request, getMediaQuery(@"name"), cfg, rss))

    get "/@name/search":
      cond '.' notin @"name"
      let query = initQuery(params(request), name=(@"name"))
      let rss = "/$1/search/rss?$2" % [@"name", genQueryUrl(query)]
      respTimeline(await showTimeline(request, query, cfg, rss))
