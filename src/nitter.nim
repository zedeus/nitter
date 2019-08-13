import asyncdispatch, asyncfile, httpclient, sequtils, strutils, strformat, uri, os
from net import Port

import jester, regex

import api, utils, types, cache, formatters, search, config, prefs, agents
import views/[general, profile, status, preferences]

const configPath {.strdefine.} = "./nitter.conf"
let cfg = getConfig(configPath)

proc showSingleTimeline(name, after, agent: string; query: Option[Query];
                        prefs: Prefs): Future[string] {.async.} =
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

  let profileHtml = renderProfile(profile, timeline, await railFut, prefs)
  return renderMain(profileHtml, prefs, title=cfg.title, titleText=pageTitle(profile),
                    desc=pageDesc(profile))

proc showMultiTimeline(names: seq[string]; after, agent: string; query: Option[Query];
                       prefs: Prefs): Future[string] {.async.} =
  var q = query
  if q.isSome:
    get(q).fromUser = names
  else:
    q = some(Query(kind: multi, fromUser: names, excludes: @["replies"]))

  var timeline = renderMulti(await getTimelineSearch(get(q), after, agent),
                             names.join(","), prefs)

  return renderMain(timeline, prefs, title=cfg.title, titleText="Multi")

proc showTimeline(name, after: string; query: Option[Query];
                  prefs: Prefs): Future[string] {.async.} =
  let agent = getAgent()
  let names = name.strip(chars={'/'}).split(",").filterIt(it.len > 0)

  if names.len == 1:
    return await showSingleTimeline(names[0], after, agent, query, prefs)
  else:
    return await showMultiTimeline(names, after, agent, query, prefs)

template respTimeline(timeline: typed) =
  if timeline.len == 0:
    resp Http404, showError("User \"" & @"name" & "\" not found", cfg.title, prefs)
  resp timeline

proc getCookiePrefs(request: Request): Prefs =
  getPrefs(request.cookies.getOrDefault("preferences"))

setProfileCacheTime(cfg.profileCacheTime)

settings:
  port = Port(cfg.port)
  staticDir = cfg.staticDir
  bindAddr = cfg.address

routes:
  get "/":
    let prefs = getCookiePrefs(request)
    resp renderMain(renderSearch(), prefs, title=cfg.title)

  post "/search":
    if @"query".len == 0:
      resp Http404, showError("Please enter a username.", cfg.title,
                              getCookiePrefs(request))
    redirect("/" & @"query")

  post "/saveprefs":
    var prefs = getCookiePrefs(request)
    genUpdatePrefs()
    setCookie("preferences", $prefs.id, daysForward(360))
    redirect("/settings")

  get "/settings":
    let prefs = getCookiePrefs(request)
    resp renderMain(renderPreferences(prefs), prefs, title=cfg.title, titleText="Preferences")

  get "/@name/?":
    cond '.' notin @"name"
    let prefs = getCookiePrefs(request)
    respTimeline(await showTimeline(@"name", @"after", none(Query), prefs))

  get "/@name/search":
    cond '.' notin @"name"
    let prefs = getCookiePrefs(request)
    let query = initQuery(@"filter", @"include", @"not", @"sep", @"name")
    respTimeline(await showTimeline(@"name", @"after", some(query), prefs))

  get "/@name/replies":
    cond '.' notin @"name"
    let prefs = getCookiePrefs(request)
    respTimeline(await showTimeline(@"name", @"after", some(getReplyQuery(@"name")), prefs))

  get "/@name/media":
    cond '.' notin @"name"
    let prefs = getCookiePrefs(request)
    respTimeline(await showTimeline(@"name", @"after", some(getMediaQuery(@"name")), prefs))

  get "/@name/status/@id":
    cond '.' notin @"name"
    let prefs = getCookiePrefs(request)

    let conversation = await getTweet(@"name", @"id", getAgent())
    if conversation == nil or conversation.tweet.id.len == 0:
      resp Http404, showError("Tweet not found", cfg.title, prefs)

    let title = pageTitle(conversation.tweet.profile)
    let desc = conversation.tweet.text
    let html = renderConversation(conversation, prefs)

    if conversation.tweet.video.isSome():
      let thumb = get(conversation.tweet.video).thumb
      let vidUrl = getVideoEmbed(conversation.tweet.id)
      resp renderMain(html, prefs, title=cfg.title, titleText=title, desc=desc,
                      images = @[thumb], `type`="video", video=vidUrl)
    elif conversation.tweet.gif.isSome():
      let thumb = get(conversation.tweet.gif).thumb
      let vidUrl = getVideoEmbed(conversation.tweet.id)
      resp renderMain(html, prefs, title=cfg.title, titleText=title, desc=desc,
                      images = @[thumb], `type`="video", video=vidUrl)
    else:
      resp renderMain(html, prefs, title=cfg.title, titleText=title,
                      desc=desc, images=conversation.tweet.photos)

  get "/pic/@sig/@url":
    cond "http" in @"url"
    cond "twimg" in @"url"
    let prefs = getCookiePrefs(request)

    let
      uri = parseUri(decodeUrl(@"url"))
      path = uri.path.split("/")[2 .. ^1].join("/")
      filename = cfg.cacheDir / cleanFilename(path & uri.query)

    if getHmac($uri) != @"sig":
      resp showError("Failed to verify signature", cfg.title, prefs)

    if not existsDir(cfg.cacheDir):
      createDir(cfg.cacheDir)

    if not existsFile(filename):
      let client = newAsyncHttpClient()
      await client.downloadFile($uri, filename)
      client.close()

    if not existsFile(filename):
      resp Http404

    let file = openAsync(filename)
    let buf = await readAll(file)
    file.close()

    resp buf, mimetype(filename)

  get "/video/@sig/@url":
    cond "http" in @"url"
    cond "video.twimg" in @"url"
    let prefs = getCookiePrefs(request)
    let url = decodeUrl(@"url")

    if getHmac(url) != @"sig":
      resp showError("Failed to verify signature", cfg.title, prefs)

    let client = newAsyncHttpClient()
    let video = await client.getContent(url)
    client.close()

    resp video, mimetype(url)

runForever()
