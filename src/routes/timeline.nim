# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, strutils, sequtils, uri, options, times, json
import jester, karax/vdom

import router_utils
import ".."/[types, redis_cache, formatters, query, api]
import ../views/[general, profile, timeline, status, search, about_account]

export vdom
export uri, sequtils
export router_utils
export redis_cache, formatters, query, api
export profile, timeline, status, about_account

proc formatApiTime(dt: DateTime): string =
  dt.format("yyyy-MM-dd'T'HH:mm:ss'Z'")

proc userToJson(user: User): JsonNode =
  %*{
    "id": user.id,
    "username": user.username,
    "fullname": user.fullname,
    "bio": user.bio,
    "location": user.location,
    "website": user.website,
    "avatar": getUserPic(user.userPic, "_400x400"),
    "banner": user.banner,
    "followers": user.followers,
    "following": user.following,
    "tweets": user.tweets,
    "likes": user.likes,
    "media": user.media,
    "verified_type": $user.verifiedType,
    "protected": user.protected,
    "suspended": user.suspended,
    "join_date": if user.joinDate.year > 0: user.joinDate.formatApiTime else: ""
  }

proc videoVariantToJson(variant: VideoVariant): JsonNode =
  %*{
    "content_type": $variant.contentType,
    "url": variant.url,
    "bitrate": variant.bitrate,
    "resolution": variant.resolution
  }

proc videoToJson(video: Video): JsonNode =
  var variants = newJArray()
  for variant in video.variants:
    variants.add videoVariantToJson(variant)

  %*{
    "type": $video.playbackType,
    "url": video.url,
    "proxy_url": getVidUrl(video.url),
    "thumbnail": video.thumb,
    "duration_ms": video.durationMs,
    "available": video.available,
    "reason": video.reason,
    "title": video.title,
    "description": video.description,
    "variants": variants
  }

proc mediaToJson(media: Media): JsonNode =
  case media.kind
  of photoMedia:
    %*{
      "type": "photo",
      "url": media.photo.url,
      "proxy_url": getPicUrl(media.photo.url),
      "alt_text": media.photo.altText
    }
  of videoMedia:
    videoToJson(media.video)
  of gifMedia:
    %*{
      "type": "gif",
      "url": media.gif.url,
      "proxy_url": getVidUrl(media.gif.url),
      "thumbnail": media.gif.thumb,
      "alt_text": media.gif.altText
    }

proc pollToJson(poll: Poll): JsonNode =
  %*{
    "options": poll.options,
    "values": poll.values,
    "votes": poll.votes,
    "leader": poll.leader,
    "status": poll.status
  }

proc cardToJson(card: Card): JsonNode =
  var result = %*{
    "kind": $card.kind,
    "url": card.url,
    "title": card.title,
    "destination": card.dest,
    "text": card.text,
    "image": card.image
  }
  if card.video.isSome:
    result["video"] = videoToJson(card.video.get())
  result

proc tweetToJson*(tweet: Tweet; cfg: Config; prefs: Prefs; depth=1): JsonNode =
  if tweet.isNil:
    return newJNull()

  var media = newJArray()
  for item in tweet.media:
    media.add mediaToJson(item)

  var result = %*{
    "id": $tweet.id,
    "url": getUrlPrefix(cfg) & getLink(tweet, focus=false),
    "created_at": tweet.time.formatApiTime,
    "text": tweet.text,
    "html": replaceUrls(tweet.text, prefs),
    "available": tweet.available,
    "tombstone": tweet.tombstone,
    "location": tweet.location,
    "reply_to": tweet.reply,
    "pinned": tweet.pinned,
    "has_thread": tweet.hasThread,
    "note": tweet.note,
    "is_ad": tweet.isAd,
    "is_ai": tweet.isAI,
    "user": userToJson(tweet.user),
    "stats": %*{
      "replies": tweet.stats.replies,
      "retweets": tweet.stats.retweets,
      "likes": tweet.stats.likes,
      "views": tweet.stats.views
    },
    "media": media,
    "history": tweet.history
  }

  if tweet.poll.isSome:
    result["poll"] = pollToJson(tweet.poll.get())

  if tweet.card.isSome:
    result["card"] = cardToJson(tweet.card.get())

  if depth > 0 and tweet.quote.isSome:
    result["quote"] = tweetToJson(tweet.quote.get(), cfg, prefs, depth - 1)

  if depth > 0 and tweet.retweet.isSome:
    result["retweet"] = tweetToJson(tweet.retweet.get(), cfg, prefs, depth - 1)

  result

