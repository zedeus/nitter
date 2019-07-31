import asyncdispatch, asyncfile, httpclient, strutils, strformat, uri, os
from net import Port

import jester, regex

import api, utils, types, cache, formatters, search, config, agents
import views/[general, profile, status]

const configPath {.strdefine.} = "./nitter.conf"
let cfg = getConfig(configPath)

proc showTimeline(name, after: string; query: Option[Query]): Future[string] {.async.} =
  let
    agent = getAgent()
    username = name.strip(chars={'/'})
    profileFut = getCachedProfile(username, agent)
    railFut = getPhotoRail(username, agent)

  var timelineFut: Future[Timeline]
  if query.isNone:
    timelineFut = getTimeline(username, after, agent)
  else:
    timelineFut = getTimelineSearch(username, after, agent, get(query))

  let profile = await profileFut
  if profile.username.len == 0:
    return ""

  let profileHtml = renderProfile(profile, await timelineFut, await railFut)
  return renderMain(profileHtml, title=cfg.title, titleText=pageTitle(profile))

template respTimeline(timeline: typed) =
  if timeline.len == 0:
    resp Http404, showError("User \"" & @"name" & "\" not found", cfg.title)
  resp timeline

setProfileCacheTime(cfg.profileCacheTime)

settings:
  port = Port(cfg.port)
  staticDir = cfg.staticDir
  bindAddr = cfg.address

routes:
  get "/":
    resp renderMain(renderSearch(), title=cfg.title, titleText="Search")

  post "/search":
    if @"query".len == 0:
      resp Http404, showError("Please enter a username.", cfg.title)
    redirect("/" & @"query")

  get "/@name/?":
    cond '.' notin @"name"
    respTimeline(await showTimeline(@"name", @"after", none(Query)))

  get "/@name/search":
    cond '.' notin @"name"
    let query = initQuery(@"filter", @"include", @"not", @"sep", @"name")
    respTimeline(await showTimeline(@"name", @"after", some(query)))

  get "/@name/replies":
    cond '.' notin @"name"
    respTimeline(await showTimeline(@"name", @"after", some(getReplyQuery(@"name"))))

  get "/@name/media":
    cond '.' notin @"name"
    respTimeline(await showTimeline(@"name", @"after", some(getMediaQuery(@"name"))))

  get "/@name/status/@id":
    cond '.' notin @"name"

    let conversation = await getTweet(@"name", @"id", getAgent())
    if conversation == nil or conversation.tweet.id.len == 0:
      resp Http404, showError("Tweet not found", cfg.title)

    let title = pageTitle(conversation.tweet.profile)
    resp renderMain(renderConversation(conversation), title=cfg.title, titleText=title)

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
    defer: file.close()

    resp await readAll(file), mimetype(filename)

  get "/video/@sig/@url":
    cond "http" in @"url"
    cond "video.twimg" in @"url"
    let url = decodeUrl(@"url")

    if getHmac(url) != @"sig":
      resp showError("Failed to verify signature", cfg.title)

    let
      client = newAsyncHttpClient()
      video = await client.getContent(url)

    defer: client.close()
    resp video, mimetype(url)

runForever()
