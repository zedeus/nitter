import httpclient, asyncdispatch, htmlparser, times
import sequtils, strutils, strformat, json, xmltree, uri
import nimquery, regex

import ./types, ./parser

const
  agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36"
  auth = "Bearer AAAAAAAAAAAAAAAAAAAAAPYXBAAAAAAACLXUNDekMxqa8h%2F40K4moUkGsoc%3DTYfbDKbT3jJPCEVnMYqilB28NHfOPqkca3qaAxGfsyKCs0wRbw"

  base = parseUri("https://twitter.com/")
  apiBase = parseUri("https://api.twitter.com/1.1/")

  timelineUrl = "i/profiles/show/$1/timeline/tweets?include_available_features=1&include_entities=1&include_new_items_bar=true"
  profilePopupUrl = "i/profiles/popup"
  profileIntentUrl = "intent/user"
  tweetUrl = "i/status/"
  videoUrl = "videos/tweet/config/$1.json"
  tokenUrl = "guest/activate.json"

var
  token = ""
  tokenUpdated: Time
  tokenLifetime = initDuration(hours=2)

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
  except:
    return nil

  return parseJson(resp)

proc getGuestToken(): Future[string] {.async.} =
  if getTime() - tokenUpdated < tokenLifetime:
    return token

  tokenUpdated = getTime()

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
  token = result

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

  tweet.video = some(parseVideo(json))

proc getVideos*(tweets: Tweets) {.async.} =
  var token = await getGuestToken()
  var videoFuts: seq[Future[void]]

  for tweet in tweets.filterIt(it.video.isSome):
    videoFuts.add getVideo(tweet, token)

  await all(videoFuts)

proc getConversationVideos*(convo: Conversation) {.async.} =
  var token = await getGuestToken()
  var futs: seq[Future[void]]

  futs.add getVideo(convo.tweet, token)
  futs.add getVideos(convo.before)
  futs.add getVideos(convo.after)
  futs.add convo.replies.mapIt(getVideos(it))

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

  if not html.querySelector(".ProfileCard-sensitiveWarningContainer").isNil:
    return await getProfileFallback(username, headers)

  result = parsePopupProfile(html)

proc getTimeline*(username: string; after=""): Future[Tweets] {.async.} =
  let headers = newHttpHeaders({
    "Accept": "application/json, text/javascript, */*; q=0.01",
    "Referer": $(base / username),
    "User-Agent": agent,
    "X-Twitter-Active-User": "yes",
    "X-Requested-With": "XMLHttpRequest",
    "Accept-Language": "en-US,en;q=0.9"
  })

  var url = timelineUrl % username
  if after.len > 0:
    url &= "&max_position=" & after

  let html = await fetchHtml(base / url, headers, jsonKey="items_html")

  result = parseTweets(html)
  await getVideos(result)

proc getTweet*(id: string): Future[Conversation] {.async.} =
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
    url = base / tweetUrl / id
    html = await fetchHtml(url, headers)

  result = parseConversation(html)
  await getConversationVideos(result)
