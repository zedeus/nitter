import strutils, sequtils, strformat, options
import karax/[karaxdsl, vdom, vstyles]

import renderutils
import ".."/[types, utils, formatters]

proc getSmallPic(url: string): string =
  result = url
  if "?" notin url:
    result &= ":small"
  result = getPicUrl(result)

proc renderMiniAvatar(profile: Profile): VNode =
  let url = getPicUrl(profile.getUserpic("_mini"))
  buildHtml():
    img(class="avatar mini", src=url)

proc renderHeader(tweet: Tweet; retweet: string; prefs: Prefs): VNode =
  buildHtml(tdiv):
    if retweet.len > 0:
      tdiv(class="retweet-header"):
        span: icon "retweet", retweet & " retweeted"

    if tweet.pinned:
      tdiv(class="pinned"):
        span: icon "pin", "Pinned Tweet"

    tdiv(class="tweet-header"):
      a(class="tweet-avatar", href=("/" & tweet.profile.username)):
        var size = "_bigger"
        if not prefs.autoplayGifs and tweet.profile.userpic.endsWith("gif"):
          size = "_400x400"
        genImg(tweet.profile.getUserpic(size), class="avatar")

      tdiv(class="tweet-name-row"):
        tdiv(class="fullname-and-username"):
          linkUser(tweet.profile, class="fullname")
          linkUser(tweet.profile, class="username")

        span(class="tweet-date"):
          a(href=getLink(tweet), title=tweet.getTime):
            text tweet.getShortTime

proc renderAlbum(tweet: Tweet): VNode =
  let
    groups = if tweet.photos.len < 3: @[tweet.photos]
             else: tweet.photos.distribute(2)

  buildHtml(tdiv(class="attachments")):
    for i, photos in groups:
      let margin = if i > 0: ".25em" else: ""
      tdiv(class="gallery-row", style={marginTop: margin}):
        for photo in photos:
          tdiv(class="attachment image"):
            let
              named = "name=" in photo
              orig = if named: photo else: photo & "?name=orig"
              small = if named: photo else: photo & "?name=small"
            a(href=getPicUrl(orig), class="still-image", target="_blank"):
              genImg(small)

proc isPlaybackEnabled(prefs: Prefs; video: Video): bool =
  case video.playbackType
  of mp4: prefs.mp4Playback
  of m3u8, vmap: prefs.hlsPlayback

proc renderVideoDisabled(video: Video; path: string): VNode =
  buildHtml(tdiv):
    img(src=getSmallPic(video.thumb))
    tdiv(class="video-overlay"):
      case video.playbackType
      of mp4:
        p: text "mp4 playback disabled in preferences"
      of m3u8, vmap:
        buttonReferer "/enablehls", "Enable hls playback", path

proc renderVideoUnavailable(video: Video): VNode =
  buildHtml(tdiv):
    img(src=getSmallPic(video.thumb))
    tdiv(class="video-overlay"):
      case video.reason
      of "dmcaed":
        p: text "This media has been disabled in response to a report by the copyright owner"
      else:
        p: text "This media is unavailable"

proc renderVideo*(video: Video; prefs: Prefs; path: string): VNode =
  let container =
    if video.description.len > 0 or video.title.len > 0: " card-container"
    else: ""
  buildHtml(tdiv(class="attachments card")):
    tdiv(class="gallery-video" & container):
      tdiv(class="attachment video-container"):
        let thumb = getSmallPic(video.thumb)
        if not video.available:
          renderVideoUnavailable(video)
        elif not prefs.isPlaybackEnabled(video):
          renderVideoDisabled(video, path)
        else:
          let vid = video.variants.filterIt(it.videoType == video.playbackType)
          let source = getVidUrl(vid[0].url)
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
            tdiv(class="overlay-circle"): span(class="overlay-triangle")
            verbatim "</div>"
      if container.len > 0:
        tdiv(class="card-content"):
          h2(class="card-title"): text video.title
          if video.description.len > 0:
            p(class="card-description"): text video.description

