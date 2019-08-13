import httpclient, asyncdispatch, htmlparser, times
import sequtils, strutils, json, xmltree, uri

import types, parser, parserutils, formatters, search

const
  lang = "en-US,en;q=0.9"
  auth = "Bearer AAAAAAAAAAAAAAAAAAAAAPYXBAAAAAAACLXUNDekMxqa8h%2F40K4moUkGsoc%3DTYfbDKbT3jJPCEVnMYqilB28NHfOPqkca3qaAxGfsyKCs0wRbw"
  accept = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3"
  jsonAccept = "application/json, text/javascript, */*; q=0.01"

  base = parseUri("https://twitter.com/")
  apiBase = parseUri("https://api.twitter.com/1.1/")

  timelineUrl = "i/profiles/show/$1/timeline/tweets"
  timelineSearchUrl = "i/search/timeline"
  timelineMediaUrl = "i/profiles/show/$1/media_timeline"
  profilePopupUrl = "i/profiles/popup"
  profileIntentUrl = "intent/user"
  tweetUrl = "status"
  videoUrl = "videos/tweet/config/$1.json"
  tokenUrl = "guest/activate.json"
  cardUrl = "i/cards/tfw/v1/$1"
  pollUrl = cardUrl & "?cardname=poll2choice_text_only&lang=en"

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
    proc `multi`(thread: Thread | Timeline; agent: string; token="") {.async.} =
      if thread == nil: return
      var `media` = thread.tweets.filterIt(it.`media`.isSome)
      when `token`:
        var gToken = token
        if gToken.len == 0: gToken = await getGuestToken(agent)
        await all(`media`.mapIt(`single`(it, token, agent)))
      else:
        await all(`media`.mapIt(`single`(it, agent)))

    proc `convo`(convo: Conversation; agent: string) {.async.} =
      var futs: seq[Future[void]]
      when `token`:
        var token = await getGuestToken(agent)
        futs.add `single`(convo.tweet, agent, token)
        futs.add `multi`(convo.before, agent, token=token)
        futs.add `multi`(convo.after, agent, token=token)
        futs.add convo.replies.mapIt(`multi`(it, agent, token=token))
      else:
        futs.add `single`(convo.tweet, agent)
        futs.add `multi`(convo.before, agent)
        futs.add `multi`(convo.after, agent)
        futs.add convo.replies.mapIt(`multi`(it, agent))
      await all(futs)

template newClient() {.dirty.} =
  var client = newAsyncHttpClient()
  defer: client.close()
  client.headers = headers

proc fetchHtml(url: Uri; headers: HttpHeaders; jsonKey = ""): Future[XmlNode] {.async.} =
  newClient()

  var resp = ""
  try:
    resp = await client.getContent($url)
  except:
    return nil

  if jsonKey.len > 0:
    let json = parseJson(resp)[jsonKey].str
    return parseHtml(json)
  else:
    return parseHtml(resp)

proc fetchJson(url: Uri; headers: HttpHeaders): Future[JsonNode] {.async.} =
  newClient()

  var resp = ""
  try:
    resp = await client.getContent($url)
    result = parseJson(resp)
  except:
    return nil

proc getGuestToken(agent: string; force=false): Future[string] {.async.} =
  if getTime() - tokenUpdated < tokenLifetime and
     not force and tokenUses < tokenMaxUses:
    return guestToken

  tokenUpdated = getTime()
  tokenUses = 0

  let headers = newHttpHeaders({
    "Accept": jsonAccept,
    "Referer": $base,
    "User-Agent": agent,
    "Authorization": auth
  })

  newClient()

  let
    url = apiBase / tokenUrl
    json = parseJson(await client.postContent($url))

  result = json["guest_token"].to(string)
  guestToken = result

