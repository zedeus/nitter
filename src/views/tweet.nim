import strutils, sequtils, strformat, options
import karax/[karaxdsl, vdom, vstyles]

import renderutils
import ".."/[types, utils, formatters]

proc renderHeader(tweet: Tweet): VNode =
  buildHtml(tdiv):
    if tweet.retweet.isSome:
      tdiv(class="retweet-header"):
        span: icon "retweet", get(tweet.retweet).by & " retweeted"

    if tweet.pinned:
      tdiv(class="pinned"):
        span: icon "pin", "Pinned Tweet"

    tdiv(class="tweet-header"):
      a(class="tweet-avatar", href=("/" & tweet.profile.username)):
        genImg(tweet.profile.getUserpic("_bigger"), class="avatar")

      tdiv(class="tweet-name-row"):
        tdiv(class="fullname-and-username"):
          linkUser(tweet.profile, class="fullname")
          linkUser(tweet.profile, class="username")

        span(class="tweet-date"):
          a(href=getLink(tweet), title=tweet.getTime()):
            text tweet.shortTime

proc renderAlbum(tweet: Tweet): VNode =
  let
    groups = if tweet.photos.len < 3: @[tweet.photos]
             else: tweet.photos.distribute(2)

  if groups.len == 1 and groups[0].len == 1:
    buildHtml(tdiv(class="single-image")):
      tdiv(class="attachments gallery-row"):
        a(href=getPicUrl(groups[0][0] & "?name=orig"), class="still-image",
          target="_blank"):
            genImg(groups[0][0])
  else:
    buildHtml(tdiv(class="attachments")):
      for i, photos in groups:
        let margin = if i > 0: ".25em" else: ""
        let flex = if photos.len > 1 or groups.len > 1: "flex" else: "block"
        tdiv(class="gallery-row", style={marginTop: margin}):
          for photo in photos:
            tdiv(class="attachment image"):
              a(href=getPicUrl(photo & "?name=orig"), class="still-image",
                target="_blank", style={display: flex}):
                genImg(photo)

proc isPlaybackEnabled(prefs: Prefs; video: Video): bool =
  case video.playbackType
  of mp4: prefs.mp4Playback
  of m3u8, vmap: prefs.hlsPlayback

proc renderVideoDisabled(video: Video; path: string): VNode =
  buildHtml(tdiv):
    img(src=getPicUrl(video.thumb))
    tdiv(class="video-overlay"):
      case video.playbackType
      of mp4:
        p: text "mp4 playback disabled in preferences"
      of m3u8, vmap:
        buttonReferer "/enablehls", "Enable hls playback", path

proc renderVideoUnavailable(video: Video): VNode =
  buildHtml(tdiv):
    img(src=getPicUrl(video.thumb))
    tdiv(class="video-overlay"):
      case video.reason
      of "dmcaed":
        p: text "This media has been disabled in response to a report by the copyright owner"
      else:
        p: text "This media is unavailable"

proc renderVideo(video: Video; prefs: Prefs; path: string): VNode =
  let container =
    if video.description.len > 0 or video.title.len > 0: " card-container"
    else: ""
  buildHtml(tdiv(class="attachments")):
    tdiv(class="gallery-video" & container):
      tdiv(class="attachment video-container"):
        let thumb = getPicUrl(video.thumb)
        if not video.available:
          renderVideoUnavailable(video)
        elif not prefs.isPlaybackEnabled(video):
          renderVideoDisabled(video, path)
        else:
          let source = getVidUrl(video.url)
          case video.playbackType
          of mp4:
            if prefs.muteVideos:
              video(poster=thumb, controls="", muted=""):
                source(src=source, `type`="video/mp4")
            else:
              video(poster=thumb, controls=""):
                source(src=source, `type`="video/mp4")
          of m3u8, vmap:
            video(poster=thumb, data-url=source, data-autoload="false")
            verbatim "<div class=\"video-overlay\" onclick=\"playVideo(this)\">"
            verbatim "<div class=\"overlay-circle\">"
            verbatim "<span class=\"overlay-triangle\"</span></div></div>"
      if container.len > 0:
        tdiv(class="card-content"):
          h2(class="card-title"): text video.title
          if video.description.len > 0:
            p(class="card-description"): text video.description

proc renderGif(gif: Gif; prefs: Prefs): VNode =
  buildHtml(tdiv(class="attachments media-gif")):
    tdiv(class="gallery-gif", style=style(maxHeight, "unset")):
      tdiv(class="attachment"):
        let thumb = getPicUrl(gif.thumb)
        let url = getGifUrl(gif.url)
        if prefs.autoplayGifs:
          video(class="gif", poster=thumb, autoplay="", muted="", loop=""):
            source(src=url, `type`="video/mp4")
        else:
          video(class="gif", poster=thumb, controls="", muted="", loop=""):
            source(src=url, `type`="video/mp4")

proc renderPoll(poll: Poll): VNode =
  buildHtml(tdiv(class="poll")):
    for i in 0 ..< poll.options.len:
      let leader = if poll.leader == i: " leader" else: ""
      let perc = $poll.values[i] & "%"
      tdiv(class=("poll-meter" & leader)):
        span(class="poll-choice-bar", style=style(width, perc))
        span(class="poll-choice-value"): text perc
        span(class="poll-choice-option"): text poll.options[i]
    span(class="poll-info"):
      text $poll.votes & " votes • " & poll.status

