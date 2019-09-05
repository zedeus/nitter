import asyncdispatch, asyncfile, httpclient, uri, os
import sequtils, strformat, strutils
from net import Port

import jester, regex

import api, utils, types, cache, formatters, search, config, prefs, agents
import views/[general, profile, status, preferences]

const configPath {.strdefine.} = "./nitter.conf"
let cfg = getConfig(configPath)

proc showSingleTimeline(name, after, agent: string; query: Option[Query];
                        prefs: Prefs; path: string): Future[string] {.async.} =
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
  return renderMain(profileHtml, prefs, cfg.title, pageTitle(profile),
                    pageDesc(profile), path)

proc showMultiTimeline(names: seq[string]; after, agent: string; query: Option[Query];
                       prefs: Prefs; path: string): Future[string] {.async.} =
  var q = query
  if q.isSome:
    get(q).fromUser = names
  else:
    q = some(Query(kind: multi, fromUser: names, excludes: @["replies"]))

  var timeline = renderMulti(await getTimelineSearch(get(q), after, agent),
                             names.join(","), prefs, path)

  return renderMain(timeline, prefs, cfg.title, "Multi")

proc showTimeline(name, after: string; query: Option[Query];
                  prefs: Prefs; path: string): Future[string] {.async.} =
  let agent = getAgent()
  let names = name.strip(chars={'/'}).split(",").filterIt(it.len > 0)

  if names.len == 1:
    return await showSingleTimeline(names[0], after, agent, query, prefs, path)
  else:
    return await showMultiTimeline(names, after, agent, query, prefs, path)

template respTimeline(timeline: typed) =
  if timeline.len == 0:
    resp Http404, showError("User \"" & @"name" & "\" not found", cfg.title)
  resp timeline

template cookiePrefs(): untyped {.dirty.} =
  getPrefs(request.cookies.getOrDefault("preferences"))

template getPath(): untyped {.dirty.} =
  $(parseUri(request.path) ? filterParams(request.params))

template refPath(): untyped {.dirty.} =
  if @"referer".len > 0: @"referer" else: "/"

setProfileCacheTime(cfg.profileCacheTime)

settings:
  port = Port(cfg.port)
  staticDir = cfg.staticDir
  bindAddr = cfg.address

routes:
  get "/":
    resp renderMain(renderSearch(), Prefs(), cfg.title)

  post "/search":
    if @"query".len == 0:
      resp Http404, showError("Please enter a username.", cfg.title)
    redirect("/" & @"query")

  get "/settings":
    let prefs = cookiePrefs()
    let path = refPath()
    resp renderMain(renderPreferences(prefs, path), prefs, cfg.title,
                    "Preferences", path)

  post "/saveprefs":
    var prefs = cookiePrefs()
    genUpdatePrefs()
    setCookie("preferences", $prefs.id, daysForward(360), httpOnly=true, secure=cfg.useHttps)
    redirect(refPath())

  post "/resetprefs":
    var prefs = cookiePrefs()
    resetPrefs(prefs)
    setCookie("preferences", $prefs.id, daysForward(360), httpOnly=true, secure=cfg.useHttps)
    redirect($(parseUri("/settings") ? filterParams(request.params)))

  post "/enablehls":
    var prefs = cookiePrefs()
    prefs.hlsPlayback = true
    cache(prefs)
    setCookie("preferences", $prefs.id, daysForward(360), httpOnly=true, secure=cfg.useHttps)
    redirect(refPath())

  get "/@name/?":
    cond '.' notin @"name"
    respTimeline(await showTimeline(@"name", @"after", none(Query),
                                    cookiePrefs(), getPath()))

  get "/@name/search":
    cond '.' notin @"name"
    let prefs = cookiePrefs()
    let query = initQuery(@"filter", @"include", @"not", @"sep", @"name")
    respTimeline(await showTimeline(@"name", @"after", some(query),
                                    cookiePrefs(), getPath()))

  get "/@name/replies":
    cond '.' notin @"name"
    let prefs = cookiePrefs()
    respTimeline(await showTimeline(@"name", @"after", some(getReplyQuery(@"name")),
                                    cookiePrefs(), getPath()))

  get "/@name/media":
    cond '.' notin @"name"
    let prefs = cookiePrefs()
    respTimeline(await showTimeline(@"name", @"after", some(getMediaQuery(@"name")),
                                    cookiePrefs(), getPath()))

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

  get "/pic/@sig/@url":
    cond "http" in @"url"
    cond "twimg" in @"url"
    let
      uri = parseUri(decodeUrl(@"url"))
      path = uri.path.split("/")[2 .. ^1].join("/")
      filename = cfg.cacheDir / cleanFilename(path & uri.query)

    if getHmac($uri) != @"sig":
      resp showError("Failed to verify signature", cfg.title)

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
    var url = decodeUrl(@"url")
    let prefs = cookiePrefs()

    if getHmac(url) != @"sig":
      resp showError("Failed to verify signature", cfg.title)

    let client = newAsyncHttpClient()
    var content = await client.getContent(url)

    if ".vmap" in url:
      var m: RegexMatch
      discard content.find(re"""url="(.+.m3u8)"""", m)
      url = decodeUrl(content[m.group(0)[0]])
      content = await client.getContent(url)

    if ".m3u8" in url:
      content = proxifyVideo(content, prefs.proxyVideos)

    client.close()
    resp content, mimetype(url)

runForever()