proc getVideoFetch*(tweet: Tweet; agent, token: string) {.async.} =
  if tweet.video.isNone(): return

  let headers = newHttpHeaders({
    "Accept": jsonAccept,
    "Referer": $(base / getLink(tweet)),
    "User-Agent": agent,
    "Authorization": auth,
    "x-guest-token": token
  })

  let url = apiBase / (videoUrl % tweet.id)
  let json = await fetchJson(url, headers)

  if json == nil:
    if getTime() - tokenUpdated > initDuration(seconds=1):
      tokenUpdated = getTime()
      discard await getGuestToken(agent, force=true)
    await getVideoFetch(tweet, agent, guestToken)
    return

  if tweet.card.isNone:
    tweet.video = some(parseVideo(json, tweet.id))
  else:
    get(tweet.card).video = some(parseVideo(json, tweet.id))
    tweet.video = none(Video)
  tokenUses.inc

proc getVideoVar*(tweet: Tweet): var Option[Video] =
  if tweet.card.isSome():
    return get(tweet.card).video
  else:
    return tweet.video

proc getVideo*(tweet: Tweet; agent, token: string; force=false) {.async.} =
  withDb:
    try:
      getVideoVar(tweet) = some(Video.getOne("videoId = ?", tweet.id))
    except KeyError:
      await getVideoFetch(tweet, agent, token)
      var video = getVideoVar(tweet)
      if video.isSome():
        get(video).insert()

proc getPoll*(tweet: Tweet; agent: string) {.async.} =
  if tweet.poll.isNone(): return

  let headers = newHttpHeaders({
    "Accept": accept,
    "Referer": $(base / getLink(tweet)),
    "User-Agent": agent,
    "Authority": "twitter.com",
    "Accept-Language": lang,
  })

  let url = base / (pollUrl % tweet.id)
  let html = await fetchHtml(url, headers)
  if html == nil: return

  tweet.poll = some(parsePoll(html))

proc getCard*(tweet: Tweet; agent: string) {.async.} =
  if tweet.card.isNone(): return

  let headers = newHttpHeaders({
    "Accept": accept,
    "Referer": $(base / getLink(tweet)),
    "User-Agent": agent,
    "Authority": "twitter.com",
    "Accept-Language": lang,
  })

  let query = get(tweet.card).query.replace("sensitive=true", "sensitive=false")
  let html = await fetchHtml(base / query, headers)
  if html == nil: return

  parseCard(get(tweet.card), html)

genMediaGet(video, token=true)
genMediaGet(poll)
genMediaGet(card)

proc getPhotoRail*(username, agent: string): Future[seq[GalleryPhoto]] {.async.} =
  let headers = newHttpHeaders({
    "Accept": jsonAccept,
    "Referer": $(base / username),
    "User-Agent": agent,
    "X-Requested-With": "XMLHttpRequest"
  })

  let params = {
    "for_photo_rail": "true",
    "oldest_unread_id": "0"
  }

  let url = base / (timelineMediaUrl % username) ? params
  let html = await fetchHtml(url, headers, jsonKey="items_html")

  result = parsePhotoRail(html)

proc getProfileFallback(username: string; headers: HttpHeaders): Future[Profile] {.async.} =
  let url = base / profileIntentUrl ? {"screen_name": username}
  let html = await fetchHtml(url, headers)
  if html == nil: return Profile()

  result = parseIntentProfile(html)

proc getProfile*(username, agent: string): Future[Profile] {.async.} =
  let headers = newHttpHeaders({
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9",
    "Referer": $(base / username),
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": lang
  })

  let
    params = {
      "screen_name": username,
      "wants_hovercard": "true",
      "_": $(epochTime().int)
    }
    url = base / profilePopupUrl ? params
    html = await fetchHtml(url, headers, jsonKey="html")

  if html == nil: return Profile()

  if html.select(".ProfileCard-sensitiveWarningContainer") != nil:
    return await getProfileFallback(username, headers)

  result = parsePopupProfile(html)

