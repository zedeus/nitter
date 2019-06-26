import xmltree, sequtils, strtabs, strutils, strformat, json

import ./types, ./parserutils, ./formatters

proc parsePopupProfile*(node: XmlNode): Profile =
  let profile = node.select(".profile-card")
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
    userpic:   profile.select(".profile.summary").getAvatar("img.photo"),
    verified:  not profile.select("li.verified").isNil,
    protected: not profile.select("li.protected").isNil,
    banner:    getBanner(profile)
  )

  result.getIntentStats(profile)

proc parseTweetProfile*(profile: XmlNode): Profile =
  result = Profile(
    fullname: profile.getAttr("data-name").stripText(),
    username: profile.getAttr("data-screen-name"),
    userpic:  profile.getAvatar(".avatar"),
    verified: isVerified(profile)
  )

proc parseQuote*(quote: XmlNode): Quote =
  result = Quote(
    id:   quote.getAttr("data-item-id"),
    link: quote.getAttr("href"),
    text: getQuoteText(quote)
  )

  result.profile = Profile(
    fullname: quote.selectText(".QuoteTweet-fullname").stripText(),
    username: quote.getAttr("data-screen-name"),
    verified: isVerified(quote)
  )

  result.getQuoteMedia(quote)

proc parseTweet*(node: XmlNode): Tweet =
  let tweet = node.select(".tweet")
  if tweet.isNil():
    return Tweet()

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
    result.retweetBy = some(by.stripText())
    result.retweetId = some(tweet.getAttr("data-retweet-id"))

  let quote = tweet.select(".QuoteTweet-innerContainer")
  if not quote.isNil:
    result.quote = some(parseQuote(quote))

proc parseTweets*(node: XmlNode): Tweets =
  if node.isNil or node.kind == xnText: return
  node.selectAll(".stream-item").map(parseTweet)

proc parseConversation*(node: XmlNode): Conversation =
  result = Conversation(
    tweet:  parseTweet(node.select(".permalink-tweet-container")),
    before: parseTweets(node.select(".in-reply-to"))
  )

  let replies = node.select(".replies-to", ".stream-items")
  if replies.isNil: return

  for reply in replies.filterIt(it.kind != xnText):
    if "selfThread" in reply.attr("class"):
      result.after = parseTweets(reply.select(".stream-items"))
    else:
      result.replies.add parseTweets(reply)

proc parseVideo*(node: JsonNode): Video =
  let track = node{"track"}
  let contentType = track["contentType"].to(string)

  case contentType
  of "media_entity":
    result = Video(
      contentType: m3u8,
      thumb: node["posterImage"].to(string),
      id: track["contentId"].to(string),
      length: track["durationMs"].to(int),
      views: track["viewCount"].to(string),
      url: track["playbackUrl"].to(string),
      available: track{"mediaAvailability"}["status"].to(string) == "available"
    )
  of "vmap":
    result = Video(
      contentType: vmap,
      thumb: node["posterImage"].to(string),
      url: track["vmapUrl"].to(string),
      length: track["durationMs"].to(int),
    )
  else:
    echo "Can't parse video of type ", contentType
