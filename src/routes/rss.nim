# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, tables, times, hashes, uri

import jester

import router_utils, timeline
import ../query

include "../views/rss.nimf"

export times, hashes

proc redisKey*(page, name, cursor: string): string =
  result = page & ":" & name
  if cursor.len > 0:
    result &= ":" & cursor

proc timelineRss*(req: Request; cfg: Config; query: Query; prefs: Prefs): Future[Rss] {.async.} =
  var profile: Profile
  let
    name = req.params.getOrDefault("name")
    after = getCursor(req)
    names = getNames(name)

  if names.len == 1:
    profile = await fetchProfile(after, query, skipRail=true)
  else:
    var q = query
    q.fromUser = names
    profile.tweets = await getGraphTweetSearch(q, after)
    # this is kinda dumb
    profile.user = User(
      username: name,
      fullname: names.join(" | "),
      userpic: "https://abs.twimg.com/sticky/default_profile_images/default_profile.png"
    )

  if profile.user.suspended:
    return Rss(feed: profile.user.username, cursor: "suspended")

  if profile.user.fullname.len > 0:
    let rss = renderTimelineRss(profile, cfg, prefs, multi=(names.len > 1))
    return Rss(feed: rss, cursor: profile.tweets.bottom)

template respRss*(rss, page) =
  if rss.cursor.len == 0:
    let info = case page
               of "User": " \"" & @"name" & "\" "
               of "List": " \"" & @"id" & "\" "
               else: " "

    resp Http404, showError(page & info & "not found", cfg)
  elif rss.cursor.len == 9 and rss.cursor == "suspended":
    resp Http404, showError(getSuspended(@"name"), cfg)

  let headers = {"Content-Type": "application/rss+xml; charset=utf-8",
                 "Min-Id": rss.cursor}
  resp Http200, headers, rss.feed

proc createRssRouter*(cfg: Config) =
  router rss:
    get "/search/rss":
      if not cfg.enableRSSSearch:
        resp Http403, showError("RSS feed is disabled", cfg)
      if @"q".len > 200:
        resp Http400, showError("Search input too long.", cfg)

      let
        prefs = requestPrefs()
        query = initQuery(params(request))
      if query.kind != tweets:
        resp Http400, showError("Only Tweet searches are allowed for RSS feeds.", cfg)

      let
        cursor = getCursor()
        key = redisKey("search", $hash(genQueryUrl(query)), cursor)

      var rss = await getCachedRss(key)
      if rss.cursor.len > 0:
        respRss(rss, "Search")

      let tweets = await getGraphTweetSearch(query, cursor)
      rss.cursor = tweets.bottom
      rss.feed = renderSearchRss(tweets.content, query.text, genQueryUrl(query), cfg, prefs)

      await cacheRss(key, rss)
      respRss(rss, "Search")

    get "/@name/rss":
      cond '.' notin @"name"
      if not cfg.enableRSSUserTweets:
        resp Http403, showError("RSS feed is disabled", cfg)
      let
        prefs = requestPrefs()
        name = @"name"
        key = redisKey("twitter", name, getCursor())

      var rss = await getCachedRss(key)
      if rss.cursor.len > 0:
        respRss(rss, "User")

      rss = await timelineRss(request, cfg, Query(fromUser: @[name]), prefs)

      await cacheRss(key, rss)
      respRss(rss, "User")

    get "/@name/@tab/rss":
      cond '.' notin @"name"
      cond @"tab" in ["with_replies", "media", "search"]
      let rssEnabled = case @"tab"
        of "with_replies": cfg.enableRSSUserReplies
        of "media": cfg.enableRSSUserMedia
        of "search": cfg.enableRSSSearch
        else: false
      if not rssEnabled:
        resp Http403, showError("RSS feed is disabled", cfg)
      let
        prefs = requestPrefs()
        name = @"name"
        tab = @"tab"
        query =
          case tab
          of "with_replies": getReplyQuery(name)
          of "media": getMediaQuery(name)
          of "search": initQuery(params(request), name=name)
          else: Query(fromUser: @[name])

      let searchKey = if tab != "search": ""
                      else: ":" & $hash(genQueryUrl(query))

      let key = redisKey(tab, name & searchKey, getCursor())

      var rss = await getCachedRss(key)
      if rss.cursor.len > 0:
        respRss(rss, "User")

      rss = await timelineRss(request, cfg, query, prefs)

      await cacheRss(key, rss)
      respRss(rss, "User")

    get "/@name/lists/@slug/rss":
      cond @"name" != "i"
      if not cfg.enableRSSList:
        resp Http403, showError("RSS feed is disabled", cfg)
      let
        slug = decodeUrl(@"slug")
        list = await getCachedList(@"name", slug)
        cursor = getCursor()

      if list.id.len == 0:
        resp Http404, showError("List \"" & @"slug" & "\" not found", cfg)

      let url = "/i/lists/" & list.id & "/rss"
      if cursor.len > 0:
        redirect(url & "?cursor=" & encodeUrl(cursor, false))
      else:
        redirect(url)

    get "/i/lists/@id/rss":
      if not cfg.enableRSSList:
        resp Http403, showError("RSS feed is disabled", cfg)
      let
        prefs = requestPrefs()
        id = @"id"
        cursor = getCursor()
        key = redisKey("lists", id, cursor)

      var rss = await getCachedRss(key)
      if rss.cursor.len > 0:
        respRss(rss, "List")

      let
        list = await getCachedList(id=id)
        timeline = await getGraphListTweets(list.id, cursor)
      rss.cursor = timeline.bottom
      rss.feed = renderListRss(timeline.content, list, cfg, prefs)

      await cacheRss(key, rss)
      respRss(rss, "List")

    get "/@name/status/@id/rss":
      cond '.' notin @"name"
      let name = @"name"
      let id = @"id"

      var key = name & "/" & id

      var rss = await getCachedRss(key)
      if rss.cursor.len > 0:
        respRss(rss, "Tweet")

      var conv = await getTweet(id)
      if conv == nil or conv.tweet == nil or conv.tweet.id == 0:
        var error = "Tweet not found"
        if conv != nil and conv.tweet != nil and conv.tweet.tombstone.len > 0:
          error = conv.tweet.tombstone
        resp Http404, showError(error, cfg)

      while conv.after.hasMore:
        let newer_conv = await getTweet($conv.after.content[^1].id)
        if newer_conv == nil or newer_conv.tweet == nil or newer_conv.tweet.id == 0:
          break
        conv = newer_conv

      let lastThreadTweets = conv.before.content & @[conv.tweet] & conv.after.content
      let feed = compress renderThreadRss(lastThreadTweets, name, id, cfg)
      rss = Rss(feed: feed, cursor: $lastThreadTweets[0].id)

      await cacheRss(key, rss)
      respRss(rss, "Tweet")
