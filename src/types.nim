import times, sequtils, strutils, options
import norm/sqlite

export sqlite, options

db("cache.db", "", "", ""):
  type
    Profile* = object
      username*: string
      fullname*: string
      bio*: string
      userpic*: string
      banner*: string
      following*: string
      followers*: string
      tweets*: string
      verified* {.
          dbType: "STRING",
          parseIt: parseBool(it.s)
          formatIt: $it
        .}: bool
      protected* {.
          dbType: "STRING",
          parseIt: parseBool(it.s)
          formatIt: $it
        .}: bool
      updated* {.
          dbType: "INTEGER",
          parseIt: it.i.fromUnix(),
          formatIt: getTime().toUnix()
        .}: Time

type
  VideoType* = enum
    vmap, m3u8

  Video* = object
    contentType*: VideoType
    url*: string
    thumb*: string
    id*: string
    views*: string
    length*: int
    available*: bool

  Gif* = object
    url*: string
    thumb*: string

  Quote* = object
    id*: string
    profile*: Profile
    link*: string
    text*: string
    sensitive*: bool
    thumb*: Option[string]
    badge*: Option[string]

  Tweet* = ref object
    id*: string
    profile*: Profile
    link*: string
    text*: string
    time*: Time
    shortTime*: string
    replies*: string
    retweets*: string
    likes*: string
    pinned*: bool
    quote*: Option[Quote]
    retweetBy*: Option[string]
    retweetId*: Option[string]
    gif*: Option[Gif]
    video*: Option[Video]
    photos*: seq[string]
    available*: bool

  Tweets* = seq[Tweet]

  Conversation* = ref object
    tweet*: Tweet
    before*: Tweets
    after*: Tweets
    replies*: seq[Tweets]

  Timeline* = ref object
    tweets*: Tweets
    minId*: string
    maxId*: string
    hasMore*: bool

proc contains*(thread: Tweets; tweet: Tweet): bool =
  thread.anyIt(it.id == tweet.id)
