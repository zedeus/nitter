import times, sequtils, options
import norm/sqlite

export sqlite, options

type
  VideoType* = enum
    vmap, m3u8, mp4

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

    Video* = object
      videoId*: string
      contentId*: string
      durationMs*: int
      url*: string
      thumb*: string
      views*: string
      playbackType* {.
          dbType: "STRING",
          parseIt: parseEnum[VideoType](it.s),
          formatIt: $it,
        .}: VideoType
      available* {.
          dbType: "STRING",
          parseIt: parseBool(it.s)
          formatIt: $it
        .}: bool

type
  QueryKind* = enum
    replies, media, multi, custom = "search"

  Query* = object
    kind*: QueryKind
    filters*: seq[string]
    includes*: seq[string]
    excludes*: seq[string]
    fromUser*: seq[string]
    sep*: string

  Gif* = object
    url*: string
    thumb*: string

  GalleryPhoto* = object
    url*: string
    tweetId*: string
    color*: string

  Poll* = object
    options*: seq[string]
    values*: seq[int]
    votes*: string
    status*: string
    leader*: int

  CardKind* = enum
    summary = "summary"
    summaryLarge = "summary_large_image"
    promoWebsite = "promo_website"
    promoVideo = "promo_video_website"
    player = "player"
    liveEvent = "live_event"

  Card* = object
    kind*: CardKind
    id*: string
    query*: string
    url*: string
    title*: string
    dest*: string
    text*: string
    image*: Option[string]
    video*: Option[Video]

  Quote* = object
    id*: string
    profile*: Profile
    text*: string
    reply*: seq[string]
    hasThread*: bool
    sensitive*: bool
    available*: bool
    thumb*: string
    badge*: string

  Retweet* = object
    by*: string
    id*: string

  TweetStats* = object
    replies*: string
    retweets*: string
    likes*: string

  Tweet* = ref object
    id*: string
    threadId*: string
    profile*: Profile
    text*: string
    time*: Time
    shortTime*: string
    reply*: seq[string]
    pinned*: bool
    available*: bool
    hasThread*: bool
    stats*: TweetStats
    retweet*: Option[Retweet]
    quote*: Option[Quote]
    card*: Option[Card]
    gif*: Option[Gif]
    video*: Option[Video]
    photos*: seq[string]
    poll*: Option[Poll]

  Thread* = ref object
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
    beginning*: bool
    query*: Option[Query]

  Config* = ref object
    address*: string
    port*: int
    title*: string
    staticDir*: string
    cacheDir*: string
    profileCacheTime*: int

proc contains*(thread: Thread; tweet: Tweet): bool =
  thread.tweets.anyIt(it.id == tweet.id)
