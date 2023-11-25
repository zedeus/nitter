# SPDX-License-Identifier: AGPL-3.0-only
import times, sequtils, options, tables
import prefs_impl

genPrefsType()

type
  RateLimitError* = object of CatchableError
  InternalError* = object of CatchableError
  BadClientError* = object of CatchableError

  TimelineKind* {.pure.} = enum
    tweets, replies, media

  Api* {.pure.} = enum
    tweetDetail
    tweetResult
    photoRail
    search
    list
    listBySlug
    listMembers
    listTweets
    userRestId
    userScreenName
    userTweets
    userTweetsAndReplies
    userMedia

  RateLimit* = object
    remaining*: int
    reset*: int
    limited*: bool
    limitedAt*: int

  GuestAccount* = ref object
    id*: int64
    oauthToken*: string
    oauthSecret*: string
    pending*: int
    apis*: Table[Api, RateLimit]

  Error* = enum
    null = 0
    noUserMatches = 17
    protectedUser = 22
    missingParams = 25
    couldntAuth = 32
    doesntExist = 34
    invalidParam = 47
    userNotFound = 50
    suspended = 63
    rateLimited = 88
    expiredToken = 89
    listIdOrSlug = 112
    tweetNotFound = 144
    tweetNotAuthorized = 179
    forbidden = 200
    badToken = 239
    noCsrf = 353
    tweetUnavailable = 421
    tweetCensored = 422

  VerifiedType* = enum
    none = "None"
    blue = "Blue"
    business = "Business"
    government = "Government"

  User* = object
    id*: string
    username*: string
    fullname*: string
    location*: string
    website*: string
    bio*: string
    userPic*: string
    banner*: string
    pinnedTweet*: int64
    following*: int
    followers*: int
    tweets*: int
    likes*: int
    media*: int
    verifiedType*: VerifiedType
    protected*: bool
    suspended*: bool
    joinDate*: DateTime

  VideoType* = enum
    m3u8 = "application/x-mpegURL"
    mp4 = "video/mp4"
    vmap = "video/vmap"

  VideoVariant* = object
    contentType*: VideoType
    url*: string
    bitrate*: int
    resolution*: int

  Video* = object
    durationMs*: int
    url*: string
    thumb*: string
    views*: string
    available*: bool
    reason*: string
    title*: string
    description*: string
    playbackType*: VideoType
    variants*: seq[VideoVariant]

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

  Gif* = object
    url*: string
    thumb*: string

  GalleryPhoto* = object
    url*: string
    tweetId*: string
    color*: string

  PhotoRail* = seq[GalleryPhoto]

  Poll* = object
    options*: seq[string]
    values*: seq[int]
    votes*: int
    leader*: int
    status*: string

  CardKind* = enum
    amplify = "amplify"
    app = "app"
    appPlayer = "appplayer"
    player = "player"
    summary = "summary"
    summaryLarge = "summary_large_image"
    promoWebsite = "promo_website"
    promoVideo = "promo_video_website"
    promoVideoConvo = "promo_video_convo"
    promoImageConvo = "promo_image_convo"
    promoImageApp = "promo_image_app"
    storeLink = "direct_store_link_app"
    liveEvent = "live_event"
    broadcast = "broadcast"
    periscope = "periscope_broadcast"
    unified = "unified_card"
    moment = "moment"
    messageMe = "message_me"
    videoDirectMessage = "video_direct_message"
    imageDirectMessage = "image_direct_message"
    audiospace = "audiospace"
    newsletterPublication = "newsletter_publication"
    jobDetails = "job_details"
    hidden
    unknown

  Card* = object
    kind*: CardKind
    url*: string
    title*: string
    dest*: string
    text*: string
    image*: string
    video*: Option[Video]

  TweetStats* = object
    replies*: int
    retweets*: int
    likes*: int
    quotes*: int

  Tweet* = ref object
    id*: int64
    threadId*: int64
    replyId*: int64
    user*: User
    text*: string
    time*: DateTime
    reply*: seq[string]
    pinned*: bool
    hasThread*: bool
    available*: bool
    tombstone*: string
    location*: string
    # Unused, needed for backwards compat
    source*: string
    stats*: TweetStats
    retweet*: Option[Tweet]
    attribution*: Option[User]
    mediaTags*: seq[User]
    quote*: Option[Tweet]
    card*: Option[Card]
    poll*: Option[Poll]
    gif*: Option[Gif]
    video*: Option[Video]
    photos*: seq[string]

  Tweets* = seq[Tweet]

  Result*[T] = object
    content*: seq[T]
    top*, bottom*: string
    beginning*: bool
    query*: Query

  Chain* = object
    content*: Tweets
    hasMore*: bool
    cursor*: string

  Conversation* = ref object
    tweet*: Tweet
    before*: Chain
    after*: Chain
    replies*: Result[Chain]

  Timeline* = Result[Tweets]

  Profile* = object
    user*: User
    photoRail*: PhotoRail
    pinned*: Option[Tweet]
    tweets*: Timeline

  List* = object
    id*: string
    name*: string
    userId*: string
    username*: string
    description*: string
    members*: int
    banner*: string

  GlobalObjects* = ref object
    tweets*: Table[string, Tweet]
    users*: Table[string, User]

  Config* = ref object
    address*: string
    port*: int
    useHttps*: bool
    httpMaxConns*: int
    title*: string
    hostname*: string
    staticDir*: string

    hmacKey*: string
    base64Media*: bool
    minTokens*: int
    enableRss*: bool
    enableDebug*: bool
    proxy*: string
    proxyAuth*: string

    rssCacheTime*: int
    listCacheTime*: int

    redisHost*: string
    redisPort*: int
    redisConns*: int
    redisMaxConns*: int
    redisPassword*: string

  Rss* = object
    feed*, cursor*: string

proc contains*(thread: Chain; tweet: Tweet): bool =
  thread.content.anyIt(it.id == tweet.id)

proc add*(timeline: var seq[Tweets]; tweet: Tweet) =
  timeline.add @[tweet]
