import asyncdispatch, httpclient, times, strutils, hashes, random, uri
import jester, regex

import api, utils, types, cache
import views/[user, general, conversation]

proc showTimeline(name: string; num=""): Future[string] {.async.} =
  let
    username = name.strip(chars={'/'})
    profileFut = getCachedProfile(username)
    tweetsFut = getTimeline(username, after=num)

  let profile = await profileFut
  if profile.username.len == 0:
    return ""

  return renderMain(renderProfile(profile, await tweetsFut, num.len == 0))

routes:
  get "/":
    resp renderMain(renderSearchPanel())

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
    let conversation = await getTweet(@"id")
    if conversation.tweet.id.len == 0:
      resp Http404, showError("Tweet not found")

    resp renderMain(renderConversation(conversation))

  get "/pic/@sig/@url":
    cond "http" in @"url"
    cond "twimg" in @"url"
    let url = decodeUrl(@"url")

    if getHmac(url) != @"sig":
      resp showError("Failed to verify signature")

    let
      client = newAsyncHttpClient()
      pic = await client.getContent(url)

    client.close()

    resp pic, mimetype(url)

  get "/video/@sig/@url":
    cond "http" in @"url"
    cond "video.twimg" in @"url"
    let url = decodeUrl(@"url")

    if getHmac(url) != @"sig":
      resp showError("Failed to verify signature")

    let
      client = newAsyncHttpClient()
      pic = await client.getContent(url)

    defer: client.close()
    resp pic, mimetype(url)

runForever()
