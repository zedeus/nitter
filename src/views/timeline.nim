import strutils, strformat, algorithm, times
import karax/[karaxdsl, vdom, vstyles]

import ../types, ../search
import tweet, renderutils

proc getQuery(timeline: Timeline): string =
  if timeline.query.isNone: "?"
  else: genQueryUrl(get(timeline.query))

proc getTabClass(timeline: Timeline; tab: string): string =
  var classes = @["tab-item"]

  if timeline.query.isNone:
    if tab == "tweets":
      classes.add "active"
  elif $timeline.query.get().queryType == tab:
    classes.add "active"

  return classes.join(" ")

proc renderSearchTabs(timeline: Timeline; profile: Profile): VNode =
  let link = "/" & profile.username
  buildHtml(ul(class="tab")):
    li(class=timeline.getTabClass("tweets")):
      a(href=link): text "Tweets"
    li(class=timeline.getTabClass("replies")):
      a(href=(link & "/replies")): text "Tweets & Replies"
    li(class=timeline.getTabClass("media")):
      a(href=(link & "/media")): text "Media"

proc renderNewer(timeline: Timeline; profile: Profile): VNode =
  buildHtml(tdiv(class="status-el show-more")):
    a(href=("/" & profile.username & getQuery(timeline).strip(chars={'?'}))):
      text "Load newest tweets"

proc renderOlder(timeline: Timeline; profile: Profile): VNode =
  buildHtml(tdiv(class="show-more")):
    a(href=(&"/{profile.username}{getQuery(timeline)}after={timeline.minId}")):
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

proc renderThread(thread: seq[Tweet]): VNode =
  buildHtml(tdiv(class="timeline-tweet thread-line")):
    for i, threadTweet in thread.sortedByIt(it.time):
      renderTweet(threadTweet, "thread", index=i, total=thread.high)

proc threadFilter(it: Tweet; tweetThread: string): bool =
  it.retweet.isNone and it.reply.len == 0 and it.threadId == tweetThread

proc renderTweets(timeline: Timeline): VNode =
  buildHtml(tdiv(id="tweets")):
    var threads: seq[string]
    for tweet in timeline.tweets:
      if tweet.threadId in threads: continue
      let thread = timeline.tweets.filterIt(threadFilter(it, tweet.threadId))
      if thread.len < 2:
        renderTweet(tweet, "timeline-tweet")
      else:
        renderThread(thread)
        threads &= tweet.threadId

proc renderTimeline*(timeline: Timeline; profile: Profile): VNode =
  buildHtml(tdiv):
    renderSearchTabs(timeline, profile)

    if not profile.protected and not timeline.beginning:
      renderNewer(timeline, profile)

    if profile.protected:
      renderProtected(profile.username)
    elif timeline.tweets.len == 0:
      renderNoneFound()
    else:
      renderTweets(timeline)
      if timeline.hasMore or timeline.query.isSome:
        renderOlder(timeline, profile)
      else:
        renderNoMore()
