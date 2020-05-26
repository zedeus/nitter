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
  else: Query(fromUser: @[name])

proc fetchTimeline*(after, agent: string; query: Query): Future[Timeline] =
  case query.kind
  of QueryKind.media: getMediaTimeline(query.fromUser[0], after, agent)
  of posts: getTimeline(query.fromUser[0], after, agent)
  else: getSearch[Tweet](query, after, agent)

proc fetchSingleTimeline*(after, agent: string; query: Query;
                          media=true): Future[(Profile, Timeline)] {.async.} =
  let name = query.fromUser[0]
  var timeline: Timeline
  var profile: Profile
  var cachedProfile = hasCachedProfile(name)

  if cachedProfile.isSome:
    profile = get(cachedProfile)

  if query.kind == posts and cachedProfile.isNone:
    (profile, timeline) = await getProfileAndTimeline(name, after, agent, media)
    cache(profile)
  else:
    let timelineFut = fetchTimeline(after, agent, query)
    if cachedProfile.isNone:
      profile = await getCachedProfile(name, agent)
    timeline = await timelineFut

  if profile.username.len == 0: return
  return (profile, timeline)

proc getMultiQuery*(q: Query; names: seq[string]): Query =
  result = q
  result.fromUser = names
  if q.kind == posts and "replies" notin q.excludes:
    result.excludes.add "replies"

proc get*(req: Request; key: string): string =
  params(req).getOrDefault(key)

proc showTimeline*(request: Request; query: Query; cfg: Config; prefs: Prefs;
                   rss, after: string): Future[string] {.async.} =
  let agent = getAgent()

  if query.fromUser.len != 1:
    let
      timeline = await getSearch[Tweet](query, after, agent)
      html = renderTweetSearch(timeline, prefs, getPath())
    return renderMain(html, request, cfg, "Multi", rss=rss)

  let
    rail = getPhotoRail(query.fromUser[0], agent, skip=(query.kind == media))
    (p, t) = await fetchSingleTimeline(after, agent, query)
    r = await rail
  if p.username.len == 0: return
  if p.suspended:
    return showError(getSuspended(p.username), cfg)

  let pHtml = renderProfile(p, t, r, prefs, getPath())
  return renderMain(pHtml, request, cfg, pageTitle(p), pageDesc(p),
                    rss=rss, images = @[p.getUserpic("_200x200")])

template respTimeline*(timeline: typed) =
  let t = timeline
  if t.len == 0:
    resp Http404, showError("User \"" & @"name" & "\" not found", cfg)
  resp t

proc createTimelineRouter*(cfg: Config) =
  setProfileCacheTime(cfg.profileCacheTime)

  router timeline:
    get "/@name/?@tab?/?":
      cond '.' notin @"name"
      cond @"name" notin ["pic", "gif", "video"]
      cond @"tab" in ["with_replies", "media", "search", ""]
      let
        prefs = cookiePrefs()
        after = @"max_position"
        names = getNames(@"name")

      var query = request.getQuery(@"tab", @"name")
      if names.len != 1:
        query = query.getMultiQuery(names)

      if @"scroll".len > 0:
        if query.fromUser.len != 1:
          let timeline = await getSearch[Tweet](query, after, getAgent())
          timeline.beginning = true
          resp $renderTweetSearch(timeline, prefs, getPath())
        else:
          let timeline = await fetchTimeline(after, getAgent(), query)
          timeline.beginning = true
          resp $renderTimelineTweets(timeline, prefs, getPath())

      var rss = "/$1/$2/rss" % [@"name", @"tab"]
      if @"tab".len == 0:
        rss = "/$1/rss" % @"name"
      elif @"tab" == "search":
        rss &= "?" & genQueryUrl(query)

      respTimeline(await showTimeline(request, query, cfg, prefs, rss, after))
