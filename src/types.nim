import times, sequtils, options, tables, json
import prefs_impl

genPrefsType()

type
  RateLimitError* = object of CatchableError

  Token* = ref object
    tok*: string
    remaining*: int
    reset*: Time
    init*: Time
    lastUse*: Time

  Error* = enum
    null = 0
    noUserMatches = 17
    protectedUser = 22
    couldntAuth = 32
    doesntExist = 34
    userNotFound = 50
    suspended = 63
    rateLimited = 88
    invalidToken = 89
    listIdOrSlug = 112
    forbidden = 200
    badToken = 239
    noCsrf = 353

  Profile* = object
    id*: string
    username*: string
    fullname*: string
    lowername*: string
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
    suspended*: bool
    joinDate*: Time

  VideoType* = enum
    m3u8 = "application/x-mpegURL"
    mp4 = "video/mp4"
    vmap = "video/vmap"

  VideoVariant* = object
    videoType*: VideoType
    url*: string
    bitrate*: int

  Video* = object
    videoId*: string
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

  Card* = object
    kind*: CardKind
    id*: string
    query*: string
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
    profile*: Profile
    text*: string
    time*: Time
    reply*: seq[string]
    pinned*: bool
    hasThread*: bool
    available*: bool
    tombstone*: string
    location*: string
    stats*: TweetStats
    retweet*: Option[Tweet]
    attribution*: Option[Profile]
    mediaTags*: seq[Profile]
    quote*: Option[Tweet]
    card*: Option[Card]
    poll*: Option[Poll]
    gif*: Option[Gif]
    video*: Option[Video]
    photos*: seq[string]

  Result*[T] = object
    content*: seq[T]
    top*, bottom*: string
    beginning*: bool
    query*: Query

  Chain* = object
    content*: seq[Tweet]
    more*: int64
    cursor*: string

  Conversation* = ref object
    tweet*: Tweet
    before*: Chain
    after*: Chain
    replies*: Result[Chain]

  Timeline* = Result[Tweet]

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
    users*: Table[string, Profile]

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

    rssCacheTime*: int
    listCacheTime*: int

    redisHost*: string
    redisPort*: int
    redisConns*: int
    redisMaxConns*: int
    redisPassword*: string

    replaceYouTube*: string

  Rss* = object
    feed*, cursor*: string

  RestApiError* = object
    message*: string

  LinkHeader* = object
    links*: TableRef[string, string]

proc contains*(thread: Chain; tweet: Tweet): bool =
  thread.content.anyIt(it.id == tweet.id)

proc `%`*[T](p: Result[T]): JsonNode =
  result = %p.content

proc `%`*(t: Time): JsonNode =
  result = JsonNode(kind: JString, str: format(t, "yyyy-MM-dd'T'HH:mm:sszzz", utc()))

proc `%`*(t: Tweet): JsonNode =
  let p = t.profile
  result = %* {
    "id": t.id,
    "threadId": t.threadId,
    "replyId": t.replyId,
    "profile": {"id": p.id, "username": p.username, "fullname": p.fullname},
    "text": t.text,
    "time": t.time,
    "reply": t.reply,
    "pinned": t.pinned,
    "hasThread": t.hasThread,
    "available": t.available,
    "tombstone": t.tombstone,
    "location": t.location,
    "stats": t.stats,
    "retweet": t.retweet,
    "attribution": t.attribution,
    "mediaTags": t.mediaTags,
    "quote": t.quote,
    "card": t.card,
    "poll": t.poll,
    "gif": t.gif,
    "video": t.video,
    "photos": t.photos,
  }

proc newRestApiError*(message: string): RestApiError =
  result.message = message

proc newLinkHeader*(): LinkHeader =
  result.links = newTable[string, string]()

proc `[]=`*(links: LinkHeader; rel: string; url: sink string) =
  links.links[rel] = url

proc `$`*(links: LinkHeader): string =
  for rel, url in links.links:
    if len(result) > 0:
      add(result, ", ")
    add(result, "<" & url & ">; rel=\"" & rel & "\"")
