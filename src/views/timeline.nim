# SPDX-License-Identifier: AGPL-3.0-only
import strutils, strformat, algorithm, uri, options
import karax/[karaxdsl, vdom]

import ".."/[types, query, formatters]
import tweet, renderutils

proc timelineViewClass(query: Query): string =
  if query.kind != media:
    return "timeline"

  case query.view
  of "grid": "timeline media-grid-view"
  of "gallery": "timeline media-gallery-view"
  else: "timeline"

proc getQuery(query: Query): string =
  if query.kind != posts:
    result = genQueryUrl(query)
  if result.len > 0:
    result &= "&"

proc getSearchMaxId(results: Timeline; path: string): string =
  if results.query.kind != tweets or results.content.len == 0 or
     results.query.until.len == 0:
    return

  let lastThread = results.content[^1]
  if lastThread.len == 0 or lastThread[^1].id == 0:
    return

  # 2000000 is the minimum decrement to guarantee no result overlap
  var maxId = lastThread[^1].id - 2_000_000'i64
  if maxId <= 0:
    maxId = lastThread[^1].id - 1

  if maxId > 0:
    return "maxid:" & $maxId

proc renderToTop*(focus="#"): VNode =
  buildHtml(tdiv(class="top-ref")):
    icon "down", href=focus

proc renderNewer*(query: Query; path: string; focus=""): VNode =
  let
    q = genQueryUrl(query)
    url = if q.len > 0: "?" & q else: ""
    p = if focus.len > 0: path.replace("#m", focus) else: path
  buildHtml(tdiv(class="timeline-item show-more")):
    a(href=(p & url)):
      text "Load newest"

proc renderMore*(query: Query; cursor: string; focus=""): VNode =
  buildHtml(tdiv(class="show-more")):
    a(href=(&"?{getQuery(query)}cursor={encodeUrl(cursor, usePlus=false)}{focus}")):
      text "Load more"

proc renderNoMore(): VNode =
  buildHtml(tdiv(class="timeline-footer")):
    h2(class="timeline-end"):
      text "No more items"

proc renderNoneFound(): VNode =
  buildHtml(tdiv(class="timeline-header")):
    h2(class="timeline-none"):
      text "No items found"

proc renderThread(thread: Tweets; prefs: Prefs; path: string; bigThumb=false): VNode =
  buildHtml(tdiv(class="thread-line")):
    let sortedThread = thread.sortedByIt(it.id)
    for i, tweet in sortedThread:
      # thread has a gap, display "more replies" link
      if i > 0 and tweet.replyId != sortedThread[i - 1].id:
        tdiv(class="timeline-item thread more-replies-thread"):
          tdiv(class="more-replies"):
            a(class="more-replies-text", href=getLink(tweet)):
              text "more replies"

      let show = i == thread.high and sortedThread[0].id != tweet.threadId
      let header = if tweet.pinned or tweet.retweet.isSome: "with-header " else: ""
      renderTweet(tweet, prefs, path, class=(header & "thread"),
                  index=i, last=(i == thread.high), bigThumb=bigThumb)

proc renderUser(user: User; prefs: Prefs): VNode =
  buildHtml(tdiv(class="timeline-item", data-username=user.username)):
    a(class="tweet-link", href=("/" & user.username))
    tdiv(class="tweet-body profile-result"):
      tdiv(class="tweet-header"):
        a(class="tweet-avatar", href=("/" & user.username)):
          genImg(user.getUserPic("_bigger"), class=prefs.getAvatarClass)

        tdiv(class="tweet-name-row"):
          tdiv(class="fullname-and-username"):
            linkUser(user, class="fullname")
            verifiedIcon(user)
        linkUser(user, class="username")

      tdiv(class="tweet-content media-body", dir="auto"):
        verbatim replaceUrls(user.bio, prefs)

proc renderTimelineUsers*(results: Result[User]; prefs: Prefs; path=""): VNode =
  buildHtml(tdiv(class="timeline")):
    if not results.beginning:
      renderNewer(results.query, path)

    if results.content.len > 0:
      for user in results.content:
        renderUser(user, prefs)
      if results.bottom.len > 0:
        renderMore(results.query, results.bottom)
      renderToTop()
    elif results.beginning:
      renderNoneFound()
    else:
      renderNoMore()

proc filterThreads(threads: seq[Tweets]; prefs: Prefs): seq[Tweets] =
  var retweets: seq[int64]
  for thread in threads:
    if thread.len == 1:
      let tweet = thread[0]
      let retweetId = if tweet.retweet.isSome: get(tweet.retweet).id else: 0
      if retweetId in retweets or tweet.id in retweets or
         tweet.pinned and prefs.hidePins:
        continue
      if retweetId != 0 and tweet.retweet.isSome:
        retweets &= retweetId
    result.add(thread)

proc renderTimelineTweets*(results: Timeline; prefs: Prefs; path: string;
                           pinned=none(Tweet)): VNode =
  buildHtml(tdiv(class=results.query.timelineViewClass)):
    if not results.beginning:
      renderNewer(results.query, parseUri(path).path)

    if not prefs.hidePins and pinned.isSome:
      let tweet = get pinned
      renderTweet(tweet, prefs, path)

    if results.content.len == 0:
      if not results.beginning:
        renderNoMore()
      else:
        renderNoneFound()
    else:
      let filtered = filterThreads(results.content, prefs)

      if results.query.view == "gallery":
        let bigThumb = prefs.gallerySize == "Large"
        let galClass = if prefs.compactGallery: "gallery-masonry compact" else: "gallery-masonry"
        tdiv(class=galClass, `data-col-size`=prefs.gallerySize.toLowerAscii):
          for thread in filtered:
            if thread.len == 1: renderTweet(thread[0], prefs, path, bigThumb=bigThumb)
            else: renderThread(thread, prefs, path, bigThumb)
      else:
        for thread in filtered:
          if thread.len == 1: renderTweet(thread[0], prefs, path)
          else: renderThread(thread, prefs, path)

      var cursor = getSearchMaxId(results, path)
      if cursor.len > 0:
        renderMore(results.query, cursor)
      elif results.bottom.len > 0:
        renderMore(results.query, results.bottom)
      renderToTop()
