import xmltree, sequtils, strutils, json, options

import types, parserutils, formatters

proc parseTimelineProfile*(node: XmlNode): Profile =
  let profile = node.select(".ProfileHeaderCard")
  if profile == nil: return

  let pre = ".ProfileHeaderCard-"
  result = Profile(
    fullname:  profile.getName(pre & "nameLink"),
    username:  profile.getUsername(pre & "screenname"),
    joinDate:  profile.getDate(pre & "joinDateText"),
    website:   profile.selectAttr(pre & "urlText a", "title"),
    bio:       profile.getBio(pre & "bio"),
    location:  getLocation(profile),
    userpic:   node.getAvatar(".profile-picture img"),
    verified:  isVerified(profile),
    protected: isProtected(profile),
    banner:    getTimelineBanner(node),
    media:     getMediaCount(node)
  )

  result.getProfileStats(node.select(".ProfileNav-list"))

proc parsePopupProfile*(node: XmlNode; selector=".profile-card"): Profile =
  let profile = node.select(selector)
  if profile == nil: return

  result = Profile(
    fullname:  profile.getName(".fullname"),
    username:  profile.getUsername(".username"),
    bio:       profile.getBio(".bio", fallback=".ProfileCard-bio"),
    userpic:   profile.getAvatar(".ProfileCard-avatarImage"),
    verified:  isVerified(profile),
    protected: isProtected(profile),
    banner:    getBanner(profile)
  )

  result.getPopupStats(profile)

proc parseListProfile*(profile: XmlNode): Profile =
  result = Profile(
    fullname:  profile.getName(".fullname"),
    username:  profile.getUsername(".username"),
    bio:       profile.getBio(".bio").stripText(),
    userpic:   profile.getAvatar(".avatar"),
    verified:  isVerified(profile),
    protected: isProtected(profile),
  )

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
    id:    parseInt(quote.attr("data-item-id")),
    text:  getQuoteText(quote),
    reply: parseTweetReply(quote),
    hasThread: quote.select(".self-thread-context") != nil,
    available: true
  )

  result.profile = Profile(
    fullname: quote.selectText(".QuoteTweet-fullname").stripText(),
    username: quote.attr("data-screen-name"),
    verified: isVerified(quote)
  )

  result.getQuoteMedia(quote)

proc parseTweet*(node: XmlNode): Tweet =
  if node == nil:
    return Tweet()

  if "withheld" in node.attr("class"):
    return Tweet(tombstone: getTombstone(node.selectText(".Tombstone-label")))

  let tweet = node.select(".tweet")
  if tweet == nil:
    return Tweet()

  result = Tweet(
    id:        parseInt(tweet.attr("data-item-id")),
    threadId:  parseInt(tweet.attr("data-conversation-id")),
    text:      getTweetText(tweet),
    time:      getTimestamp(tweet),
    shortTime: getShortTime(tweet),
    profile:   parseTweetProfile(tweet),
    stats:     parseTweetStats(tweet),
    reply:     parseTweetReply(tweet),
    hasThread: tweet.select(".content > .self-thread-context") != nil,
    pinned:    "pinned" in tweet.attr("class"),
    available: true
  )

  result.getTweetMedia(tweet)
  result.getTweetCard(tweet)

  let by = tweet.selectText(".js-retweet-text > a > b")
  if by.len > 0:
    result.retweet = some Retweet(
      by: stripText(by),
      id: parseInt(tweet.attr("data-retweet-id"))
    )

  let quote = tweet.select(".QuoteTweet-innerContainer")
  if quote != nil:
    result.quote = some parseQuote(quote)

  let tombstone = tweet.select(".Tombstone")
  if tombstone != nil:
    if "unavailable" in tombstone.innerText():
      let quote = Quote(tombstone: getTombstone(node.selectText(".Tombstone-label")))
      result.quote = some quote

proc parseChain*(nodes: XmlNode): Chain =
  if nodes == nil: return
  result = Chain()
  for n in nodes.filterIt(it.kind != xnText):
    let class = n.attr("class").toLower()
    if "tombstone" in class or "unavailable" in class or "withheld" in class:
      result.content.add Tweet()
    elif "morereplies" in class:
      result.more = getMoreReplies(n)
    else:
      result.content.add parseTweet(n)

proc parseConversation*(node: XmlNode; after: string): Conversation =
  let tweet = node.select(".permalink-tweet-container")

  if tweet == nil:
    return Conversation(tweet: parseTweet(node.select(".permalink-tweet-withheld")))

  result = Conversation(
    tweet:  parseTweet(tweet),
    before: parseChain(node.select(".in-reply-to .stream-items")),
    replies: Result[Chain](
      minId: node.selectAttr(".replies-to .stream-container", "data-min-position"),
      hasMore: node.select(".stream-footer .has-more-items") != nil,
      beginning: after.len == 0
    )
  )

  let showMore = node.selectAttr(".ThreadedConversation-showMoreThreads button",
                                 "data-cursor")

  if showMore.len > 0:
    result.replies.minId = showMore
    result.replies.hasMore = true

  let replies = node.select(".replies-to .stream-items")
  if replies == nil: return

  for i, reply in replies.filterIt(it.kind != xnText):
    let class = reply.attr("class").toLower()
    let thread = reply.select(".stream-items")

    if i == 0 and "self" in class:
      result.after = parseChain(thread)
    elif "lone" in class:
      result.replies.content.add parseChain(reply)
    else:
      result.replies.content.add parseChain(thread)

proc parseTimeline*(node: XmlNode; after: string): Timeline =
  if node == nil: return Timeline()
  result = Timeline(
    content: parseChain(node.select(".stream > .stream-items")).content,
    minId: node.attr("data-min-position"),
    maxId: node.attr("data-max-position"),
    hasMore: node.select(".has-more-items") != nil,
    beginning: after.len == 0
  )

proc parseVideo*(node: JsonNode; tweetId: int): Video =
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
      available: track{"mediaAvailability"}["status"].to(string) == "available",
      reason: track{"mediaAvailability"}["reason"].to(string))
  of "vmap":
    result = Video(
      playbackType: vmap,
      durationMs: track.getOrDefault("durationMs").getInt(0),
      url: track["vmapUrl"].to(string),
      available: true)
  else:
    echo "Can't parse video of type ", cType

  result.videoId = $tweetId
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

proc parsePhotoRail*(node: XmlNode): seq[GalleryPhoto] =
  for img in node.selectAll(".tweet-media-img-placeholder"):
    result.add GalleryPhoto(
      url: img.attr("data-image-url"),
      tweetId: img.attr("data-tweet-id"),
      color: img.attr("background-color").replace("style: ", "")
    )

proc parseCard*(card: var Card; node: XmlNode) =
  card.title = node.selectText("h2.TwitterCard-title")
  card.text = node.selectText("p.tcu-resetMargin")
  card.dest = node.selectText("span.SummaryCard-destination")

  if card.url.len == 0:
    card.url = node.selectAttr("a", "href")

  let image = node.select(".tcu-imageWrapper img")
  if image != nil:
    # workaround for issue 11713
    card.image = some image.attr("data-src").replace("gname", "g&name")

  if card.kind == liveEvent:
    card.text = card.title
    card.title = node.selectText(".TwitterCard-attribution--category")
