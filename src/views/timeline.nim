import strutils, strformat, sequtils, algorithm, times, uri
import karax/[karaxdsl, vdom, vstyles]

import ".."/[types, query, formatters]
import tweet, renderutils

proc getQuery(query: Query): string =
  if query.kind != posts:
    result = genQueryUrl(query)
  if result.len > 0:
    result &= "&"

proc renderNewer(query: Query; path: string): VNode =
  let q = genQueryUrl(query)
  let url = if q.len > 0: "?" & q else: ""
  buildHtml(tdiv(class="timeline-item show-more")):
    a(href=(path & url)):
      text "Load newest"

proc renderMore(query: Query; minId: string): VNode =
  buildHtml(tdiv(class="show-more")):
    a(href=(&"?{getQuery(query)}after={minId}")):
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
    for i, threadTweet in thread.sortedByIt(it.time):
      let show = i == thread.len and thread[0].id != threadTweet.threadId
      renderTweet(threadTweet, prefs, path, class="thread",
                  index=i, total=thread.high, showThread=show)

proc threadFilter(it: Tweet; tweetThread: string): bool =
  it.retweet.isNone and it.reply.len == 0 and it.threadId == tweetThread

proc renderUser(user: Profile; prefs: Prefs): VNode =
  buildHtml(tdiv(class="timeline-item")):
    a(class="tweet-link", href=("/" & user.username))
    tdiv(class="tweet-body profile-result"):
      tdiv(class="tweet-header"):
        a(class="tweet-avatar", href=("/" & user.username)):
          genImg(user.getUserpic("_bigger"), class="avatar")

        tdiv(class="tweet-name-row"):
          tdiv(class="fullname-and-username"):
            linkUser(user, class="fullname")
        linkUser(user, class="username")

      tdiv(class="tweet-content media-body"):
        verbatim linkifyText(user.bio, prefs)

proc renderTimelineUsers*(results: Result[Profile]; prefs: Prefs; path=""): VNode =
  buildHtml(tdiv(class="timeline")):
    if not results.beginning:
      renderNewer(results.query, path)

    if results.content.len > 0:
      for user in results.content:
        renderUser(user, prefs)
      if results.minId != "0":
        renderMore(results.query, results.minId)
    elif results.beginning:
      renderNoneFound()
    else:
      renderNoMore()

proc renderTimelineTweets*(results: Result[Tweet]; prefs: Prefs; path: string): VNode =
  buildHtml(tdiv(class="timeline")):
    if not results.beginning:
      renderNewer(results.query, parseUri(path).path)

    if results.content.len == 0:
      renderNoneFound()
    else:
      var threads: seq[string]
      var retweets: seq[string]
      for tweet in results.content:
        if tweet.threadId in threads or tweet.id in retweets: continue
        let thread = results.content.filterIt(threadFilter(it, tweet.threadId))
        if thread.len < 2:
          if tweet.retweet.isSome:
            retweets &= tweet.id
          renderTweet(tweet, prefs, path, showThread=tweet.hasThread)
        else:
          renderThread(thread, prefs, path)
          threads &= tweet.threadId

      if results.hasMore or results.query.kind != posts:
        renderMore(results.query, results.minId)
      else:
        renderNoMore()
