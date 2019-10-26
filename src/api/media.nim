import httpclient, asyncdispatch, times, sequtils, strutils, json, uri
import macros, options

import ".."/[types, parser, formatters, cache]
import utils, consts

var
  guestToken = ""
  tokenUses = 0
  tokenMaxUses = 230
  tokenUpdated: Time
  tokenLifetime = initDuration(minutes=20)

macro genMediaGet(media: untyped; token=false) =
  let
    mediaName = capitalizeAscii($media)
    multi = ident("get" & mediaName & "s")
    convo = ident("getConversation" & mediaName & "s")
    single = ident("get" & mediaName)

  quote do:
    proc `multi`*(thread: Chain | Timeline; agent: string; token="") {.async.} =
      if thread == nil: return
      var `media` = thread.content.filterIt(it.`media`.isSome)
      when `token`:
        var gToken = token
        if gToken.len == 0: gToken = await getGuestToken(agent)
        await all(`media`.mapIt(`single`(it, token, agent)))
      else:
        await all(`media`.mapIt(`single`(it, agent)))

    proc `convo`*(convo: Conversation; agent: string) {.async.} =
      var futs: seq[Future[void]]
      when `token`:
        var token = await getGuestToken(agent)
        futs.add `single`(convo.tweet, agent, token)
        futs.add `multi`(convo.before, agent, token=token)
        futs.add `multi`(convo.after, agent, token=token)
        if convo.replies != nil:
          futs.add convo.replies.content.mapIt(`multi`(it, agent, token=token))
      else:
        futs.add `single`(convo.tweet, agent)
        futs.add `multi`(convo.before, agent)
        futs.add `multi`(convo.after, agent)
        if convo.replies != nil:
          futs.add convo.replies.content.mapIt(`multi`(it, agent))
      await all(futs)

proc getGuestToken(agent: string; force=false): Future[string] {.async.} =
  if getTime() - tokenUpdated < tokenLifetime and
     not force and tokenUses < tokenMaxUses:
    return guestToken

  tokenUpdated = getTime()
  tokenUses = 0

  let headers = genHeaders({"authorization": auth}, agent, base, lang=false)
  newClient()

  let json = parseJson(await client.postContent($(apiBase / tokenUrl)))

  if json != nil:
    result = json["guest_token"].to(string)
    guestToken = result

proc getVideoVar(tweet: Tweet): var Option[Video] =
  if tweet.card.isSome():
    return get(tweet.card).video
  else:
    return tweet.video

proc getVideoFetch(tweet: Tweet; agent, token: string): Future[Option[Video]] {.async.} =
  if tweet.video.isNone(): return

  let
    headers = genHeaders({"authorization": auth, "x-guest-token": token},
                         agent, base / getLink(tweet, focus=false), lang=false)
    url = apiBase / (videoUrl % $tweet.id)
    json = await fetchJson(url, headers)

  if json == nil:
    if getTime() - tokenUpdated > initDuration(seconds=1):
      tokenUpdated = getTime()
      discard await getGuestToken(agent, force=true)
      result = await getVideoFetch(tweet, agent, guestToken)
    return

  var video = parseVideo(json, tweet.id)
  video.title = get(tweet.video).title
  video.description = get(tweet.video).description
  cache(video)

  result = some video
  tokenUses.inc

proc getVideo*(tweet: Tweet; agent, token: string; force=false) {.async.} =
  var video = getCachedVideo(tweet.id)
  if video.isNone:
    video = await getVideoFetch(tweet, agent, token)
  getVideoVar(tweet) = video
  if tweet.card.isSome: tweet.video = none Video

proc getPoll*(tweet: Tweet; agent: string) {.async.} =
  if tweet.poll.isNone(): return

  let
    headers = genHeaders(agent, base / getLink(tweet, focus=false), auth=true)
    url = base / (pollUrl % $tweet.id)
    html = await fetchHtml(url, headers)

  if html == nil: return
  tweet.poll = some parsePoll(html)

proc getCard*(tweet: Tweet; agent: string) {.async.} =
  if tweet.card.isNone(): return

  let
    headers = genHeaders(agent, base / getLink(tweet, focus=false), auth=true)
    query = get(tweet.card).query.replace("sensitive=true", "sensitive=false")
    html = await fetchHtml(base / query, headers)

  if html == nil: return
  parseCard(get(tweet.card), html)

proc getPhotoRail*(username, agent: string; skip=false): Future[seq[GalleryPhoto]] {.async.} =
  if skip: return
  let
    headers = genHeaders(agent, base / username, xml=true)
    params = {"for_photo_rail": "true", "oldest_unread_id": "0"}
    url = base / (timelineMediaUrl % username) ? params
    html = await fetchHtml(url, headers, jsonKey="items_html")

  result = parsePhotoRail(html)

genMediaGet(video, token=true)
genMediaGet(poll)
genMediaGet(card)
