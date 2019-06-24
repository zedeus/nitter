import xmltree, sequtils, strtabs, strutils, strformat, json
import nimquery

import ./types, ./parserutils

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
    fullname: profile.getAttr("data-name"),
    username: profile.getAttr("data-screen-name"),
    userpic:  profile.getAvatar(".avatar"),
    verified: isVerified(profile)
  )

proc parseQuote*(tweet: XmlNode): Tweet =
  let tweet = tweet.querySelector(".QuoteTweet-innerContainer")
  result = Tweet(
    id:   tweet.getAttr("data-item-id"),
    link: tweet.getAttr("href"),
    text: tweet.selectText(".QuoteTweet-text")
  )

  result.profile = Profile(
    fullname: tweet.getAttr("data-screen-name"),
    username: tweet.selectText(".QuteTweet-fullname"),
    verified: isVerified(tweet)
  )

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
