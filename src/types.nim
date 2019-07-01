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
    vmap, m3u8, mp4

  Video* = object
    contentId*: string
    playbackType*: VideoType
    durationMs*: int
    url*: string
    thumb*: string
    views*: string
    available*: bool

  Gif* = object
    url*: string
    thumb*: string

  Poll* = object
    options*: seq[string]
    values*: seq[int]
    votes*: string
    status*: string
    leader*: int

  Quote* = object
    id*: string
    profile*: Profile
    text*: string
    sensitive*: bool
    thumb*: Option[string]
    badge*: Option[string]

  Retweet* = object
    by*: string
    id*: string

  TweetStats* = object
    replies*: string
    retweets*: string
    likes*: string

  Tweet* = ref object
    id*: string
    profile*: Profile
    text*: string
    time*: Time
    shortTime*: string
    available*: bool
    pinned*: bool
    stats*: TweetStats
    retweet*: Option[Retweet]
    quote*: Option[Quote]
    gif*: Option[Gif]
    video*: Option[Video]
    photos*: seq[string]
    poll*: Option[Poll]

  Thread* = object
    tweets*: seq[Tweet]
    more*: int

  Conversation* = ref object
    tweet*: Tweet
    before*: Thread
    after*: Thread
    replies*: seq[Thread]

  Timeline* = ref object
    tweets*: seq[Tweet]
    minId*: string
    maxId*: string
    hasMore*: bool

proc contains*(thread: Thread; tweet: Tweet): bool =
  thread.tweets.anyIt(it.id == tweet.id)
