import asyncdispatch, strutils, sequtils, uri

import jester

import router_utils
import ".."/[api, prefs, types, utils, cache, formatters, agents, query]
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

proc showTimeline*(name, after: string; query: Query;
                   prefs: Prefs; path, title, rss: string): Future[string] {.async.} =
  let agent = getAgent()
  let names = name.strip(chars={'/'}).split(",").filterIt(it.len > 0)

  if names.len == 1:
    let (p, t, r) = await fetchSingleTimeline(names[0], after, agent, query)
    if p.username.len == 0: return
    let pHtml = renderProfile(p, t, r, prefs, path)
    return renderMain(pHtml, prefs, title, pageTitle(p), pageDesc(p), path, rss=rss)
  else:
    let
      timeline = await fetchMultiTimeline(names, after, agent, query)
      html = renderTweetSearch(timeline, prefs, path)
    return renderMain(html, prefs, title, "Multi")

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
      respTimeline(await showTimeline(@"name", @"after", Query(), cookiePrefs(),
                                      getPath(), cfg.title, rss))

    get "/@name/replies":
      cond '.' notin @"name"
      let rss = "/$1/replies/rss" % @"name"
      respTimeline(await showTimeline(@"name", @"after", getReplyQuery(@"name"),
                                      cookiePrefs(), getPath(), cfg.title, rss))

    get "/@name/media":
      cond '.' notin @"name"
      let rss = "/$1/media/rss" % @"name"
      respTimeline(await showTimeline(@"name", @"after", getMediaQuery(@"name"),
                                      cookiePrefs(), getPath(), cfg.title, rss))

    get "/@name/search":
      cond '.' notin @"name"
      let query = initQuery(params(request), name=(@"name"))
      let rss = "/$1/search/rss?$2" % [@"name", genQueryUrl(query, onlyParam=true)]
      respTimeline(await showTimeline(@"name", @"after", query, cookiePrefs(),
                                      getPath(), cfg.title, rss))

    get "/@name/status/@id":
      cond '.' notin @"name"
      let prefs = cookiePrefs()

      let conversation = await getTweet(@"name", @"id", getAgent())
      if conversation == nil or conversation.tweet.id.len == 0:
        if conversation != nil and conversation.tweet.tombstone.len > 0:
          resp Http404, showError(conversation.tweet.tombstone, cfg.title)
        else:
          resp Http404, showError("Tweet not found", cfg.title)

      let path = getPath()
      let title = pageTitle(conversation.tweet.profile)
      let desc = conversation.tweet.text
      let html = renderConversation(conversation, prefs, path)

      if conversation.tweet.video.isSome():
        let thumb = get(conversation.tweet.video).thumb
        let vidUrl = getVideoEmbed(conversation.tweet.id)
        resp renderMain(html, prefs, cfg.title, title, desc, path, images = @[thumb],
                        `type`="video", video=vidUrl)
      elif conversation.tweet.gif.isSome():
        let thumb = get(conversation.tweet.gif).thumb
        let vidUrl = getVideoEmbed(conversation.tweet.id)
        resp renderMain(html, prefs, cfg.title, title, desc, path, images = @[thumb],
                        `type`="video", video=vidUrl)
      else:
        resp renderMain(html, prefs, cfg.title, title, desc, path,
                        images=conversation.tweet.photos, `type`="photo")

    get "/i/web/status/@id":
      redirect("/i/status/" & @"id")
