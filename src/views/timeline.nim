# SPDX-License-Identifier: AGPL-3.0-only
import strutils, strformat, sequtils, algorithm, uri, options
import karax/[karaxdsl, vdom]

import ".."/[types, query, formatters]
import tweet, renderutils

proc getQuery(query: Query): string =
  if query.kind != posts:
    result = genQueryUrl(query)
  if result.len > 0:
    result &= "&"

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

proc renderThread(thread: seq[Tweet]; prefs: Prefs; path: string): VNode =
  buildHtml(tdiv(class="thread-line")):
    let sortedThread = thread.sortedByIt(it.id)
    for i, tweet in sortedThread:
      let show = i == thread.high and sortedThread[0].id != tweet.threadId
      let header = if tweet.pinned or tweet.retweet.isSome: "with-header " else: ""
      renderTweet(tweet, prefs, path, class=(header & "thread"),
                  index=i, last=(i == thread.high), showThread=show)

proc threadFilter(tweets: openArray[Tweet]; threads: openArray[int64]; it: Tweet): seq[Tweet] =
  result = @[it]
  if it.retweet.isSome or it.replyId in threads: return
  for t in tweets:
    if t.id == result[0].replyId:
      result.insert t
    elif t.replyId == result[0].id:
      result.add t

proc renderUser*(user: User; prefs: Prefs): VNode =
  buildHtml(tdiv(class="timeline-item")):
    a(class="tweet-link", href=("/" & user.username))
    tdiv(class="tweet-body profile-result"):
      tdiv(class="tweet-header"):
        a(class="tweet-avatar", href=("/" & user.username)):
          genImg(user.getUserPic("_bigger"), class=prefs.getAvatarClass)

        tdiv(class="tweet-name-row"):
          tdiv(class="fullname-and-username"):
            linkUser(user, class="fullname")
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

proc renderTimelineTweets*(results: Result[Tweet]; prefs: Prefs; path: string;
                           pinned=none(Tweet)): VNode =
  buildHtml(tdiv(class="timeline")):
    if not results.beginning:
      renderNewer(results.query, parseUri(path).path)

    if not prefs.hidePins and pinned.isSome:
      let tweet = get pinned
      renderTweet(tweet, prefs, path, showThread=tweet.hasThread)

    if results.content.len == 0:
      if not results.beginning:
        renderNoMore()
      else:
        renderNoneFound()
    else:
      var
        threads: seq[int64]
        retweets: seq[int64]

      for tweet in results.content:
        let rt = if tweet.retweet.isSome: get(tweet.retweet).id else: 0

        if tweet.id in threads or rt in retweets or tweet.id in retweets or
           tweet.pinned and prefs.hidePins: continue

        let thread = results.content.threadFilter(threads, tweet)
        if thread.len < 2:
          var hasThread = tweet.hasThread
          if rt != 0:
            retweets &= rt
            hasThread = get(tweet.retweet).hasThread
          renderTweet(tweet, prefs, path, showThread=hasThread)
        else:
          renderThread(thread, prefs, path)
          threads &= thread.mapIt(it.id)

      renderMore(results.query, results.bottom)
      renderToTop()
