import asyncdispatch, strutils, sequtils, uri

import jester

import router_utils
import ".."/[api, prefs, types, cache, formatters, agents, query]
import ../views/[general, profile, timeline, status, search]

export uri, sequtils
export router_utils
export api, cache, formatters, query, agents
export profile, timeline, status

type ProfileTimeline = (Profile, Timeline, seq[GalleryPhoto])

proc fetchSingleTimeline*(name, after, agent: string;
                          query: Query): Future[ProfileTimeline] {.async.} =
  let railFut = getPhotoRail(name, agent)

  var timeline: Timeline
  var profile: Profile
  var cachedProfile = hasCachedProfile(name)

  if cachedProfile.isSome:
    profile = get(cachedProfile)

  if query.kind == posts:
    if cachedProfile.isSome:
      timeline = await getTimeline(name, after, agent)
    else:
      (profile, timeline) = await getProfileAndTimeline(name, agent, after)
      cache(profile)
  else:
    var timelineFut = getSearch[Tweet](query, after, agent)
    if cachedProfile.isNone:
      profile = await getCachedProfile(name, agent)
    timeline = await timelineFut

  if profile.username.len == 0: return
  return (profile, timeline, await railFut)

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

proc showTimeline*(request: Request; query: Query; title, rss: string): Future[string] {.async.} =
  let
    agent = getAgent()
    prefs = cookiePrefs()
    name = request.get("name")
    after = request.get("after")
    names = name.strip(chars={'/'}).split(",").filterIt(it.len > 0)

  if names.len == 1:
    let (p, t, r) = await fetchSingleTimeline(names[0], after, agent, query)
    if p.username.len == 0: return
    let pHtml = renderProfile(p, t, r, prefs, getPath())
    return renderMain(pHtml, request, title, pageTitle(p), pageDesc(p), rss=rss)
  else:
    let
      timeline = await fetchMultiTimeline(names, after, agent, query)
      html = renderTweetSearch(timeline, prefs, getPath())
    return renderMain(html, request, title, "Multi")

template respTimeline*(timeline: typed) =
  if timeline.len == 0:
    resp Http404, showError("User \"" & @"name" & "\" not found", cfg.title)
  resp timeline

proc createTimelineRouter*(cfg: Config) =
  setProfileCacheTime(cfg.profileCacheTime)

  router timeline:
    get "/@name/?":
      cond '.' notin @"name"
      let rss = "/$1/rss" % @"name"
      respTimeline(await showTimeline(request, Query(), cfg.title, rss))

    get "/@name/replies":
      cond '.' notin @"name"
      let rss = "/$1/replies/rss" % @"name"
      respTimeline(await showTimeline(request, getReplyQuery(@"name"), cfg.title, rss))

    get "/@name/media":
      cond '.' notin @"name"
      let rss = "/$1/media/rss" % @"name"
      respTimeline(await showTimeline(request, getMediaQuery(@"name"), cfg.title, rss))

    get "/@name/search":
      cond '.' notin @"name"
      let query = initQuery(params(request), name=(@"name"))
      let rss = "/$1/search/rss?$2" % [@"name", genQueryUrl(query)]
      respTimeline(await showTimeline(request, query, cfg.title, rss))
