import options
import jsony
from json import JsonNode
import user, media, common

type
  RawTweet* = object
    createdAt*: string
    idStr*: string
    fullText*: string
    displayTextRange*: array[2, int]
    entities*: Entities
    extendedEntities*: ExtendedEntities
    inReplyToStatusIdStr*: string
    inReplyToScreenName*: string
    userIdStr*: string
    isQuoteStatus*: bool
    replyCount*: int
    retweetCount*: int
    favoriteCount*: int
    quoteCount*: int
    conversationIdStr*: string
    favorited*: bool
    retweeted*: bool
    selfThread*: tuple[idStr: string]
    card*: Option[Card]
    quotedStatusIdStr*: string
    retweetedStatusIdStr*: string

  Card* = object
    name*: string
    url*: string
    bindingValues*: JsonNode

  Entities* = object
    hashtags*: seq[Hashtag]
    symbols*: seq[Hashtag]
    userMentions*: seq[UserMention]
    urls*: seq[Url]
    media*: seq[Entity]

  Hashtag* = object
    indices*: Slice[int]

  UserMention* = object
    screenName*: string
    name*: string
    indices*: Slice[int]

  ExtendedEntities* = object
    media*: seq[Entity]

  Entity* = object
    kind*: MediaType
    indices*: Slice[int]
    mediaUrlHttps*: string
    url*: string
    expandedUrl*: string
    videoInfo*: VideoInfo
    ext*: Ext
    extMediaAvailability*: tuple[status: string]
    extAltText*: string
    additionalMediaInfo*: AdditionalMediaInfo
    sourceStatusIdStr*: string
    sourceUserIdStr*: string

  AdditionalMediaInfo* = object
    sourceUser*: Option[RawUser]
    title*: string
    description*: string

  Ext* = object
    mediaStats*: JsonNode

  MediaStats* = object
    ok*: tuple[viewCount: string]

proc renameHook*(v: var Entity; fieldName: var string) =
  if fieldName == "type":
    fieldName = "kind"

proc parseHook*(s: string; i: var int; v: var Slice[int]) =
  var slice: array[2, int]
  parseHook(s, i, slice)
  v = slice[0] ..< slice[1]
