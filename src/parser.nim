import xmltree, sequtils, strtabs, strutils, strformat, json, times
import nimquery, regex

import ./types, ./formatters

proc getAttr(node: XmlNode; attr: string; default=""): string =
  if node.isNil or node.attrs.isNil: return default
  return node.attrs.getOrDefault(attr)

proc selectAttr(node: XmlNode; selector: string; attr: string; default=""): string =
  let res = node.querySelector(selector)
  if res == nil: "" else: res.getAttr(attr, default)

proc selectText(node: XmlNode; selector: string): string =
  let res = node.querySelector(selector)
  result = if res == nil: "" else: res.innerText()

proc parsePopupProfile*(node: XmlNode): Profile =
  let profile = node.querySelector(".profile-card")
  if profile.isNil: return

  result = Profile(
     fullname: profile.selectText(".fullname").strip(),
     username: profile.selectText(".username").strip(chars={'@', ' '}),
     description: profile.selectText(".bio"),
     verified: profile.selectText(".Icon.Icon--verified").len > 0,
     protected: profile.selectText(".Icon.Icon--protected").len > 0,
     userpic: profile.selectAttr(".ProfileCard-avatarImage", "src").getUserpic(),
     banner: profile.selectAttr("svg > image", "xlink:href").replace("600x200", "1500x500")
  )

  if result.banner.len == 0:
      result.banner = profile.selectAttr(".ProfileCard-bg", "style")

  let stats = profile.querySelectorAll(".ProfileCardStats-statLink")
  for s in stats:
    let text = s.getAttr("title").split(" ")[0]
    case s.getAttr("href").split("/")[^1]
    of "followers": result.followers = text
    of "following": result.following = text
    else: result.tweets = text

proc parseIntentProfile*(profile: XmlNode): Profile =
  result = Profile(
    fullname: profile.selectText("a.fn.url.alternate-context").strip(),
    username: profile.selectText(".nickname").strip(chars={'@', ' '}),
    userpic: profile.querySelector(".profile.summary").selectAttr("img.photo", "src").getUserPic(),
    description: profile.selectText("p.note").strip(),
    verified: not profile.querySelector("li.verified").isNil,
    protected: not profile.querySelector("li.protected").isNil,
    banner: "background-color: #161616",
    tweets: "?"
  )

  for stat in profile.querySelectorAll("dd.count > a"):
    case stat.getAttr("href").split("/")[^1]
    of "followers": result.followers = stat.innerText()
    of "following": result.following = stat.innerText()

proc parseTweetProfile*(profile: XmlNode): Profile =
  result = Profile(
    fullname: profile.getAttr("data-name"),
    username: profile.getAttr("data-screen-name"),
    userpic: profile.selectAttr(".avatar", "src").getUserpic(),
    verified: profile.selectText(".Icon.Icon--verified").len > 0
  )

proc parseTweet*(tweet: XmlNode): Tweet =
  let time = tweet.querySelector(".js-short-timestamp")
  result = Tweet(
    id: tweet.getAttr("data-item-id"),
    link: tweet.getAttr("data-permalink-path"),
    text: tweet.selectText(".tweet-text").stripTwitterUrls(),
    pinned: "pinned" in tweet.getAttr("class"),
    profile: parseTweetProfile(tweet),
    time: fromUnix(parseInt(time.getAttr("data-time", "0"))),
    shortTime: time.innerText(),
    replies: "0",
    likes: "0",
    retweets: "0"
  )

  for action in tweet.querySelectorAll(".ProfileTweet-actionCountForAria"):
    let text = action.innerText.split()
    case text[1]
    of "replies": result.replies = text[0]
    of "likes": result.likes = text[0]
    of "retweets": result.retweets = text[0]
    else: discard

  for photo in tweet.querySelectorAll(".AdaptiveMedia-photoContainer"):
    result.photos.add photo.attrs["data-image-url"]

  let player = tweet.selectAttr(".PlayableMedia-player", "style")
  if player.len > 0:
    let thumb = player.replace(re".+:url\('([^']+)'\)", "$1")
    if "tweet_video" in thumb:
      result.gif = some(thumb.replace(re".+thumb/([^\.']+)\.jpg.*", "$1"))
    else:
      result.videoThumb = some(thumb)

  let by = tweet.selectText(".js-retweet-text > a > b")
  if by.len > 0:
    result.retweetBy = some(by)

proc parseTweets*(node: XmlNode): Tweets =
  if node.isNil: return
  node.querySelectorAll(".tweet").map(parseTweet)

proc parseConversation*(node: XmlNode): Conversation =
  result.tweet = parseTweet(node.querySelector(".permalink-tweet-container > .tweet"))
  result.before = parseTweets(node.querySelector(".in-reply-to"))

  let replies = node.querySelector(".replies-to")
  if replies.isNil: return

  result.after = parseTweets(replies.querySelector(".ThreadedConversation--selfThread"))

  for reply in replies.querySelectorAll("li > .stream-items"):
    let thread = parseTweets(reply)
    if not thread.anyIt(it in result.after):
      result.replies.add thread