proc tweetsToJson(tweets: Tweets; cfg: Config; prefs: Prefs): JsonNode =
  result = newJArray()
  for tweet in tweets:
    result.add tweetToJson(tweet, cfg, prefs)

proc getTweetsWithPinned*(profile: Profile): seq[Tweets] =
  result = profile.tweets.content

  if not profile.pinned.isSome:
    return

  let pinnedTweet = profile.pinned.get
  for thread in result:
    for tweet in thread:
      if tweet.id == pinnedTweet.id:
        return

  result.insert(@[pinnedTweet], 0)

proc timelineToJson(groups: seq[Tweets]; cfg: Config; prefs: Prefs): JsonNode =
  result = newJArray()
  for group in groups:
    for tweet in group:
      result.add tweetToJson(tweet, cfg, prefs)

proc timelineApiResponse*(profile: Profile; cfg: Config; prefs: Prefs): string =
  $(%*{
    "user": userToJson(profile.user),
    "cursor": profile.tweets.bottom,
    "has_more": profile.tweets.bottom.len > 0,
    "tweets": timelineToJson(getTweetsWithPinned(profile), cfg, prefs)
  })

proc tweetApiResponse*(tweet: Tweet; cfg: Config; prefs: Prefs): string =
  $(tweetToJson(tweet, cfg, prefs))

proc apiErrorResponse*(message: string): string =
  $(%*{"error": message})

proc getQuery*(request: Request; tab, name: string; prefs: Prefs): Query =
  let view = request.params.getOrDefault("view")
  case tab
  of "with_replies":
    result = getReplyQuery(name)
  of "media":
    result = getMediaQuery(name)
    result.view =
      if view in ["timeline", "grid", "gallery"]: view
      else: prefs.mediaView.toLowerAscii
  of "search":
    result = initQuery(params(request), name=name)
  else:
    result = Query(fromUser: @[name])

template skipIf[T](cond: bool; default; body: Future[T]): Future[T] =
  if cond:
    let fut = newFuture[T]()
    fut.complete(default)
    fut
  else:
    body

proc fetchProfile*(after: string; query: Query; skipRail=false): Future[Profile] {.async.} =
  let
    name = query.fromUser[0]
    userId = await getUserId(name)

  if userId.len == 0:
    return Profile(user: User(username: name))
  elif userId == "suspended":
    return Profile(user: User(username: name, suspended: true))

  # temporary fix to prevent errors from people browsing
  # timelines during/immediately after deployment
  var after = after
  if query.kind in {posts, replies} and after.startsWith("scroll"):
    after.setLen 0

  let
    rail =
      skipIf(skipRail or query.kind == media, @[]):
        getCachedPhotoRail(userId)

    user = getCachedUser(name)
    info = getCachedAccountInfo(name, fetch=false)

  result =
    case query.kind
    of posts: await getGraphUserTweets(userId, TimelineKind.tweets, after)
    of replies: await getGraphUserTweets(userId, TimelineKind.replies, after)
    of media: await getGraphUserTweets(userId, TimelineKind.media, after)
    else: Profile(tweets: await getGraphTweetSearch(query, after))

  result.user = await user
  result.photoRail = await rail
  result.accountInfo = await info

  result.tweets.query = query

proc showTimeline*(request: Request; query: Query; cfg: Config; prefs: Prefs;
                   rss, after: string): Future[string] {.async.} =
  if query.fromUser.len != 1:
    let
      timeline = await getGraphTweetSearch(query, after)
      html = renderTweetSearch(timeline, prefs, getPath())
    return renderMain(html, request, cfg, prefs, "Multi", rss=rss)

  var profile = await fetchProfile(after, query)
  template u: untyped = profile.user

  if u.suspended:
    return showError(getSuspended(u.username), cfg)

  if profile.user.id.len == 0: return

  let pHtml = renderProfile(profile, prefs, getPath())
  result = renderMain(pHtml, request, cfg, prefs, pageTitle(u), pageDesc(u),
                      rss=rss, images = @[u.getUserPic("_400x400")],
                      banner=u.banner)

