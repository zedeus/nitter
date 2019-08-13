import strutils, sequtils
import karax/[karaxdsl, vdom, vstyles]

import ../types, ../utils, ../formatters
import renderutils

proc renderHeader(tweet: Tweet): VNode =
  buildHtml(tdiv):
    if tweet.retweet.isSome:
      tdiv(class="retweet"):
        span: text "🔄 " & get(tweet.retweet).by & " retweeted"
    if tweet.pinned:
      tdiv(class="pinned"):
        span: text "📌 Pinned Tweet"

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
    class = if groups.len == 1 and groups[0].len == 1: "single-image"
            else: ""

  buildHtml(tdiv(class=("attachments " & class))):
    for i, photos in groups:
      let margin = if i > 0: ".25em" else: ""
      let flex = if photos.len > 1 or groups.len > 1: "flex" else: "block"
      tdiv(class="gallery-row", style={marginTop: margin}):
        for photo in photos:
          tdiv(class="attachment image"):
            a(href=getSigUrl(photo & "?name=orig", "pic"), class="still-image",
              target="_blank", style={display: flex}):
              genImg(photo)

proc renderVideo(video: Video; prefs: Prefs): VNode =
  buildHtml(tdiv(class="attachments")):
    tdiv(class="gallery-video"):
      tdiv(class="attachment video-container"):
        let thumb = video.thumb.getSigUrl("pic")
        case video.playbackType
        of mp4:
          video(poster=thumb, controls=""):
            source(src=video.url.getSigUrl("video"), `type`="video/mp4")
        of m3u8, vmap:
          if prefs.videoPlayback:
            video(poster=thumb)
            tdiv(class="video-overlay"):
              p: text "Video playback not supported yet"
          else:
            img(src=thumb)
            tdiv(class="video-overlay"):
              p: text "Video playback disabled"

proc renderGif(gif: Gif; prefs: Prefs): VNode =
  buildHtml(tdiv(class="attachments media-gif")):
    tdiv(class="gallery-gif", style=style(maxHeight, "unset")):
      tdiv(class="attachment"):
        let thumb = gif.thumb.getSigUrl("pic")
        let url = gif.url.getSigUrl("video")
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
      img(src=get(card.image).getSigUrl("pic"))
      if card.kind == player:
        tdiv(class="card-overlay"):
          tdiv(class="card-overlay-circle"):
            span(class="card-overlay-triangle")

proc renderCard(card: Card; prefs: Prefs): VNode =
  const largeCards = {summaryLarge, liveEvent, promoWebsite, promoVideo}
  let large = if card.kind in largeCards: " large" else: ""

  buildHtml(tdiv(class=("card" & large))):
    a(class="card-container", href=card.url):
      if card.image.isSome:
        renderCardImage(card)
      elif card.video.isSome:
        renderVideo(get(card.video), prefs)

      tdiv(class="card-content-container"):
        tdiv(class="card-content"):
          h2(class="card-title"): text card.title
          p(class="card-description"): text card.text
          span(class="card-destination"): text card.dest

proc renderStats(stats: TweetStats): VNode =
  buildHtml(tdiv(class="tweet-stats")):
    span(class="tweet-stat"): text "💬 " & $stats.replies
    span(class="tweet-stat"): text "🔄 " & $stats.retweets
    span(class="tweet-stat"): text "👍 " & $stats.likes

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
        span(class="icon quote-sensitive-icon"): text "❗"

proc renderQuote(quote: Quote): VNode =
  if not quote.available:
    return buildHtml(tdiv(class="quote unavailable")):
      tdiv(class="unavailable-quote"):
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
      verbatim linkifyText(quote.text)

    if quote.hasThread:
      a(class="show-thread", href=getLink(quote)):
        text "Show this thread"

proc renderTweet*(tweet: Tweet; prefs: Prefs; class="";
                  index=0; total=(-1); last=false): VNode =
  var divClass = class
  if index == total or last:
    divClass = "thread-last " & class

  if not tweet.available:
    return buildHtml(tdiv(class=divClass)):
      tdiv(class="status-el unavailable"):
        tdiv(class="unavailable-box"):
          text "This tweet is unavailable"

  buildHtml(tdiv(class=divClass)):
    tdiv(class="status-el"):
      tdiv(class="status-body"):
        renderHeader(tweet)

        if index == 0 and tweet.reply.len > 0:
          renderReply(tweet)

        tdiv(class="status-content media-body"):
          verbatim linkifyText(tweet.text)

        if tweet.quote.isSome:
          renderQuote(tweet.quote.get())

        if tweet.card.isSome:
          renderCard(tweet.card.get(), prefs)
        elif tweet.photos.len > 0:
          renderAlbum(tweet)
        elif tweet.video.isSome:
          renderVideo(tweet.video.get(), prefs)
        elif tweet.gif.isSome:
          renderGif(tweet.gif.get(), prefs)
        elif tweet.poll.isSome:
          renderPoll(tweet.poll.get())

        renderStats(tweet.stats)

        if tweet.hasThread and "timeline" in class:
          a(class="show-thread", href=getLink(tweet)):
            text "Show this thread"
