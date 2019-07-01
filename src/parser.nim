import xmltree, sequtils, strtabs, strutils, strformat, json

import ./types, ./parserutils, ./formatters

proc parsePopupProfile*(node: XmlNode): Profile =
  let profile = node.select(".profile-card")
  if profile == nil: return

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
    verified:  profile.select("li.verified") != nil,
    protected: profile.select("li.protected") != nil,
    banner:    getBanner(profile)
  )

  result.getIntentStats(profile)

proc parseTweetProfile*(profile: XmlNode): Profile =
  result = Profile(
    fullname: profile.attr("data-name").stripText(),
    username: profile.attr("data-screen-name"),
    userpic:  profile.getAvatar(".avatar"),
    verified: isVerified(profile)
  )

proc parseQuote*(quote: XmlNode): Quote =
  result = Quote(
    id:   quote.attr("data-item-id"),
    text: getQuoteText(quote)
  )

  result.profile = Profile(
    fullname: quote.selectText(".QuoteTweet-fullname").stripText(),
    username: quote.attr("data-screen-name"),
    verified: isVerified(quote)
  )

  result.getQuoteMedia(quote)

proc parseTweet*(node: XmlNode): Tweet =
  let tweet = node.select(".tweet")
  if tweet == nil: return Tweet()

  result = Tweet(
    id:        tweet.attr("data-item-id"),
    text:      getTweetText(tweet),
    time:      getTimestamp(tweet),
    shortTime: getShortTime(tweet),
    profile:   parseTweetProfile(tweet),
    pinned:    "pinned" in tweet.attr("class"),
    available: true
  )

  result.getTweetStats(tweet)
  result.getTweetMedia(tweet)
  result.getTweetCards(tweet)

  let by = tweet.selectText(".js-retweet-text > a > b")
  if by.len > 0:
    result.retweet = some(Retweet(
      by: stripText(by),
      id: tweet.attr("data-retweet-id")
    ))

  let quote = tweet.select(".QuoteTweet-innerContainer")
  if quote != nil:
    result.quote = some(parseQuote(quote))

proc parseThread*(nodes: XmlNode): Thread =
  if nodes == nil: return
  for n in nodes.filterIt(it.kind != xnText):
    let class = n.attr("class").toLower()
    if "tombstone" in class or "unavailable" in class:
      result.tweets.add Tweet()
    elif "morereplies" in class:
      result.more = getMoreReplies(n)
    else:
      result.tweets.add parseTweet(n)

proc parseConversation*(node: XmlNode): Conversation =
  result = Conversation(
    tweet:  parseTweet(node.select(".permalink-tweet-container")),
    before: parseThread(node.select(".in-reply-to .stream-items"))
  )

  let replies = node.select(".replies-to .stream-items")
  if replies == nil: return

  for reply in replies.filterIt(it.kind != xnText):
    let class = reply.attr("class").toLower()
    let thread = reply.select(".stream-items")

    if "self" in class:
      result.after = parseThread(thread)
    elif "lone" in class:
      result.replies.add parseThread(reply)
    else:
      result.replies.add parseThread(thread)

proc parseVideo*(node: JsonNode): Video =
  let
    track = node{"track"}
    cType = track["contentType"].to(string)
    pType = track["playbackType"].to(string)

  case cType
  of "media_entity":
    result = Video(
      playbackType: if "mp4" in pType: mp4 else: m3u8,
      contentId: track["contentId"].to(string),
      durationMs: track["durationMs"].to(int),
      views: track["viewCount"].to(string),
      url: track["playbackUrl"].to(string),
      available: track{"mediaAvailability"}["status"].to(string) == "available"
    )
  of "vmap":
    result = Video(
      playbackType: vmap,
      durationMs: track["durationMs"].to(int),
      url: track["vmapUrl"].to(string)
    )
  else:
    echo "Can't parse video of type ", cType

  result.thumb = node["posterImage"].to(string)

proc parsePoll*(node: XmlNode): Poll =
  let
    choices = node.selectAll(".PollXChoice-choice")
    votes = node.selectText(".PollXChoice-footer--total")

  result.votes = votes.strip().split(" ")[0]
  result.status = node.selectText(".PollXChoice-footer--time")

  for choice in choices:
    for span in choice.select(".PollXChoice-choice--text").filterIt(it.kind != xnText):
      if span.attr("class").len == 0:
        result.options.add span.innerText()
      elif "progress" in span.attr("class"):
        result.values.add parseInt(span.innerText()[0 .. ^2])

  var highest = 0
  for i, n in result.values:
    if n > highest:
      highest = n
      result.leader = i