template respTimeline*(timeline: typed) =
  let t = timeline
  if t.len == 0:
    resp Http404, showError("User \"" & @"name" & "\" not found", cfg)
  resp t

template respUserId*() =
  cond @"user_id".len > 0
  let username = await getCachedUsername(@"user_id")
  if username.len > 0:
    redirect("/" & username)
  else:
    resp Http404, showError("User not found", cfg)

proc createTimelineRouter*(cfg: Config) =
  router timeline:
    get "/i/user/@user_id":
      respUserId()

    get "/intent/user":
      respUserId()

    get "/intent/follow/?":
      let username = request.params.getOrDefault("screen_name")
      if username.len == 0:
        resp Http400, showError("Missing screen_name parameter", cfg)
      redirect("/" & username)

    get "/@name/about/?":
      cond @"name".allCharsInSet({'a'..'z', 'A'..'Z', '0'..'9', '_'})
      let
        prefs = requestPrefs()
        name = @"name"
        info = await getCachedAccountInfo(name)
      if info.suspended:
        resp showError(getSuspended(name), cfg)
      if info.username.len == 0:
        resp Http404, showError("User \"" & name & "\" not found", cfg)
      let aboutHtml = renderAboutAccount(info)
      resp renderMain(aboutHtml, request, cfg, prefs,
                      "About @" & info.username)

    get "/@name/api":
      cond '.' notin @"name"
      cond @"name" notin ["pic", "gif", "video", "search", "settings", "login", "intent", "i"]
      cond @"name".allCharsInSet({'a'..'z', 'A'..'Z', '0'..'9', '_', ','})

      let
        prefs = requestPrefs()
        after = getCursor()
        name = @"name"
        profile = await fetchProfile(after, Query(fromUser: @[name]), skipRail=true)

      if profile.user.suspended:
        resp Http404, apiErrorResponse(getSuspended(name)), "application/json; charset=utf-8"

      if profile.user.id.len == 0:
        resp Http404, apiErrorResponse("User not found"), "application/json; charset=utf-8"

      resp Http200, timelineApiResponse(profile, cfg, prefs),
           "application/json; charset=utf-8"

    get "/@name/?@tab?/?":
      cond '.' notin @"name"
      cond @"name" notin ["pic", "gif", "video", "search", "settings", "login", "intent", "i"]
      cond @"name".allCharsInSet({'a'..'z', 'A'..'Z', '0'..'9', '_', ','})
      cond @"tab" in ["with_replies", "media", "search", ""]
      let
        prefs = requestPrefs()
        after = getCursor()
        names = getNames(@"name")

      var query = request.getQuery(@"tab", @"name", prefs)
      if names.len != 1:
        query.fromUser = names

      # used for the infinite scroll feature
      if @"scroll".len > 0:
        if query.fromUser.len != 1:
          var timeline = await getGraphTweetSearch(query, after)
          if timeline.content.len == 0: 
            resp Http204
          timeline.beginning = true
          resp $renderTweetSearch(timeline, prefs, getPath())
        else:
          var profile = await fetchProfile(after, query, skipRail=true)
          if profile.tweets.content.len == 0: resp Http404
          profile.tweets.beginning = true
          resp $renderTimelineTweets(profile.tweets, prefs, getPath())

      let rssEnabled =
        if @"tab".len == 0: cfg.enableRSSUserTweets
        elif @"tab" == "with_replies": cfg.enableRSSUserReplies
        elif @"tab" == "media": cfg.enableRSSUserMedia
        elif @"tab" == "search": cfg.enableRSSSearch
        else: false

      let rss =
        if not rssEnabled: 
          ""
        elif @"tab".len == 0:
          "/$1/rss" % @"name"
        elif @"tab" == "search":
          "/$1/search/rss?$2" % [@"name", genQueryUrl(query)]
        else:
          "/$1/$2/rss" % [@"name", @"tab"]

      respTimeline(await showTimeline(request, query, cfg, prefs, rss, after))
