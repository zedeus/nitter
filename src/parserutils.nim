import xmltree, strtabs, strformat, strutils, times, uri
import regex

import types, formatters

from q import nil
from htmlgen import a

const
  thumbRegex = re".+:url\('([^']+)'\)"
  gifRegex = re".+thumb/([^\.']+)\.[jpng].*"

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
  if result == nil:
    result = profile

proc isVerified*(profile: XmlNode): bool =
  getHeader(profile).select(".Icon.Icon--verified") != nil

proc isProtected*(profile: XmlNode): bool =
  getHeader(profile).select(".Icon.Icon--protected") != nil

proc parseText*(text: XmlNode; skipLink=""): string =
  if text == nil: return
  for el in text:
    case el.kind
    of xnText:
      result.add el
    of xnElement:
      if el.attrs == nil:
        if el.tag == "strong":
          result.add $el
        continue

      let class = el.attr("class")
      if "data-expanded-url" in el.attrs:
        let url = el.attr("data-expanded-url")
        if url == skipLink: continue
        if "u-hidden" in class and result.len > 0:
          result.add "\n"
        result.add a(shortLink(url), href=url)
      elif "ashtag" in class or "hashflag" in class:
        let hash = el.innerText()
        result.add a(hash, href=("/search?q=" & encodeUrl(hash)))
      elif "atreply" in class:
        result.add a(el.innerText(), href=el.attr("href"))
      elif "Emoji" in class:
        result.add el.attr("alt")
    else: discard

proc getQuoteText*(tweet: XmlNode): string =
  parseText(tweet.select(".QuoteTweet-text"))

proc getTweetText*(tweet: XmlNode): string =
  let
    quote = tweet.select(".QuoteTweet")
    text = tweet.select(".tweet-text")
    link = text.selectAttr("a.twitter-timeline-link.u-hidden", "data-expanded-url")
  parseText(text, if quote != nil: link else: "")

proc getTime(tweet: XmlNode): XmlNode =
  tweet.select(".js-short-timestamp")

proc getTimestamp*(tweet: XmlNode): Time =
  let time = getTime(tweet).attr("data-time")
  fromUnix(if time.len > 0: parseInt(time) else: 0)

proc getShortTime*(tweet: XmlNode): string =
  getTime(tweet).innerText()

proc getDate*(node: XmlNode; selector: string): Time =
  let date = node.select(selector)
  if date == nil: return
  parseTime(date.attr("title"), "h:mm tt - d MMM YYYY", utc())

proc getName*(profile: XmlNode; selector: string): string =
  profile.selectText(selector).stripText()

proc getUsername*(profile: XmlNode; selector: string): string =
  profile.selectText(selector).strip(chars={'@', ' ', '\n'})

proc getBio*(profile: XmlNode; selector: string; fallback=""): string =
  var bio = profile.select(selector)
  if bio == nil and fallback.len > 0:
    bio = profile.select(fallback)
  parseText(bio)

proc getLocation*(profile: XmlNode): string =
  let sel = ".ProfileHeaderCard-locationText"
  result = profile.selectText(sel).stripText()

  let link = profile.selectAttr(sel & " a", "data-place-id")
  if link.len > 0:
    result &= ":" & link

proc getAvatar*(profile: XmlNode; selector: string): string =
  profile.selectAttr(selector, "src").getUserpic()

proc getBanner*(node: XmlNode): string =
  let url = node.selectAttr("svg > image", "xlink:href")
  if url.len > 0:
    result = url.replace("600x200", "1500x500")
  else:
    result = node.selectAttr(".ProfileCard-bg", "style")
    result = result.replace("background-color: ", "")

  if result.len == 0:
    result = "#161616"

proc getTimelineBanner*(node: XmlNode): string =
  let banner = node.select(".ProfileCanopy-headerBg img")
  let img = banner.attr("src")
  if img.len > 0:
    return img

  let style = node.select("style").innerText()
  var m: RegexMatch
  if style.find(re"a:active \{\n +color: (#[A-Z0-9]+)", m):
    return style[m.group(0)[0]]

proc getMediaCount*(node: XmlNode): string =
  let text = node.selectText(".PhotoRail-headingWithCount")
  return text.stripText().split(" ")[0]

proc getProfileStats*(profile: var Profile; node: XmlNode) =
  for s in node.selectAll( ".ProfileNav-stat"):
    let text = s.attr("title").split(" ")[0]
    case s.attr("data-nav")
    of "followers": profile.followers = text
    of "following": profile.following = text
    of "favorites": profile.likes = text
    of "tweets": profile.tweets = text

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

  let selector = if "Quote" in node.attr("class"): "b"
                 else: "a b"

  for username in reply.selectAll(selector):
    result.add username.innerText()

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
    tweet.gif = some getGif(player.select(".PlayableMedia-player"))
  elif "video" in player.attr("class"):
    tweet.video = some Video()

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

proc getTweetCard*(tweet: Tweet; node: XmlNode) =
  if node.attr("data-has-cards") == "false": return
  var cardType = node.attr("data-card2-type")

  if ":" in cardType:
    cardType = cardType.split(":")[^1]

  if "poll" in cardType:
    tweet.poll = some Poll()
    return

  if "message_me" in cardType:
    return

  let cardDiv = node.select(".card2 > .js-macaw-cards-iframe-container")
  if cardDiv == nil: return

  var card = Card(
    id: $tweet.id,
    query: cardDiv.attr("data-src")
  )

  try:
    card.kind = parseEnum[CardKind](cardType)
  except ValueError:
    card.kind = summary

  let cardUrl = cardDiv.attr("data-card-url")
  for n in node.selectAll(".tweet-text a"):
    if n.attr("href") == cardUrl:
      card.url = n.attr("data-expanded-url")

  tweet.card = some card

proc getMoreReplies*(node: XmlNode): int =
  let text = node.innerText().strip()
  try:
    result = parseInt(text.split(" ")[0])
  except:
    result = -1
