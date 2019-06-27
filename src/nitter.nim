import asyncdispatch, asyncfile, httpclient, strutils, strformat, uri, os
import jester

import api, utils, types, cache, formatters

include views/"user.nimf"
include views/"general.nimf"

const cacheDir {.strdefine.} = "/tmp/nitter"

proc showTimeline(name: string; num=""): Future[string] {.async.} =
  let
    username = name.strip(chars={'/'})
    profileFut = getCachedProfile(username)
    tweetsFut = getTimeline(username, after=num)

  let profile = await profileFut
  if profile.username.len == 0:
    return ""

  let profileHtml = renderProfile(profile, await tweetsFut, num.len == 0)
  return renderMain(profileHtml, title=pageTitle(profile))

routes:
  get "/":
    resp renderMain(renderSearchPanel(), title=pageTitle("Search"))

  post "/search":
    if @"query".len == 0:
      resp Http404, showError("Please enter a username.")

    redirect("/" & @"query")

  get "/@name/?":
    cond '.' notin @"name"

    let timeline = await showTimeline(@"name", @"after")
    if timeline.len == 0:
      resp Http404, showError("User \"" & @"name" & "\" not found")

    resp timeline

  get "/@name/status/@id":
    cond '.' notin @"name"

    let conversation = await getTweet(@"name", @"id")
    if conversation.isNil or conversation.tweet.id.len == 0:
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
