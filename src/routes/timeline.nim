import asyncdispatch, strutils, sequtils, uri, options
import jester, karax/vdom

import router_utils
import ".."/[api, types, cache, formatters, agents, query]
import ../views/[general, profile, timeline, status, search]

export vdom
export uri, sequtils
export router_utils
export api, cache, formatters, query, agents
export profile, timeline, status

proc getQuery*(request: Request; tab, name: string): Query =
  case tab
  of "with_replies": getReplyQuery(name)
  of "media": getMediaQuery(name)
  of "search": initQuery(params(request), name=name)
  else: Query()

proc fetchTimeline*(name, after, agent: string; query: Query): Future[Timeline] =
  case query.kind
  of QueryKind.media: getMediaTimeline(name, after, agent)
  of posts: getTimeline(name, after, agent)
  else: getSearch[Tweet](query, after, agent)

proc fetchSingleTimeline*(name, after, agent: string; query: Query;
                          media=true): Future[(Profile, Timeline)] {.async.} =
  var timeline: Timeline
  var profile: Profile
  var cachedProfile = hasCachedProfile(name)

  if cachedProfile.isSome:
    profile = get(cachedProfile)

  if query.kind == posts and cachedProfile.isNone:
    (profile, timeline) = await getProfileAndTimeline(name, after, agent, media)
    cache(profile)
  else:
    let timelineFut = fetchTimeline(name, after, agent, query)
    if cachedProfile.isNone:
      profile = await getCachedProfile(name, agent)
    timeline = await timelineFut

  if profile.username.len == 0: return
  return (profile, timeline)

proc fetchMultiTimeline*(names: seq[string]; after, agent: string; query: Query;
                         media=true): Future[Timeline] {.async.} =
  var q = query
  q.fromUser = names
  if q.kind == posts and "replies" notin q.excludes:
    q.excludes.add "replies"
  return await getSearch[Tweet](q, after, agent, media)

proc get*(req: Request; key: string): string =
  params(req).getOrDefault(key)

proc showTimeline*(request: Request; query: Query; cfg: Config; prefs: Prefs;
                   rss, after: string): Future[string] {.async.} =
  let agent = getAgent()
  let names = getNames(request.get("name"))

  if names.len != 1:
    let timeline = await fetchMultiTimeline(names, after, agent, query)
    let html = renderTweetSearch(timeline, prefs, getPath())
    return renderMain(html, request, cfg, "Multi", rss=rss)

  let
    rail = getPhotoRail(names[0], agent, skip=(query.kind == media))
    (p, t) = await fetchSingleTimeline(names[0], after, agent, query)
    r = await rail
  if p.username.len == 0: return
  let pHtml = renderProfile(p, t, r, prefs, getPath())
  return renderMain(pHtml, request, cfg, pageTitle(p), pageDesc(p),
                    rss=rss, images = @[p.getUserpic("_200x200")])

template respTimeline*(timeline: typed) =
  if timeline.len == 0:
    resp Http404, showError("User \"" & @"name" & "\" not found", cfg)
  resp timeline

template respScroll*(timeline: typed) =
  timeline.beginning = true # don't render "load newest"
  resp $renderTimelineTweets(timeline, prefs, getPath())

proc createTimelineRouter*(cfg: Config) =
  setProfileCacheTime(cfg.profileCacheTime)

  router timeline:
    get "/@name/?@tab?":
      cond '.' notin @"name"
      cond @"tab" in ["with_replies", "media", "search", ""]
      let
        prefs = cookiePrefs()
        after = @"max_position"
        query = request.getQuery(@"tab", @"name")

      if @"scroll".len > 0:
        respScroll(await fetchTimeline(@"name", after, getAgent(), query))

      var rss = "/$1/$2/rss" % [@"name", @"tab"]
      if @"tab".len == 0:
        rss = "/$1/rss" % @"name"
      elif @"tab" == "search":
        rss &= "?" & genQueryUrl(query)

      respTimeline(await showTimeline(request, query, cfg, prefs, rss, after))