proc getTweet*(username, id, agent: string): Future[Conversation] {.async.} =
  let headers = newHttpHeaders({
    "Accept": jsonAccept,
    "Referer": $base,
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": lang,
    "pragma": "no-cache",
    "x-previous-page-name": "profile"
  })

  let
    url = base / username / tweetUrl / id
    html = await fetchHtml(url, headers)

  if html == nil: return

  result = parseConversation(html)

  let
    vidsFut = getConversationVideos(result, agent)
    pollFut = getConversationPolls(result, agent)
    cardFut = getConversationCards(result, agent)

  await all(vidsFut, pollFut, cardFut)

proc finishTimeline(json: JsonNode; query: Option[Query]; after, agent: string): Future[Timeline] {.async.} =
  if json == nil: return Timeline()

  result = Timeline(
    hasMore: json["has_more_items"].to(bool),
    maxId: json.getOrDefault("max_position").getStr(""),
    minId: json.getOrDefault("min_position").getStr("").cleanPos(),
    query: query,
    beginning: after.len == 0
  )

  if json["new_latent_count"].to(int) == 0: return
  if not json.hasKey("items_html"): return

  let
    html = parseHtml(json["items_html"].to(string))
    thread = parseThread(html)
    vidsFut = getVideos(thread, agent)
    pollFut = getPolls(thread, agent)
    cardFut = getCards(thread, agent)

  await all(vidsFut, pollFut, cardFut)
  result.tweets = thread.tweets

proc getTimeline*(username, after, agent: string): Future[Timeline] {.async.} =
  let headers = newHttpHeaders({
    "Accept": jsonAccept,
    "Referer": $(base / username),
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": lang
  })

  var params = toSeq({
    "include_available_features": "1",
    "include_entities": "1",
    "include_new_items_bar": "false",
    "reset_error_state": "false"
  })

  if after.len > 0:
    params.add {"max_position": after}

  let json = await fetchJson(base / (timelineUrl % username) ? params, headers)
  result = await finishTimeline(json, none(Query), after, agent)

proc getTimelineSearch*(query: Query; after, agent: string): Future[Timeline] {.async.} =
  let queryParam = genQueryParam(query)
  let queryEncoded = encodeUrl(queryParam, usePlus=false)

  let headers = newHttpHeaders({
    "Accept": jsonAccept,
    "Referer": $(base / ("search?f=tweets&vertical=default&q=$1&src=typd" % queryEncoded)),
    "User-Agent": agent,
    "X-Requested-With": "XMLHttpRequest",
    "Authority": "twitter.com",
    "Accept-Language": lang
  })

  let params = {
    "f": "tweets",
    "vertical": "default",
    "q": queryParam,
    "src": "typd",
    "include_available_features": "1",
    "include_entities": "1",
    "max_position": if after.len > 0: genPos(after) else: "0",
    "reset_error_state": "false"
  }

  let json = await fetchJson(base / timelineSearchUrl ? params, headers)
  result = await finishTimeline(json, some(query), after, agent)

proc getProfileAndTimeline*(username, agent, after: string): Future[(Profile, Timeline)] {.async.} =
  let headers = newHttpHeaders({
    "authority": "twitter.com",
    "accept": accept,
    "referer": "https://twitter.com/" & username,
    "accept-language": lang
  })

  var url = base / username
  if after.len > 0:
    url = url ? {"max_position": after}

  let
    html = await fetchHtml(url, headers)
    timeline = parseTimeline(html.select("#timeline > .stream-container"), after)
    profile = parseTimelineProfile(html)

    vidsFut = getVideos(timeline, agent)
    pollFut = getPolls(timeline, agent)
    cardFut = getCards(timeline, agent)

  await all(vidsFut, pollFut, cardFut)
  result = (profile, timeline)

proc getProfileFull*(username: string): Future[Profile] {.async.} =
  let headers = newHttpHeaders({
    "authority": "twitter.com",
    "accept": accept,
    "referer": "https://twitter.com/" & username,
    "accept-language": lang
  })

  let html = await fetchHtml(base / username, headers)
  if html == nil: return
  result = parseTimelineProfile(html)
