import asyncdispatch, asyncfile, httpclient, strutils, strformat, uri, os
import jester, regex

import api, utils, types, cache, formatters, search

include views/"user.nimf"
include views/"general.nimf"

const cacheDir {.strdefine.} = "/tmp/nitter"

proc showTimeline(name, after: string; query: Option[Query]): Future[string] {.async.} =
  let
    username = name.strip(chars={'/'})
    profileFut = getCachedProfile(username)

  var timelineFut: Future[Timeline]
  if query.isNone:
     timelineFut = getTimeline(username, after)
  else:
    timelineFut = getTimelineSearch(username, after, get(query))

  let profile = await profileFut
  if profile.username.len == 0:
    return ""

  let profileHtml = renderProfile(profile, await timelineFut, after.len == 0)
  return renderMain(profileHtml, title=pageTitle(profile))

template respTimeline(timeline: typed) =
  if timeline.len == 0:
    resp Http404, showError("User \"" & @"name" & "\" not found")
  resp timeline

routes:
  get "/":
    resp renderMain(renderSearchPanel(), title=pageTitle("Search"))

  post "/search":
    if @"query".len == 0:
      resp Http404, showError("Please enter a username.")
    redirect("/" & @"query")

  get "/@name/?":
    cond '.' notin @"name"
    respTimeline(await showTimeline(@"name", @"after", none(Query)))

  get "/@name/search/?":
    cond '.' notin @"name"
    let query = initQuery(@"filter", @"sep", @"name")
    respTimeline(await showTimeline(@"name", @"after", some(query)))

  get "/@name/replies":
    cond '.' notin @"name"
    respTimeline(await showTimeline(@"name", @"after", some(getReplyQuery(@"name"))))

  get "/@name/media":
    cond '.' notin @"name"
    respTimeline(await showTimeline(@"name", @"after", some(getMediaQuery(@"name"))))

  get "/@name/status/@id":
    cond '.' notin @"name"

    let conversation = await getTweet(@"name", @"id")
    if conversation == nil or conversation.tweet.id.len == 0:
      resp Http404, showError("Tweet not found")

    let title = pageTitle(conversation.tweet.profile)
    resp renderMain(renderConversation(conversation), title=title)

  get "/pic/@sig/@url":
    cond "http" in @"url"
    cond "twimg" in @"url"

    let
      uri = parseUri(decodeUrl(@"url"))
      path = uri.path.split("/")[2 .. ^1].join("/")
      filename = cacheDir / cleanFilename(path & uri.query)

    if getHmac($uri) != @"sig":
      resp showError("Failed to verify signature")

    if not existsDir(cacheDir):
      createDir(cacheDir)

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
      resp showError("Failed to verify signature")

    let
      client = newAsyncHttpClient()
      video = await client.getContent(url)

    defer: client.close()
    resp video, mimetype(url)

runForever()
