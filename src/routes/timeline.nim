# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, strutils, sequtils, uri, options, times
import jester, karax/vdom

import router_utils
import ".."/[types, redis_cache, formatters, query, api]
import ../views/[general, profile, timeline, status, search]

export vdom
export uri, sequtils
export router_utils
export redis_cache, formatters, query, api
export profile, timeline, status

proc getQuery*(request: Request; tab, name: string): Query =
  case tab
  of "with_replies": getReplyQuery(name)
  of "media": getMediaQuery(name)
  of "search": initQuery(params(request), name=name)
  else: Query(fromUser: @[name])

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

  result =
    case query.kind
    of posts: await getGraphUserTweets(userId, TimelineKind.tweets, after)
    of replies: await getGraphUserTweets(userId, TimelineKind.replies, after)
    of media: await getGraphUserTweets(userId, TimelineKind.media, after)
    else: Profile(tweets: await getGraphTweetSearch(query, after))

  result.user = await user
  result.photoRail = await rail

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

    get "/@name/?@tab?/?":
      cond '.' notin @"name"
      cond @"name" notin ["pic", "gif", "video", "search", "settings", "login", "intent", "i"]
      cond @"name".allCharsInSet({'a'..'z', 'A'..'Z', '0'..'9', '_', ','})
      cond @"tab" in ["with_replies", "media", "search", ""]
      let
        prefs = cookiePrefs()
        after = getCursor()
        names = getNames(@"name")

      var query = request.getQuery(@"tab", @"name")
      if names.len != 1:
        query.fromUser = names

      # used for the infinite scroll feature
      if @"scroll".len > 0:
        if query.fromUser.len != 1:
          var timeline = await getGraphTweetSearch(query, after)
          if timeline.content.len == 0: resp Http404
          timeline.beginning = true
          resp $renderTweetSearch(timeline, prefs, getPath())
        else:
          var profile = await fetchProfile(after, query, skipRail=true)
          if profile.tweets.content.len == 0: resp Http404
          profile.tweets.beginning = true
          resp $renderTimelineTweets(profile.tweets, prefs, getPath())

      let rss =
        if @"tab".len == 0:
          "/$1/rss" % @"name"
        elif @"tab" == "search":
          "/$1/search/rss?$2" % [@"name", genQueryUrl(query)]
        else:
          "/$1/$2/rss" % [@"name", @"tab"]

      respTimeline(await showTimeline(request, query, cfg, prefs, rss, after))
