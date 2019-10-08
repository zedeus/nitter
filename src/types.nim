import times, sequtils, options
import norm/sqlite

import prefs_impl

export sqlite, options

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
      playbackType* {.
          dbType: "STRING"
          parseIt: parseEnum[VideoType](it.s)
          formatIt: dbValue($it)
        .}: VideoType

genPrefsType()
dbFromTypes("cache.db", "", "", "", [Profile, Video])

type
  QueryKind* = enum
    posts, replies, media, users, custom, userList

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
    tombstone*: string
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
    hasThread*: bool
    available*: bool
    tombstone*: string
    stats*: TweetStats
    retweet*: Option[Retweet]
    quote*: Option[Quote]
    card*: Option[Card]
    gif*: Option[Gif]
    video*: Option[Video]
    photos*: seq[string]
    poll*: Option[Poll]

  Thread* = ref object
    content*: seq[Tweet]
    more*: int

  Conversation* = ref object
    tweet*: Tweet
    before*: Thread
    after*: Thread
    replies*: Result[Thread]

  Timeline* = Result[Tweet]

  Config* = ref object
    address*: string
    port*: int
    useHttps*: bool
    title*: string
    staticDir*: string
    cacheDir*: string
    profileCacheTime*: int

proc contains*(thread: Thread; tweet: Tweet): bool =
  thread.content.anyIt(it.id == tweet.id)
