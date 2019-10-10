import httpclient, asyncdispatch, times, sequtils, strutils, json, uri

import ".."/[types, parser, formatters]
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

proc getVideoFetch(tweet: Tweet; agent, token: string) {.async.} =
  if tweet.video.isNone(): return

  let
    headers = genHeaders({"authorization": auth, "x-guest-token": token},
                         agent, base / getLink(tweet), lang=false)
    url = apiBase / (videoUrl % $tweet.id)
    json = await fetchJson(url, headers)

  if json == nil:
    if getTime() - tokenUpdated > initDuration(seconds=1):
      tokenUpdated = getTime()
      discard await getGuestToken(agent, force=true)
    await getVideoFetch(tweet, agent, guestToken)
    return

  if tweet.card.isNone:
    tweet.video = some parseVideo(json, tweet.id)
  else:
    get(tweet.card).video = some parseVideo(json, tweet.id)
    tweet.video = none Video
  tokenUses.inc

proc getVideoVar(tweet: Tweet): var Option[Video] =
  if tweet.card.isSome():
    return get(tweet.card).video
  else:
    return tweet.video

proc getVideo*(tweet: Tweet; agent, token: string; force=false) {.async.} =
  withCustomDb("cache.db", "", "", ""):
    try:
      getVideoVar(tweet) = some Video.getOne("videoId = ?", tweet.id)
    except KeyError:
      await getVideoFetch(tweet, agent, token)
      var video = getVideoVar(tweet)
      if video.isSome():
        get(video).insert()

proc getPoll*(tweet: Tweet; agent: string) {.async.} =
  if tweet.poll.isNone(): return

  let
    headers = genHeaders(agent, base / getLink(tweet), auth=true)
    url = base / (pollUrl % $tweet.id)
    html = await fetchHtml(url, headers)

  if html == nil: return
  tweet.poll = some parsePoll(html)

proc getCard*(tweet: Tweet; agent: string) {.async.} =
  if tweet.card.isNone(): return

  let
    headers = genHeaders(agent, base / getLink(tweet), auth=true)
    query = get(tweet.card).query.replace("sensitive=true", "sensitive=false")
    html = await fetchHtml(base / query, headers)

  if html == nil: return
  parseCard(get(tweet.card), html)

proc getPhotoRail*(username, agent: string): Future[seq[GalleryPhoto]] {.async.} =
  let
    headers = genHeaders({"x-requested-with": "XMLHttpRequest"}, agent, base / username)
    params = {"for_photo_rail": "true", "oldest_unread_id": "0"}
    url = base / (timelineMediaUrl % username) ? params
    html = await fetchHtml(url, headers, jsonKey="items_html")

  result = parsePhotoRail(html)

genMediaGet(video, token=true)
genMediaGet(poll)
genMediaGet(card)
