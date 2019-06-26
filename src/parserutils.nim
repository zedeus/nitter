import xmltree, htmlparser, strtabs, strformat, times
import regex

import ./types, ./formatters, ./api

from q import nil

const
  thumbRegex = re".+:url\('([^']+)'\)"
  gifRegex = re".+thumb/([^\.']+)\.jpg.*"

proc selectAll*(node: XmlNode; selector: string): seq[XmlNode] =
  q.select(node, selector)

proc select*(node: XmlNode; selector: string): XmlNode =
  let nodes = node.selectAll(selector)
  if nodes.len > 0: nodes[0] else: nil

proc getAttr*(node: XmlNode; attr: string; default=""): string =
  if node.isNil or node.attrs.isNil: return default
  return node.attrs.getOrDefault(attr)

proc selectAttr*(node: XmlNode; selector: string; attr: string; default=""): string =
  let res = node.select(selector)
  if res == nil: "" else: res.getAttr(attr, default)

proc selectText*(node: XmlNode; selector: string): string =
  let res = node.select(selector)
  result = if res == nil: "" else: res.innerText()

proc getHeader(profile: XmlNode): XmlNode =
  result = profile.select(".permalink-header")
  if result.isNil:
    result = profile.select(".stream-item-header")
  if result.isNil:
    result = profile.select(".ProfileCard-userFields")

proc isVerified*(profile: XmlNode): bool =
  getHeader(profile).selectText(".Icon.Icon--verified").len > 0

proc isProtected*(profile: XmlNode): bool =
  getHeader(profile).selectText(".Icon.Icon--protected").len > 0

proc getName*(profile: XmlNode; selector: string): string =
  profile.selectText(selector).stripText()

proc getUsername*(profile: XmlNode; selector: string): string =
  profile.selectText(selector).strip(chars={'@', ' '})

proc emojify*(node: XmlNode) =
  for i in node.selectAll(".Emoji"):
    i.add newText(i.getAttr("alt"))

proc getQuoteText*(tweet: XmlNode): string =
  let text = tweet.select(".QuoteTweet-text")
  emojify(text)
  result = stripText(text.innerText())
  result = stripTwitterUrls(result)

proc getTweetText*(tweet: XmlNode): string =
  let
    quote = tweet.select(".QuoteTweet")
    text = tweet.select(".tweet-text")
    link = text.selectAttr("a.twitter-timeline-link.u-hidden", "data-expanded-url")

  emojify(text)
  result = stripText(text.innerText())

  if not quote.isNil and link.len > 0:
    result = result.replace(link, "")

  result = stripTwitterUrls(result)

proc getTime(tweet: XmlNode): XmlNode =
  tweet.select(".js-short-timestamp")

proc getTimestamp*(tweet: XmlNode): Time =
  let time = getTime(tweet).getAttr("data-time", "0")
  fromUnix(parseInt(time))

proc getShortTime*(tweet: XmlNode): string =
  getTime(tweet).innerText()

proc getBio*(profile: XmlNode; selector: string): string =
  profile.selectText(selector).stripText()

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
  for s in node.selectAll( ".ProfileCardStats-statLink"):
    let text = s.getAttr("title").split(" ")[0]
    case s.getAttr("href").split("/")[^1]
    of "followers": profile.followers = text
    of "following": profile.following = text
    else: profile.tweets = text

proc getIntentStats*(profile: var Profile; node: XmlNode) =
  profile.tweets = "?"
  for s in node.selectAll( "dd.count > a"):
    let text = s.innerText()
    case s.getAttr("href").split("/")[^1]
    of "followers": profile.followers = text
    of "following": profile.following = text

proc getTweetStats*(tweet: Tweet; node: XmlNode) =
  tweet.replies = "0"
  tweet.retweets = "0"
  tweet.likes = "0"
  for action in node.selectAll(".ProfileTweet-actionCountForAria"):
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
  for photo in node.selectAll(".AdaptiveMedia-photoContainer"):
    tweet.photos.add photo.attrs["data-image-url"]

  let player = node.select(".PlayableMedia")
  if player.isNil:
    return

  if "gif" in player.getAttr("class"):
    tweet.gif = some(getGif(player.select(".PlayableMedia-player")))
  elif "video" in player.getAttr("class"):
    tweet.video = some(Video())

proc getQuoteMedia*(quote: var Quote; node: XmlNode) =
  let sensitive = node.select(".QuoteTweet--sensitive")
  if not sensitive.isNil:
    quote.sensitive = true
    return

  let media = node.select(".QuoteMedia")
  if not media.isNil:
    quote.thumb = some(media.selectAttr("img", "src"))

  let badge = node.select(".AdaptiveMedia-badgeText")
  let gifBadge = node.select(".Icon--gifBadge")

  if not badge.isNil:
    quote.badge = some(badge.innerText())
  elif not gifBadge.isNil:
    quote.badge = some("GIF")
