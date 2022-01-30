import std/[strutils, options, algorithm, json]
import std/unicode except strip
import utils, slices, media, user
import ../types/tweet
from ../types/media as mediaTypes import MediaType
from ../../types import Tweet, User, TweetStats

proc expandTweetEntities(tweet: var Tweet; raw: RawTweet) =
  let
    orig = raw.fullText.toRunes
    textRange = raw.displayTextRange
    textSlice = textRange[0] .. textRange[1]
    hasCard = raw.card.isSome

  var replyTo = ""
  if tweet.replyId > 0:
    tweet.reply.add raw.inReplyToScreenName
    replyTo = raw.inReplyToScreenName

  var replacements = newSeq[ReplaceSlice]()

  for u in raw.entities.urls:
    if u.url.len == 0 or u.url notin raw.fullText:
      continue

    replacements.extractUrls(u, textSlice.b, hideTwitter=raw.isQuoteStatus)
    # if hasCard and u.url == get(tweet.card).url:
    #   get(tweet.card).url = u.expandedUrl

  for m in raw.entities.media:
    replacements.extractUrls(m, textSlice.b, hideTwitter=true)

  for hashtag in raw.entities.hashtags:
    replacements.extractHashtags(hashtag.indices)

  for symbol in raw.entities.symbols:
    replacements.extractHashtags(symbol.indices)

  for mention in raw.entities.userMentions:
    let
      name = mention.screenName
      idx = tweet.reply.find(name)

    if mention.indices.a >= textSlice.a:
      replacements.add ReplaceSlice(kind: rkMention, slice: mention.indices,
        url: "/" & name, display: mention.name)
      if idx > -1 and name != replyTo:
        tweet.reply.delete idx
    elif idx == -1 and tweet.replyId != 0:
      tweet.reply.add name

  replacements.dedupSlices
  replacements.sort(cmp)

  tweet.text = orig.replacedWith(replacements, textSlice)
                   .strip(leading=false)

proc toTweet*(raw: RawTweet): Tweet =
  result = Tweet(
    id: raw.idStr.toId,
    threadId: raw.conversationIdStr.toId,
    replyId: raw.inReplyToStatusIdStr.toId,
    time: parseTwitterDate(raw.createdAt),
    hasThread: raw.selfThread.idStr.len > 0,
    available: true,
    user: User(id: raw.userIdStr),
    stats: TweetStats(
      replies: raw.replyCount,
      retweets: raw.retweetCount,
      likes: raw.favoriteCount,
      quotes: raw.quoteCount
    )
  )

  result.expandTweetEntities(raw)

  if raw.card.isSome:
    let card = raw.card.get
    if "poll" in card.name:
      result.poll = some parsePoll(card)
      if "image" in card.name:
        result.photos.add card.bindingValues{"image_large", "image_value", "url"}
                                            .getStr.getImageUrl
    # elif card.name == "amplify":
    #   discard
    #   # result.video = some(parsePromoVideo(jsCard{"binding_values"}))
    # else:
    #   result.card = some parseCard(card, raw.entities.urls)

  for m in raw.extendedEntities.media:
    case m.kind
    of photo: result.photos.add m.getImageUrl
    of video:
      result.video = some parseVideo(m)
      if m.additionalMediaInfo.sourceUser.isSome:
        result.attribution = some toUser get(m.additionalMediaInfo.sourceUser)
    of animatedGif: result.gif = some parseGif(m)
