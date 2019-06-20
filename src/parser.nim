import xmltree, sequtils, strtabs, strutils, strformat, json, times
import nimquery, regex

import ./types, ./formatters

proc getAttr(node: XmlNode; attr: string; default=""): string =
  if node.isNIl or node.attrs.isNil: return default
  return node.attrs.getOrDefault(attr)

proc selectAttr(node: XmlNode; selector: string; attr: string; default=""): string =
  let res = node.querySelector(selector)
  if res == nil: "" else: res.getAttr(attr, default)

proc selectText(node: XmlNode; selector: string): string =
  let res = node.querySelector(selector)
  result = if res == nil: "" else: res.innerText()

proc parseProfile*(node: XmlNode): Profile =
  let profile = node.querySelector(".profile-card")
  result.fullname = profile.selectText(".fullname")
  result.username = profile.selectText(".username").strip(chars={'@', ' '})
  result.description = profile.selectText(".bio")
  result.verified = profile.selectText("li.verified").len > 0
  result.protected = profile.selectText(".Icon.Icon--protected").len > 0
  result.userpic = profile.selectAttr(".ProfileCard-avatarImage", "src").getUserpic()
  result.banner = profile.selectAttr("svg > image", "xlink:href").replace("600x200", "1500x500")
  if result.banner == "":
      result.banner = profile.selectAttr(".ProfileCard-bg", "style")

  let stats = profile.querySelectorAll(".ProfileCardStats-statLink")
  for s in stats:
    let text = s.getAttr("title").split(" ")[0]
    case s.getAttr("href").split("/")[^1]
    of "followers": result.followers = text
    of "following": result.following = text
    else: result.tweets = text

proc parseTweetProfile*(tweet: XmlNode): Profile =
  result = Profile(
    fullname: tweet.getAttr("data-name"),
    username: tweet.getAttr("data-screen-name"),
    userpic: tweet.selectAttr(".avatar", "src").getUserpic(),
    verified: tweet.selectText(".Icon.Icon--verified").len > 0
  )

proc parseTweet*(tweet: XmlNode): Tweet =
  result.id = tweet.getAttr("data-item-id")
  result.link = tweet.getAttr("data-permalink-path")
  result.text = tweet.selectText(".tweet-text").stripTwitterUrls()
  result.retweetBy = tweet.selectText(".js-retweet-text > a > b")
  result.pinned = "pinned" in tweet.getAttr("class")
  result.profile = parseTweetProfile(tweet)

  let time = tweet.querySelector(".js-short-timestamp")
  result.time = fromUnix(parseInt(time.getAttr("data-time", "0")))
  result.shortTime = time.innerText()

  result.replies = "0"
  result.likes = "0"
  result.retweets = "0"

  for action in tweet.querySelectorAll(".ProfileTweet-actionCountForAria"):
    let
      text = action.innerText.split()
      num = text[0]

    case text[1]
    of "replies": result.replies = num
    of "likes": result.likes = num
    of "retweets": result.retweets = num
    else: discard

  for photo in tweet.querySelectorAll(".AdaptiveMedia-photoContainer"):
    result.photos.add photo.attrs["data-image-url"]

  let player = tweet.selectAttr(".PlayableMedia-player", "style")
  if player.len > 0:
    let thumb = player.replace(re".+:url\('([^']+)'\)", "$1")
    if "tweet_video" in thumb:
      result.gif = thumb.replace(re".+thumb/([^\.']+)\.jpg.+", "$1")
    else:
      result.videoThumb = thumb

proc parseTweets*(node: XmlNode): Tweets =
  if node.isNil: return
  node.querySelectorAll(".tweet").map(parseTweet)

template selectTweets*(node: XmlNode; class: string): untyped =
  parseTweets(node.querySelector(class))

proc parseConversation*(node: XmlNode): Conversation =
  result.tweet = parseTweet(node.querySelector(".permalink-tweet-container > .tweet"))
  result.before = node.selectTweets(".in-reply-to")

  let replies = node.querySelector(".replies-to")
  if replies.isNil: return

  result.after = replies.selectTweets(".ThreadedConversation--selfThread")

  for reply in replies.querySelectorAll("li > .stream-items"):
    let thread = parseTweets(reply)
    if not thread.anyIt(it in result.after):
      result.replies.add thread
