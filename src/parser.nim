import xmltree, sequtils, strtabs, strutils, strformat, json
import nimquery

import ./types, ./parserutils, ./formatters

proc parsePopupProfile*(node: XmlNode): Profile =
  let profile = node.querySelector(".profile-card")
  if profile.isNil: return

  result = Profile(
    fullname:  profile.getName(".fullname"),
    username:  profile.getUsername(".username"),
    bio:       profile.getBio(".bio"),
    userpic:   profile.getAvatar(".ProfileCard-avatarImage"),
    verified:  isVerified(profile),
    protected: isProtected(profile),
    banner:    getBanner(profile)
  )

  result.getPopupStats(profile)

proc parseIntentProfile*(profile: XmlNode): Profile =
  result = Profile(
    fullname:  profile.getName("a.fn.url.alternate-context"),
    username:  profile.getUsername(".nickname"),
    bio:       profile.getBio("p.note"),
    userpic:   profile.querySelector(".profile.summary").getAvatar("img.photo"),
    verified:  not profile.querySelector("li.verified").isNil,
    protected: not profile.querySelector("li.protected").isNil,
    banner:    getBanner(profile)
  )

  result.getIntentStats(profile)

proc parseTweetProfile*(profile: XmlNode): Profile =
  result = Profile(
    fullname: profile.getAttr("data-name").stripNbsp(),
    username: profile.getAttr("data-screen-name"),
    userpic:  profile.getAvatar(".avatar"),
    verified: isVerified(profile)
  )

proc parseQuote*(quote: XmlNode): Quote =
  result = Quote(
    id:   quote.getAttr("data-item-id"),
    link: quote.getAttr("href"),
    text: quote.selectText(".QuoteTweet-text").stripTwitterUrls()
  )

  result.profile = Profile(
    fullname: quote.selectText(".QuoteTweet-fullname").stripNbsp(),
    username: quote.getAttr("data-screen-name"),
    verified: isVerified(quote)
  )

  result.getQuoteMedia(quote)

proc parseTweet*(tweet: XmlNode): Tweet =
  result = Tweet(
    id:        tweet.getAttr("data-item-id"),
    link:      tweet.getAttr("data-permalink-path"),
    profile:   parseTweetProfile(tweet),
    text:      getTweetText(tweet),
    time:      getTimestamp(tweet),
    shortTime: getShortTime(tweet),
    pinned:    "pinned" in tweet.getAttr("class")
  )

  result.getTweetStats(tweet)
  result.getTweetMedia(tweet)

  let by = tweet.selectText(".js-retweet-text > a > b")
  if by.len > 0:
    result.retweetBy = some(by)
    result.retweetId = some(tweet.getAttr("data-retweet-id"))

  let quote = tweet.querySelector(".QuoteTweet-innerContainer")
  if not quote.isNil:
    result.quote = some(parseQuote(quote))

proc parseTweets*(node: XmlNode): Tweets =
  if node.isNil: return
  node.querySelectorAll(".tweet").map(parseTweet)

proc parseConversation*(node: XmlNode): Conversation =
  result = Conversation(
    tweet: parseTweet(node.querySelector(".permalink-tweet-container > .tweet")),
    before: parseTweets(node.querySelector(".in-reply-to"))
  )

  let replies = node.querySelector(".replies-to")
  if replies.isNil: return

  result.after = parseTweets(replies.querySelector(".ThreadedConversation--selfThread"))

  for reply in replies.querySelectorAll("li > .stream-items"):
    let thread = parseTweets(reply)
    if not thread.anyIt(it in result.after):
      result.replies.add thread

proc parseVideo*(node: JsonNode): Video =
  let track = node{"track"}
  result = Video(
    thumb: node["posterImage"].to(string),
    id: track["contentId"].to(string),
    length: track["durationMs"].to(int),
    views: track["viewCount"].to(string),
    url: track["playbackUrl"].to(string),
    available: track{"mediaAvailability"}["status"].to(string) == "available"
  )
