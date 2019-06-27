import httpclient, asyncdispatch, htmlparser, times
import sequtils, strutils, strformat, json, xmltree, uri
import regex

import ./types, ./parser, ./parserutils

const
  agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36"
  auth = "Bearer AAAAAAAAAAAAAAAAAAAAAPYXBAAAAAAACLXUNDekMxqa8h%2F40K4moUkGsoc%3DTYfbDKbT3jJPCEVnMYqilB28NHfOPqkca3qaAxGfsyKCs0wRbw"

  base = parseUri("https://twitter.com/")
  apiBase = parseUri("https://api.twitter.com/1.1/")

  timelineParams = "?include_available_features=1&include_entities=1&include_new_items_bar=false&reset_error_state=false"
  showUrl = "i/profiles/show/$1" & timelineParams
  timelineUrl = showUrl % "$1/timeline/tweets"
  profilePopupUrl = "i/profiles/popup"
  profileIntentUrl = "intent/user"
  tweetUrl = "status"
  videoUrl = "videos/tweet/config/$1.json"
  tokenUrl = "guest/activate.json"

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
    "Accept": "application/json, text/javascript, */*; q=0.01",
    "Referer": $base,
    "User-Agent": agent,
    "Authorization": auth
  })

  newClient()

  let
    url = apibase / tokenUrl
    json = parseJson(await client.postContent($url))

  result = json["guest_token"].to(string)
  guestToken = result

proc getVideo*(tweet: Tweet; token: string) {.async.} =
  if tweet.video.isNone(): return

  let headers = newHttpHeaders({
    "Accept": "application/json, text/javascript, */*; q=0.01",
    "Referer": tweet.link,
    "User-Agent": agent,
    "Authorization": auth,
    "x-guest-token": token
  })

  let
    url = apiBase / (videoUrl % tweet.id)
    json = await fetchJson(url, headers)

  if json.isNil:
    if getTime() - tokenUpdated > initDuration(seconds=1):
      tokenUpdated = getTime()
      guestToken = await getGuestToken(force=true)
    await getVideo(tweet, guestToken)
    return

  tweet.video = some(parseVideo(json))
  tokenUses.inc

proc getVideos*(tweets: Tweets; token="") {.async.} =
  var gToken = token
  var videoFuts: seq[Future[void]]

  if gToken.len == 0:
    gToken = await getGuestToken()

  for tweet in tweets.filterIt(it.video.isSome):
    videoFuts.add getVideo(tweet, token)

  await all(videoFuts)

proc getConversationVideos*(convo: Conversation) {.async.} =
  var token = await getGuestToken()
  var futs: seq[Future[void]]

  futs.add getVideo(convo.tweet, token)
  futs.add getVideos(convo.before)
  futs.add getVideos(convo.after)
  futs.add convo.replies.mapIt(getVideos(it, token))

  await all(futs)

proc getProfileFallback(username: string; headers: HttpHeaders): Future[Profile] {.async.} =
  let
    url = base / profileIntentUrl ? {"screen_name": username}
    html = await fetchHtml(url, headers)

  if html.isNil:
    return Profile()

  result = parseIntentProfile(html)

proc getProfile*(username: string): Future[Profile] {.async.} =
  let headers = newHttpHeaders({
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9",
    "Referer": $(base / username),
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": "en-US,en;q=0.9"
  })

  let
    params = {
      "screen_name": username,
      "wants_hovercard": "true",
      "_": $(epochTime().int)
    }
    url = base / profilePopupUrl ? params
    html = await fetchHtml(url, headers, jsonKey="html")

  if html.isNil:
    return Profile()

  if not html.select(".ProfileCard-sensitiveWarningContainer").isNil:
    return await getProfileFallback(username, headers)

  result = parsePopupProfile(html)

proc getTimeline*(username: string; after=""): Future[Timeline] {.async.} =
  let headers = newHttpHeaders({
    "Accept": "application/json, text/javascript, */*; q=0.01",
    "Referer": $(base / username),
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": "en-US,en;q=0.9"
  })

  var url = timelineUrl % username
  let cleanAfter = after.replace(re"[^\d]*(\d+)[^\d]*", "$1")
  if cleanAfter.len > 0:
    url &= "&max_position=" & cleanAfter

  let json = await fetchJson(base / url, headers)
  if json.isNil: return Timeline()

  result = Timeline(
    hasMore: json["has_more_items"].to(bool),
    maxId: json.getOrDefault("max_position").getStr(""),
    minId: json.getOrDefault("min_position").getStr(""),
  )

  if json["new_latent_count"].to(int) == 0:
    return

  let html = parseHtml(json["items_html"].to(string))
  result.tweets = parseTweets(html)
  await getVideos(result.tweets)

proc getTweet*(username: string; id: string): Future[Conversation] {.async.} =
  let headers = newHttpHeaders({
    "Accept": "application/json, text/javascript, */*; q=0.01",
    "Referer": $base,
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": "en-US,en;q=0.9",
    "pragma": "no-cache",
    "x-previous-page-name": "profile"
  })

  let
    url = base / username / tweetUrl / id
    html = await fetchHtml(url, headers)

  if html.isNil:
    return

  result = parseConversation(html)
  await getConversationVideos(result)
