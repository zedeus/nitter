import strutils, strformat, sequtils, algorithm, times
import karax/[karaxdsl, vdom, vstyles]

import ".."/[types, query, formatters]
import tweet, renderutils

proc getQuery(query: Option[Query]): string =
  if query.isNone:
    result = "?"
  else:
    result = genQueryUrl(get(query))
    if result[^1] != '?':
      result &= "&"

proc getTabClass(query: Option[Query]; tab: string): string =
  var classes = @["tab-item"]

  if query.isNone or get(query).kind == multi:
    if tab == "posts":
      classes.add "active"
  elif $get(query).kind == tab:
    classes.add "active"

  return classes.join(" ")

proc renderProfileTabs*(query: Option[Query]; username: string): VNode =
  let link = "/" & username
  buildHtml(ul(class="tab")):
    li(class=query.getTabClass("posts")):
      a(href=link): text "Tweets"
    li(class=query.getTabClass("replies")):
      a(href=(link & "/replies")): text "Tweets & Replies"
    li(class=query.getTabClass("media")):
      a(href=(link & "/media")): text "Media"

proc renderSearchTabs*(query: Option[Query]): VNode =
  var q = if query.isSome: get(query) else: Query()

  buildHtml(ul(class="tab")):
    li(class=query.getTabClass("custom")):
      q.kind = custom
      a(href=genQueryUrl(q)): text "Tweets"
    li(class=query.getTabClass("users")):
      q.kind = users
      a(href=genQueryUrl(q)): text "Users"

proc renderNewer(query: Option[Query]): VNode =
  buildHtml(tdiv(class="timeline-item show-more")):
    a(href=(getQuery(query).strip(chars={'?', '&'}))):
      text "Load newest"

proc renderOlder(query: Option[Query]; minId: string): VNode =
  buildHtml(tdiv(class="show-more")):
    a(href=(&"{getQuery(query)}after={minId}")):
      text "Load older"

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
      renderTweet(threadTweet, prefs, path, class="thread",
                  index=i, total=thread.high)

proc threadFilter(it: Tweet; tweetThread: string): bool =
  it.retweet.isNone and it.reply.len == 0 and it.threadId == tweetThread

proc renderUser(user: Profile; prefs: Prefs): VNode =
  buildHtml(tdiv(class="timeline-item")):
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

proc renderTimelineUsers*(results: Result[Profile]; prefs: Prefs): VNode =
  buildHtml(tdiv(class="timeline")):
    if not results.beginning:
      renderNewer(results.query)

    if results.content.len > 0:
      for user in results.content:
        renderUser(user, prefs)
      renderOlder(results.query, results.minId)
    elif results.beginning:
      renderNoneFound()
    else:
      renderNoMore()

proc renderTimelineTweets*(results: Result[Tweet]; prefs: Prefs; path: string): VNode =
  buildHtml(tdiv(class="timeline")):
    if not results.beginning:
      renderNewer(results.query)

    if results.content.len == 0:
      renderNoneFound()
    else:
      var threads: seq[string]
      for tweet in results.content:
        if tweet.threadId in threads: continue
        let thread = results.content.filterIt(threadFilter(it, tweet.threadId))
        if thread.len < 2:
          renderTweet(tweet, prefs, path)
        else:
          renderThread(thread, prefs, path)
          threads &= tweet.threadId

      if results.hasMore or results.query.isSome:
        renderOlder(results.query, results.minId)
      else:
        renderNoMore()
