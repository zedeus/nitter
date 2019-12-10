import times, sequtils, options
import norm/sqlite

import prefs_impl

type
  VideoType* = enum
    vmap, m3u8, mp4

dbTypes:
  type
    Profile* = object
      username*: string
      fullname*: string
      location*: string
      website*: string
      bio*: string
      userpic*: string
      banner*: string
      following*: string
      followers*: string
      tweets*: string
      likes*: string
      media*: string
      verified*: bool
      protected*: bool
      joinDate* {.
        dbType: "INTEGER"
        parseIt: it.i.fromUnix()
        formatIt: dbValue(it.toUnix())
        .}: Time
      updated* {.
          dbType: "INTEGER"
          parseIt: it.i.fromUnix()
          formatIt: dbValue(getTime().toUnix())
        .}: Time

    Video* = object
      videoId*: string
      contentId*: string
      durationMs*: int
      url*: string
      thumb*: string
      views*: string
      available*: bool
      reason*: string
      title*: string
      description*: string
      playbackType* {.
          dbType: "STRING"
          parseIt: parseEnum[VideoType](it.s)
          formatIt: dbValue($it)
        .}: VideoType

genPrefsType()

type
  QueryKind* = enum
    posts, replies, media, users, tweets, userList

  Query* = object
    kind*: QueryKind
    text*: string
    filters*: seq[string]
    includes*: seq[string]
    excludes*: seq[string]
    fromUser*: seq[string]
    since*: string
    until*: string
    near*: string
    sep*: string

  Result*[T] = ref object
    content*: seq[T]
    minId*: string
    maxId*: string
    hasMore*: bool
    beginning*: bool
    query*: Query

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
    promoVideoConvo = "promo_video_convo"
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
    id*: int64
    profile*: Profile
    text*: string
    reply*: seq[string]
    hasThread*: bool
    sensitive*: bool
    available*: bool
    tombstone*: string
    thumb*: string
    badge*: string

  Retweet* = object
    by*: string
    id*: int64

  TweetStats* = object
    replies*: string
    retweets*: string
    likes*: string

  Tweet* = ref object
    id*: int64
    threadId*: int64
    profile*: Profile
    text*: string
    time*: Time
    shortTime*: string
    reply*: seq[string]
    pinned*: bool
    hasThread*: bool
    available*: bool
    tombstone*: string
    stats*: TweetStats
    retweet*: Option[Retweet]
    attribution*: Option[Profile]
    quote*: Option[Quote]
    card*: Option[Card]
    gif*: Option[Gif]
    video*: Option[Video]
    photos*: seq[string]
    poll*: Option[Poll]

  Chain* = ref object
    content*: seq[Tweet]
    more*: int64

  Conversation* = ref object
    tweet*: Tweet
    before*: Chain
    after*: Chain
    replies*: Result[Chain]

  Timeline* = Result[Tweet]

  Config* = ref object
    address*: string
    port*: int
    useHttps*: bool
    staticDir*: string
    title*: string
    hostname*: string
    cacheDir*: string
    profileCacheTime*: int
    defaultTheme*: string
    hmacKey*: string

proc contains*(thread: Chain; tweet: Tweet): bool =
  thread.content.anyIt(it.id == tweet.id)
