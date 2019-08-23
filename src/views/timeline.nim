import strutils, strformat, sequtils, algorithm, times
import karax/[karaxdsl, vdom, vstyles]

import ../types, ../search
import tweet, renderutils

proc getQuery(timeline: Timeline): string =
  if timeline.query.isNone: "?"
  else: genQueryUrl(get(timeline.query))

proc getTabClass(timeline: Timeline; tab: string): string =
  var classes = @["tab-item"]

  if timeline.query.isNone or get(timeline.query).kind == multi:
    if tab == "posts":
      classes.add "active"
  elif $get(timeline.query).kind == tab:
    classes.add "active"

  return classes.join(" ")

proc renderSearchTabs(timeline: Timeline; username: string): VNode =
  let link = "/" & username
  buildHtml(ul(class="tab")):
    li(class=timeline.getTabClass("posts")):
      a(href=link): text "Tweets"
    li(class=timeline.getTabClass("replies")):
      a(href=(link & "/replies")): text "Tweets & Replies"
    li(class=timeline.getTabClass("media")):
      a(href=(link & "/media")): text "Media"

proc renderNewer(timeline: Timeline; username: string): VNode =
  buildHtml(tdiv(class="status-el show-more")):
    a(href=("/" & username & getQuery(timeline).strip(chars={'?'}))):
      text "Load newest tweets"

proc renderOlder(timeline: Timeline; username: string): VNode =
  buildHtml(tdiv(class="show-more")):
    a(href=(&"/{username}{getQuery(timeline)}after={timeline.minId}")):
      text "Load older tweets"

proc renderNoMore(): VNode =
  buildHtml(tdiv(class="timeline-footer")):
    h2(class="timeline-end", style={textAlign: "center"}):
      text "No more tweets."

proc renderNoneFound(): VNode =
  buildHtml(tdiv(class="timeline-header")):
    h2(class="timeline-none", style={textAlign: "center"}):
      text "No tweets found."

proc renderProtected(username: string): VNode =
  buildHtml(tdiv(class="timeline-header timeline-protected")):
    h2: text "This account's tweets are protected."
    p: text &"Only confirmed followers have access to @{username}'s tweets."

proc renderThread(thread: seq[Tweet]; prefs: Prefs): VNode =
  buildHtml(tdiv(class="timeline-tweet thread-line")):
    for i, threadTweet in thread.sortedByIt(it.time):
      renderTweet(threadTweet, prefs, class="thread", index=i, total=thread.high)

proc threadFilter(it: Tweet; tweetThread: string): bool =
  it.retweet.isNone and it.reply.len == 0 and it.threadId == tweetThread

proc renderTweets(timeline: Timeline; prefs: Prefs): VNode =
  buildHtml(tdiv(id="posts")):
    var threads: seq[string]
    for tweet in timeline.content:
      if tweet.threadId in threads: continue
      let thread = timeline.content.filterIt(threadFilter(it, tweet.threadId))
      if thread.len < 2:
        renderTweet(tweet, prefs, class="timeline-tweet")
      else:
        renderThread(thread, prefs)
        threads &= tweet.threadId

proc renderTimeline*(timeline: Timeline; username: string; protected: bool;
                     prefs: Prefs; multi=false): VNode =
  buildHtml(tdiv):
    if multi:
      tdiv(class="multi-header"):
        text username.replace(",", " | ")

    if not protected:
      renderSearchTabs(timeline, username)
      if not timeline.beginning:
        renderNewer(timeline, username)

    if protected:
      renderProtected(username)
    elif timeline.content.len == 0:
      renderNoneFound()
    else:
      renderTweets(timeline, prefs)
      if timeline.hasMore or timeline.query.isSome:
        renderOlder(timeline, username)
      else:
        renderNoMore()
