import xmltree, htmlparser, strtabs, strformat, times
import regex

import ./types, ./formatters, ./api

from q import nil

const
  thumbRegex = re".+:url\('([^']+)'\)"
  gifRegex = re".+thumb/([^\.']+)\.jpg.*"

proc selectAll*(node: XmlNode; selector: string): seq[XmlNode] =
  if node == nil: return
  q.select(node, selector)

proc select*(node: XmlNode; selector: string): XmlNode =
  if node == nil: return
  let nodes = node.selectAll(selector)
  if nodes.len > 0: nodes[0] else: nil

proc selectAttr*(node: XmlNode; selector: string; attr: string): string =
  let res = node.select(selector)
  if res == nil: "" else: res.attr(attr)

proc selectText*(node: XmlNode; selector: string): string =
  let res = node.select(selector)
  result = if res == nil: "" else: res.innerText()

proc getHeader(profile: XmlNode): XmlNode =
  result = profile.select(".permalink-header")
  if result == nil:
    result = profile.select(".stream-item-header")
  if result == nil:
    result = profile.select(".ProfileCard-userFields")

proc isVerified*(profile: XmlNode): bool =
  getHeader(profile).select(".Icon.Icon--verified") != nil

proc isProtected*(profile: XmlNode): bool =
  getHeader(profile).select(".Icon.Icon--protected") != nil

proc getName*(profile: XmlNode; selector: string): string =
  profile.selectText(selector).stripText()

proc getUsername*(profile: XmlNode; selector: string): string =
  profile.selectText(selector).strip(chars={'@', ' '})

proc emojify*(node: XmlNode) =
  for i in node.selectAll(".Emoji"):
    i.add newText(i.attr("alt"))

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

  if quote != nil and link.len > 0:
    result = result.replace(link, "")

  result = stripTwitterUrls(result)

proc getTime(tweet: XmlNode): XmlNode =
  tweet.select(".js-short-timestamp")

proc getTimestamp*(tweet: XmlNode): Time =
  let time = getTime(tweet).attr("data-time")
  fromUnix(if time.len > 0: parseInt(time) else: 0)

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
    let text = s.attr("title").split(" ")[0]
    case s.attr("href").split("/")[^1]
    of "followers": profile.followers = text
    of "following": profile.following = text
    else: profile.tweets = text

proc getIntentStats*(profile: var Profile; node: XmlNode) =
  profile.tweets = "?"
  for s in node.selectAll( "dd.count > a"):
    let text = s.innerText()
    case s.attr("href").split("/")[^1]
    of "followers": profile.followers = text
    of "following": profile.following = text

proc parseTweetStats*(node: XmlNode): TweetStats =
  result = TweetStats(replies: "0", retweets: "0", likes: "0")
  for action in node.selectAll(".ProfileTweet-actionCountForAria"):
    let text = action.innerText.split()
    case text[1][0 .. 2]
    of "ret": result.retweets = text[0]
    of "rep": result.replies = text[0]
    of "lik": result.likes = text[0]

proc parseTweetReply*(node: XmlNode): seq[string] =
  let reply = node.select(".ReplyingToContextBelowAuthor")
  if reply == nil: return
  for username in reply.selectAll("a"):
    result.add username.selectText("b")

proc getGif(player: XmlNode): Gif =
  let
    thumb = player.attr("style").replace(thumbRegex, "$1")
    id = thumb.replace(gifRegex, "$1")
    url = &"https://video.twimg.com/tweet_video/{id}.mp4"
  Gif(url: url, thumb: thumb)

proc getTweetMedia*(tweet: Tweet; node: XmlNode) =
  for photo in node.selectAll(".AdaptiveMedia-photoContainer"):
    tweet.photos.add photo.attrs["data-image-url"]

  let player = node.select(".PlayableMedia")
  if player == nil: return

  if "gif" in player.attr("class"):
    tweet.gif = some(getGif(player.select(".PlayableMedia-player")))
  elif "video" in player.attr("class"):
    tweet.video = some(Video())

proc getQuoteMedia*(quote: var Quote; node: XmlNode) =
  if node.select(".QuoteTweet--sensitive") != nil:
    quote.sensitive = true
    return

  let media = node.select(".QuoteMedia")
  if media != nil:
    quote.thumb = media.selectAttr("img", "src")

  let badge = node.select(".AdaptiveMedia-badgeText")
  let gifBadge = node.select(".Icon--gifBadge")

  if badge != nil:
    quote.badge = badge.innerText()
  elif gifBadge != nil:
    quote.badge = "GIF"

proc getTweetCards*(tweet: Tweet; node: XmlNode) =
  if node.attr("data-has-cards") == "false": return
  if "poll" in node.attr("data-card2-type"):
    tweet.poll = some(Poll())

proc getMoreReplies*(node: XmlNode): int =
  let text = node.innerText().strip()
  try:
    result = parseInt(text.split(" ")[0])
  except:
    result = -1
