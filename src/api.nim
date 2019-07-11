import httpclient, asyncdispatch, htmlparser, times
import sequtils, strutils, json, xmltree, uri

import types, parser, parserutils, formatters, search

const
  agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36"
  lang = "en-US,en;q=0.9"
  auth = "Bearer AAAAAAAAAAAAAAAAAAAAAPYXBAAAAAAACLXUNDekMxqa8h%2F40K4moUkGsoc%3DTYfbDKbT3jJPCEVnMYqilB28NHfOPqkca3qaAxGfsyKCs0wRbw"
  cardAccept = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3"
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

proc getGuestToken(force=false): Future[string] {.async.} =
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

proc getVideo*(tweet: Tweet; token: string) {.async.} =
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
      discard await getGuestToken(force=true)
    await getVideo(tweet, guestToken)
    return

  tweet.video = some(parseVideo(json))
  tokenUses.inc

proc getVideos*(thread: Thread; token="") {.async.} =
  if thread == nil: return

  var gToken = token
  if gToken.len == 0:
    gToken = await getGuestToken()

  var videoFuts: seq[Future[void]]
  for tweet in thread.tweets.filterIt(it.video.isSome):
    videoFuts.add getVideo(tweet, gToken)

  await all(videoFuts)

proc getConversationVideos*(convo: Conversation) {.async.} =
  var token = await getGuestToken()
  var futs: seq[Future[void]]

  futs.add getVideo(convo.tweet, token)
  futs.add convo.replies.mapIt(getVideos(it, token))
  futs.add getVideos(convo.before, token)
  futs.add getVideos(convo.after, token)

  await all(futs)

proc getPoll*(tweet: Tweet) {.async.} =
  if tweet.poll.isNone(): return

  let headers = newHttpHeaders({
    "Accept": cardAccept,
    "Referer": $(base / getLink(tweet)),
    "User-Agent": agent,
    "Authority": "twitter.com",
    "Accept-Language": lang,
  })

  let url = base / (pollUrl % tweet.id)
  let html = await fetchHtml(url, headers)
  if html == nil: return

  tweet.poll = some(parsePoll(html))

proc getPolls*(thread: Thread) {.async.} =
  if thread == nil: return
  var polls = thread.tweets.filterIt(it.poll.isSome)
  await all(polls.map(getPoll))

proc getConversationPolls*(convo: Conversation) {.async.} =
  var futs: seq[Future[void]]
  futs.add getPoll(convo.tweet)
  futs.add getPolls(convo.before)
  futs.add getPolls(convo.after)
  futs.add convo.replies.map(getPolls)
  await all(futs)

proc getCard*(tweet: Tweet) {.async.} =
  if tweet.card.isNone(): return

  let headers = newHttpHeaders({
    "Accept": cardAccept,
    "Referer": $(base / getLink(tweet)),
    "User-Agent": agent,
    "Authority": "twitter.com",
    "Accept-Language": lang,
  })

  let url = base / get(tweet.card).query
  let html = await fetchHtml(url, headers)
  if html == nil: return

  parseCard(get(tweet.card), html)
  # echo tweet.card.get()

proc getCards*(thread: Thread) {.async.} =
  if thread == nil: return
  var cards = thread.tweets.filterIt(it.card.isSome)
  await all(cards.map(getCard))

proc getConversationCards*(convo: Conversation) {.async.} =
  var futs: seq[Future[void]]
  futs.add getCard(convo.tweet)
  futs.add getCards(convo.before)
  futs.add getCards(convo.after)
  futs.add convo.replies.map(getCards)
  await all(futs)

proc getPhotoRail*(username: string): Future[seq[GalleryPhoto]] {.async.} =
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

proc getProfile*(username: string): Future[Profile] {.async.} =
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

proc getTweet*(username, id: string): Future[Conversation] {.async.} =
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
    vidsFut = getConversationVideos(result)
    pollFut = getConversationPolls(result)
    cardFut = getConversationCards(result)

  await all(vidsFut, pollFut, cardFut)

proc finishTimeline(json: JsonNode; query: Option[Query]; after: string): Future[Timeline] {.async.} =
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
    vidsFut = getVideos(thread)
    pollFut = getPolls(thread)
    cardFut = getCards(thread)

  await all(vidsFut, pollFut, cardFut)
  result.tweets = thread.tweets

proc getTimeline*(username, after: string): Future[Timeline] {.async.} =
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
  result = await finishTimeline(json, none(Query), after)

proc getTimelineSearch*(username, after: string; query: Query): Future[Timeline] {.async.} =
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
  result = await finishTimeline(json, some(query), after)
