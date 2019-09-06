import asyncdispatch, strutils, sequtils, uri

import jester

import router_utils
import ".."/[api, prefs, types, utils, cache, formatters, agents, search]
import ../views/[general, profile, timeline, status]

export uri, sequtils
export router_utils
export api, cache, formatters, search, agents
export profile, timeline, status

proc showSingleTimeline(name, after, agent: string; query: Option[Query];
                        prefs: Prefs; path, title: string): Future[string] {.async.} =
  let railFut = getPhotoRail(name, agent)

  var timeline: Timeline
  var profile: Profile
  var cachedProfile = hasCachedProfile(name)

  if cachedProfile.isSome:
    profile = get(cachedProfile)

  if query.isNone:
    if cachedProfile.isSome:
      timeline = await getTimeline(name, after, agent)
    else:
      (profile, timeline) = await getProfileAndTimeline(name, agent, after)
      cache(profile)
  else:
    var timelineFut = getTimelineSearch(get(query), after, agent)
    if cachedProfile.isNone:
      profile = await getCachedProfile(name, agent)
    timeline = await timelineFut

  if profile.username.len == 0:
    return ""

  let profileHtml = renderProfile(profile, timeline, await railFut, prefs, path)
  return renderMain(profileHtml, prefs, title, pageTitle(profile),
                    pageDesc(profile), path)

proc showMultiTimeline(names: seq[string]; after, agent: string; query: Option[Query];
                       prefs: Prefs; path, title: string): Future[string] {.async.} =
  var q = query
  if q.isSome:
    get(q).fromUser = names
  else:
    q = some(Query(kind: multi, fromUser: names, excludes: @["replies"]))

  var timeline = renderMulti(await getTimelineSearch(get(q), after, agent),
                             names.join(","), prefs, path)

  return renderMain(timeline, prefs, title, "Multi")

proc showTimeline*(name, after: string; query: Option[Query];
                  prefs: Prefs; path, title: string): Future[string] {.async.} =
  let agent = getAgent()
  let names = name.strip(chars={'/'}).split(",").filterIt(it.len > 0)

  if names.len == 1:
    return await showSingleTimeline(names[0], after, agent, query, prefs, path, title)
  else:
    return await showMultiTimeline(names, after, agent, query, prefs, path, title)

template respTimeline*(timeline: typed) =
  if timeline.len == 0:
    resp Http404, showError("User \"" & @"name" & "\" not found", cfg.title)
  resp timeline

proc createTimelineRouter*(cfg: Config) =
  setProfileCacheTime(cfg.profileCacheTime)

  router timeline:
    get "/@name/?":
      cond '.' notin @"name"
      respTimeline(await showTimeline(@"name", @"after", none(Query),
                                      cookiePrefs(), getPath(), cfg.title))

    get "/@name/search":
      cond '.' notin @"name"
      let query = initQuery(@"filter", @"include", @"not", @"sep", @"name")
      respTimeline(await showTimeline(@"name", @"after", some(query),
                                      cookiePrefs(), getPath(), cfg.title))

    get "/@name/replies":
      cond '.' notin @"name"
      respTimeline(await showTimeline(@"name", @"after", some(getReplyQuery(@"name")),
                                      cookiePrefs(), getPath(), cfg.title))

    get "/@name/media":
      cond '.' notin @"name"
      respTimeline(await showTimeline(@"name", @"after", some(getMediaQuery(@"name")),
                                      cookiePrefs(), getPath(), cfg.title))

    get "/@name/status/@id":
      cond '.' notin @"name"
      let prefs = cookiePrefs()

      let conversation = await getTweet(@"name", @"id", getAgent())
      if conversation == nil or conversation.tweet.id.len == 0:
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
        resp renderMain(html, prefs, cfg.title, title, desc, path, images=conversation.tweet.photos)

    get "/i/web/status/@id":
      redirect("/i/status/" & @"id")
