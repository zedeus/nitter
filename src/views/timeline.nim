# SPDX-License-Identifier: AGPL-3.0-only
import strutils, strformat, algorithm, uri, options
import karax/[karaxdsl, vdom]

import ".."/[types, query, formatters]
import tweet, renderutils

proc timelineViewClass(query: Query): string =
  if query.kind != QueryKind.media:
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

proc renderMore*(query: Query; cursor: string; focus=""; extra=""): VNode =
  buildHtml(tdiv(class="show-more")):
    a(href=(&"?{extra}{getQuery(query)}cursor={encodeUrl(cursor, usePlus=false)}{focus}")):
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

proc mentionUsername(word: string): string =
  # "@user" -> "user" for well-formed mentions, "" otherwise
  if word.len > 1 and word[0] == '@' and
     word[1 .. ^1].allCharsInSet({'A'..'Z', 'a'..'z', '0'..'9', '_'}):
    word[1 .. ^1]
  else: ""

proc mentionedUser(s: string): string =
  # last @mention in strings like "65 followers including @user"
  let words = s.split(' ')
  for i in countdown(words.high, 0):
    result = mentionUsername(words[i])
    if result.len > 0: return

proc renderMentionedText(s: string): VNode =
  # linkify @mentions in plain API strings like "65 followers including @user"
  let words = s.split(' ')
  buildHtml(span):
    for i in 0 ..< words.len:
      if i > 0: text " "
      let username = mentionUsername(words[i])
      if username.len > 0:
        a(href=("/" & username)): text words[i]
      else:
        text words[i]

proc renderListCard(r: ListSearchResult): VNode =
  let listUrl = "/i/lists/" & r.list.id
  buildHtml(tdiv(class="timeline-item list-result")):
    a(class="tweet-link", href=listUrl)
    a(class="list-result-banner", href=listUrl):
      if r.list.banner.len > 0:
        genImg(r.list.banner)
    tdiv(class="list-result-body"):
      tdiv(class="list-result-title fullname-and-username"):
        a(class="list-name fullname", href=listUrl): text r.list.name
        span(class="list-members"):
          text &"· {insertSep($r.list.members, ',')} members"
      tdiv(class="list-result-context"):
        if r.followersContext.len > 0:
          # the first facepile belongs to the "including @user" account
          let mentioned = mentionedUser(r.followersContext)
          for i in 0 ..< r.facepiles.len:
            if i == 0 and mentioned.len > 0:
              a(class="facepile-link", href=("/" & mentioned)):
                genImg(r.facepiles[i], class="list-facepile")
            else:
              genImg(r.facepiles[i], class="list-facepile")
          renderMentionedText(r.followersContext)
        else:
          if r.owner.username.len > 0:
            a(class="facepile-link", href=("/" & r.owner.username)):
              genImg(r.owner.getUserPic("_mini"), class="list-facepile")
          else:
            genImg(r.owner.getUserPic("_mini"), class="list-facepile")
          linkUser(r.owner, class="fullname")
          linkUser(r.owner, class="username")
      if r.list.description.len > 0:
        tdiv(class="list-result-description"):
          text r.list.description

proc renderTimelineLists*(results: Result[ListSearchResult]; prefs: Prefs;
                          path=""): VNode =
  buildHtml(tdiv(class="timeline")):
    if not results.beginning:
      renderNewer(results.query, path)

    if results.content.len > 0:
      for list in results.content:
        renderListCard(list)
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
          if thread.len == 1:
            renderTweet(thread[0], prefs, path)
          else: renderThread(thread, prefs, path)

      var cursor = getSearchMaxId(results, path)
      if cursor.len > 0:
        renderMore(results.query, cursor)
      elif results.bottom.len > 0:
        renderMore(results.query, results.bottom)
      renderToTop()
