import xmltree, strtabs, strformat, times
import nimquery, regex

import ./types, ./formatters, ./api

const
  thumbRegex = re".+:url\('([^']+)'\)"
  gifRegex = re".+thumb/([^\.']+)\.jpg.*"

proc getAttr*(node: XmlNode; attr: string; default=""): string =
  if node.isNil or node.attrs.isNil: return default
  return node.attrs.getOrDefault(attr)

proc selectAttr*(node: XmlNode; selector: string; attr: string; default=""): string =
  let res = node.querySelector(selector)
  if res == nil: "" else: res.getAttr(attr, default)

proc selectText*(node: XmlNode; selector: string): string =
  let res = node.querySelector(selector)
  result = if res == nil: "" else: res.innerText()

proc isVerified*(profile: XmlNode): bool =
  profile.selectText(".Icon.Icon--verified").len > 0

proc isProtected*(profile: XmlNode): bool =
  profile.selectText(".Icon.Icon--protected").len > 0

proc getName*(profile: XmlNode; selector: string): string =
  profile.selectText(selector).strip()

proc getUsername*(profile: XmlNode; selector: string): string =
  profile.selectText(selector).strip(chars={'@', ' '})

proc getTweetText*(tweet: XmlNode): string =
  let selector = ".tweet-text > a.twitter-timeline-link.u-hidden"
  let link = tweet.selectAttr(selector, "data-expanded-url")
  var text =tweet.selectText(".tweet-text")

  if link.len > 0 and link in text:
    text = text.replace(link, " " & link)

  stripTwitterUrls(text)

proc getTime(tweet: XmlNode): XmlNode =
  tweet.querySelector(".js-short-timestamp")

proc getTimestamp*(tweet: XmlNode): Time =
  let time = getTime(tweet).getAttr("data-time", "0")
  fromUnix(parseInt(time))

proc getShortTime*(tweet: XmlNode): string =
  getTime(tweet).innerText()

proc getBio*(profile: XmlNode; selector: string): string =
  profile.selectText(selector).strip()

proc getAvatar*(profile: XmlNode; selector: string): string =
  profile.selectAttr(selector, "src").getUserpic()

proc getBanner*(tweet: XmlNode): string =
  let url = tweet.selectAttr("svg > image", "xlink:href")

  if url.len > 0:
    result = url.replace("600x200", "1500x500")
  else:
    result = tweet.selectAttr(".ProfileCard-bg", "style")

  if result.len == 0:
    result = "background-color: #161616"

proc getPopupStats*(profile: var Profile; node: XmlNode) =
  for s in node.querySelectorAll( ".ProfileCardStats-statLink"):
    let text = s.getAttr("title").split(" ")[0]
    case s.getAttr("href").split("/")[^1]
    of "followers": profile.followers = text
    of "following": profile.following = text
    else: profile.tweets = text

proc getIntentStats*(profile: var Profile; node: XmlNode) =
  profile.tweets = "?"
  for s in node.querySelectorAll( "dd.count > a"):
    let text = s.innerText()
    case s.getAttr("href").split("/")[^1]
    of "followers": profile.followers = text
    of "following": profile.following = text

proc getTweetStats*(tweet: Tweet; node: XmlNode) =
  tweet.replies = "0"
  tweet.retweets = "0"
  tweet.likes = "0"
  for action in node.querySelectorAll(".ProfileTweet-actionCountForAria"):
    let text = action.innerText.split()
    case text[1]
    of "replies":  tweet.replies = text[0]
    of "likes":    tweet.likes = text[0]
    of "retweets": tweet.retweets = text[0]

proc getGif(player: XmlNode): Gif =
  let
    thumb = player.getAttr("style").replace(thumbRegex, "$1")
    id = thumb.replace(gifRegex, "$1")
    url = fmt"https://video.twimg.com/tweet_video/{id}.mp4"
  Gif(url: url, thumb: thumb)

proc getTweetMedia*(tweet: Tweet; node: XmlNode) =
  for photo in node.querySelectorAll(".AdaptiveMedia-photoContainer"):
    tweet.photos.add photo.attrs["data-image-url"]

  let player = node.querySelector(".PlayableMedia")
  if player.isNil:
    return

  if "gif" in player.getAttr("class"):
    tweet.gif = some(getGif(player.querySelector(".PlayableMedia-player")))
  elif "video" in player.getAttr("class"):
    tweet.video = some(Video())