proc renderGif(gif: Gif; prefs: Prefs): VNode =
  buildHtml(tdiv(class="attachments media-gif")):
    tdiv(class="gallery-gif", style={maxHeight: "unset"}):
      tdiv(class="attachment"):
        let thumb = getSmallPic(gif.thumb)
        let url = getPicUrl(gif.url)
        if prefs.autoplayGifs:
          video(class="gif", poster=thumb, controls="", autoplay="", muted="", loop=""):
            source(src=url, `type`="video/mp4")
        else:
          video(class="gif", poster=thumb, controls="", muted="", loop=""):
            source(src=url, `type`="video/mp4")

proc renderPoll(poll: Poll): VNode =
  buildHtml(tdiv(class="poll")):
    for i in 0 ..< poll.options.len:
      let
        leader = if poll.leader == i: " leader" else: ""
        val = poll.values[i]
        perc = if val > 0: val / poll.votes * 100 else: 0
        percStr = (&"{perc:>3.0f}").strip(chars={'.'}) & '%'
      tdiv(class=("poll-meter" & leader)):
        span(class="poll-choice-bar", style={width: percStr})
        span(class="poll-choice-value"): text percStr
        span(class="poll-choice-option"): text poll.options[i]
    span(class="poll-info"):
      text insertSep($poll.votes, ',') & " votes • " & poll.status

proc renderCardImage(card: Card): VNode =
  buildHtml(tdiv(class="card-image-container")):
    tdiv(class="card-image"):
      img(src=getPicUrl(card.image), alt="")
      if card.kind == player:
        tdiv(class="card-overlay"):
          tdiv(class="overlay-circle"):
            span(class="overlay-triangle")

proc renderCardContent(card: Card): VNode =
  buildHtml(tdiv(class="card-content")):
    h2(class="card-title"): text card.title
    if card.text.len > 0:
      p(class="card-description"): text card.text
    if card.dest.len > 0:
      span(class="card-destination"): text card.dest

proc renderCard(card: Card; prefs: Prefs; path: string): VNode =
  const smallCards = {app, player, summary, storeLink}
  let large = if card.kind notin smallCards: " large" else: ""
  let url = replaceUrl(card.url, prefs)

  buildHtml(tdiv(class=("card" & large))):
    if card.video.isSome:
      tdiv(class="card-container"):
        renderVideo(get(card.video), prefs, path)
        a(class="card-content-container", href=url):
          renderCardContent(card)
    else:
      a(class="card-container", href=url):
        if card.image.len > 0:
          renderCardImage(card)
        tdiv(class="card-content-container"):
          renderCardContent(card)

proc renderStats(stats: TweetStats; views: string): VNode =
  buildHtml(tdiv(class="tweet-stats")):
    span(class="tweet-stat"): icon "comment", insertSep($stats.replies, ',')
    span(class="tweet-stat"): icon "retweet", insertSep($stats.retweets, ',')
    span(class="tweet-stat"): icon "quote", insertSep($stats.quotes, ',')
    span(class="tweet-stat"): icon "heart", insertSep($stats.likes, ',')
    if views.len > 0:
      span(class="tweet-stat"): icon "play", insertSep(views, ',')

proc renderReply(tweet: Tweet): VNode =
  buildHtml(tdiv(class="replying-to")):
    text "Replying to "
    for i, u in tweet.reply:
      if i > 0: text " "
      a(href=("/" & u)): text "@" & u

proc renderAttribution(profile: Profile): VNode =
  buildHtml(a(class="attribution", href=("/" & profile.username))):
    renderMiniAvatar(profile)
    strong: text profile.fullname

proc renderMediaTags(tags: seq[Profile]): VNode =
  buildHtml(tdiv(class="media-tag-block")):
    icon "user"
    for i, p in tags:
      a(class="media-tag", href=("/" & p.username), title=p.username):
        text p.fullname
      if i < tags.high:
        text ", "

proc renderQuoteMedia(quote: Tweet; prefs: Prefs; path: string): VNode =
  buildHtml(tdiv(class="quote-media-container")):
    if quote.photos.len > 0:
      renderAlbum(quote)
    elif quote.video.isSome:
      renderVideo(quote.video.get(), prefs, path)
    elif quote.gif.isSome:
      renderGif(quote.gif.get(), prefs)