proc renderCardImage(card: Card): VNode =
  buildHtml(tdiv(class="card-image-container")):
    tdiv(class="card-image"):
      img(src=getPicUrl(get(card.image)))
      if card.kind == player:
        tdiv(class="card-overlay"):
          tdiv(class="overlay-circle"):
            span(class="overlay-triangle")

proc renderCardContent(card: Card): VNode =
  buildHtml(tdiv(class="card-content")):
    h2(class="card-title"): text card.title
    p(class="card-description"): text card.text
    span(class="card-destination"): text card.dest

proc renderCard(card: Card; prefs: Prefs; path: string): VNode =
  const largeCards = {summaryLarge, liveEvent, promoWebsite, promoVideo}
  let large = if card.kind in largeCards: " large" else: ""
  let url = replaceUrl(card.url, prefs)

  buildHtml(tdiv(class=("card" & large))):
    if card.video.isSome:
      tdiv(class="card-container"):
        renderVideo(get(card.video), prefs, path)
        a(class="card-content-container", href=url):
          renderCardContent(card)
    else:
      a(class="card-container", href=url):
        if card.image.isSome:
          renderCardImage(card)
        tdiv(class="card-content-container"):
          renderCardContent(card)

proc renderStats(stats: TweetStats; views: string): VNode =
  buildHtml(tdiv(class="tweet-stats")):
    span(class="tweet-stat"): icon "comment", $stats.replies
    span(class="tweet-stat"): icon "retweet", $stats.retweets
    span(class="tweet-stat"): icon "heart", $stats.likes
    if views.len > 0:
      span(class="tweet-stat"): icon "play", views

proc renderReply(tweet: Tweet): VNode =
  buildHtml(tdiv(class="replying-to")):
    text "Replying to "
    for i, u in tweet.reply:
      if i > 0: text " "
      a(href=("/" & u)): text "@" & u

proc renderReply(quote: Quote): VNode =
  buildHtml(tdiv(class="replying-to")):
    text "Replying to "
    for i, u in quote.reply:
      if i > 0: text " "
      a(href=("/" & u)): text "@" & u

proc renderQuoteMedia(quote: Quote): VNode =
  buildHtml(tdiv(class="quote-media-container")):
    if quote.thumb.len > 0:
      tdiv(class="quote-media"):
        genImg(quote.thumb)
        if quote.badge.len > 0:
          tdiv(class="quote-badge"):
            tdiv(class="quote-badge-text"): text quote.badge
    elif quote.sensitive:
      tdiv(class="quote-sensitive"):
        icon "attention", class="quote-sensitive-icon"

proc renderQuote(quote: Quote; prefs: Prefs): VNode =
  if not quote.available:
    return buildHtml(tdiv(class="quote unavailable")):
      tdiv(class="unavailable-quote"):
        if quote.tombstone.len > 0:
          text quote.tombstone
        else:
          text "This tweet is unavailable"

  buildHtml(tdiv(class="quote")):
    a(class="quote-link", href=getLink(quote))

    if quote.thumb.len > 0 or quote.sensitive:
      renderQuoteMedia(quote)

    tdiv(class="fullname-and-username"):
      linkUser(quote.profile, class="fullname")
      linkUser(quote.profile, class="username")

    if quote.reply.len > 0:
      renderReply(quote)

    tdiv(class="quote-text"):
      verbatim replaceUrl(quote.text, prefs)

    if quote.hasThread:
      a(class="show-thread", href=getLink(quote)):
        text "Show this thread"

proc renderTweet*(tweet: Tweet; prefs: Prefs; path: string; class="";
                  index=0; total=(-1); last=false; showThread=false;
                  mainTweet=false): VNode =
  var divClass = class
  if index == total or last:
    divClass = "thread-last " & class

  if not tweet.available:
    return buildHtml(tdiv(class=divClass & "unavailable timeline-item")):
      tdiv(class="unavailable-box"):
        if tweet.tombstone.len > 0:
          text tweet.tombstone
        else:
          text "This tweet is unavailable"

  buildHtml(tdiv(class=("timeline-item " & divClass))):
    if not mainTweet:
      a(class="tweet-link", href=getLink(tweet))

    tdiv(class="tweet-body"):
      var views = ""
      renderHeader(tweet)

      if index == 0 and tweet.reply.len > 0:
        renderReply(tweet)

      tdiv(class="tweet-content media-body", dir="auto"):
        verbatim replaceUrl(tweet.text, prefs)

      if tweet.quote.isSome:
        renderQuote(tweet.quote.get(), prefs)

      if tweet.card.isSome:
        renderCard(tweet.card.get(), prefs, path)
      elif tweet.photos.len > 0:
        renderAlbum(tweet)
      elif tweet.video.isSome:
        renderVideo(tweet.video.get(), prefs, path)
        views = tweet.video.get().views
      elif tweet.gif.isSome:
        renderGif(tweet.gif.get(), prefs)
      elif tweet.poll.isSome:
        renderPoll(tweet.poll.get())

      if mainTweet:
        p(class="tweet-published"): text getTweetTime(tweet)

      if not prefs.hideTweetStats:
        renderStats(tweet.stats, views)

      if showThread:
        a(class="show-thread", href=("/i/status/" & $tweet.threadId)):
          text "Show this thread"