proc renderQuote(quote: Tweet; prefs: Prefs; path: string): VNode =
  if not quote.available:
    return buildHtml(tdiv(class="quote unavailable")):
      tdiv(class="unavailable-quote"):
        if quote.tombstone.len > 0:
          text quote.tombstone
        elif quote.text.len > 0:
          text quote.text
        else:
          text "This tweet is unavailable"

  buildHtml(tdiv(class="quote quote-big")):
    a(class="quote-link", href=getLink(quote))

    tdiv(class="tweet-name-row"):
      tdiv(class="fullname-and-username"):
        renderMiniAvatar(quote.profile)
        linkUser(quote.profile, class="fullname")
        linkUser(quote.profile, class="username")

      span(class="tweet-date"):
        a(href=getLink(quote), title=quote.getTime):
          text quote.getShortTime

    if quote.reply.len > 0:
      renderReply(quote)

    if quote.text.len > 0:
      tdiv(class="quote-text", dir="auto"):
        verbatim replaceUrl(quote.text, prefs)

    if quote.hasThread:
      a(class="show-thread", href=getLink(quote)):
        text "Show this thread"

    if quote.photos.len > 0 or quote.video.isSome or quote.gif.isSome:
      renderQuoteMedia(quote, prefs, path)

proc renderLocation*(tweet: Tweet): string =
  let (place, url) = tweet.getLocation()
  if place.len == 0: return
  let node = buildHtml(span(class="tweet-geo")):
    text " – at "
    if url.len > 1:
      a(href=url): text place
    else:
      text place
  return $node

proc renderTweet*(tweet: Tweet; prefs: Prefs; path: string; class=""; index=0;
                  last=false; showThread=false; mainTweet=false; afterTweet=false): VNode =
  var divClass = class
  if index == -1 or last:
    divClass = "thread-last " & class

  if not tweet.available:
    return buildHtml(tdiv(class=divClass & "unavailable timeline-item")):
      tdiv(class="unavailable-box"):
        if tweet.tombstone.len > 0:
          text tweet.tombstone
        elif tweet.text.len > 0:
          text tweet.text
        else:
          text "This tweet is unavailable"

      if tweet.quote.isSome:
        renderQuote(tweet.quote.get(), prefs, path)

  let fullTweet = tweet
  var retweet: string
  var tweet = fullTweet
  if tweet.retweet.isSome:
    tweet = tweet.retweet.get
    retweet = fullTweet.profile.fullname

  buildHtml(tdiv(class=("timeline-item " & divClass))):
    if not mainTweet:
      a(class="tweet-link", href=getLink(tweet))

    tdiv(class="tweet-body"):
      var views = ""
      renderHeader(tweet, retweet, prefs)

      if not afterTweet and index == 0 and tweet.reply.len > 0 and
         (tweet.reply.len > 1 or tweet.reply[0] != tweet.profile.username):
        renderReply(tweet)

      var tweetClass = "tweet-content media-body"
      if prefs.bidiSupport:
        tweetClass &= " tweet-bidi"

      tdiv(class=tweetClass, dir="auto"):
        verbatim replaceUrl(tweet.text, prefs) & renderLocation(tweet)

      if tweet.attribution.isSome:
        renderAttribution(tweet.attribution.get())

      if tweet.card.isSome:
        renderCard(tweet.card.get(), prefs, path)

      if tweet.photos.len > 0:
        renderAlbum(tweet)
      elif tweet.video.isSome:
        renderVideo(tweet.video.get(), prefs, path)
        views = tweet.video.get().views
      elif tweet.gif.isSome:
        renderGif(tweet.gif.get(), prefs)
        views = "GIF"

      if tweet.poll.isSome:
        renderPoll(tweet.poll.get())

      if tweet.quote.isSome:
        renderQuote(tweet.quote.get(), prefs, path)

      if mainTweet:
        p(class="tweet-published"): text getTweetTime(tweet)

      if tweet.mediaTags.len > 0:
        renderMediaTags(tweet.mediaTags)

      if not prefs.hideTweetStats:
        renderStats(tweet.stats, views)

      if showThread:
        a(class="show-thread", href=("/i/status/" & $tweet.threadId)):
          text "Show this thread"
