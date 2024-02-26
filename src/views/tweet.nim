# SPDX-License-Identifier: AGPL-3.0-only
import strutils, sequtils, strformat, options, algorithm
import karax/[karaxdsl, vdom, vstyles]
from jester import Request

import renderutils
import ".."/[types, utils, formatters]
import general

const doctype = "<!DOCTYPE html>\n"

proc renderMiniAvatar(user: User; prefs: Prefs): VNode =
  let url = getPicUrl(user.getUserPic("_mini"))
  buildHtml():
    img(class=(prefs.getAvatarClass & " mini"), src=url)

proc renderHeader(tweet: Tweet; retweet: string; pinned: bool; prefs: Prefs): VNode =
  buildHtml(tdiv):
    if pinned:
      tdiv(class="pinned"):
        span: icon "pin", "Pinned Tweet"
    elif retweet.len > 0:
      tdiv(class="retweet-header"):
        span: icon "retweet", retweet & " retweeted"

    tdiv(class="tweet-header"):
      a(class="tweet-avatar", href=("/" & tweet.user.username)):
        var size = "_bigger"
        if not prefs.autoplayGifs and tweet.user.userPic.endsWith("gif"):
          size = "_400x400"
        genImg(tweet.user.getUserPic(size), class=prefs.getAvatarClass)

      tdiv(class="tweet-name-row"):
        tdiv(class="fullname-and-username"):
          linkUser(tweet.user, class="fullname")
          linkUser(tweet.user, class="username")

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
              small = if named: photo else: photo & smallWebp
            a(href=getOrigPicUrl(photo), class="still-image", target="_blank"):
              genImg(small)

proc isPlaybackEnabled(prefs: Prefs; playbackType: VideoType): bool =
  case playbackType
  of mp4: prefs.mp4Playback
  of m3u8, vmap: prefs.hlsPlayback

proc hasMp4Url(video: Video): bool =
  video.variants.anyIt(it.contentType == mp4)

proc renderVideoDisabled(playbackType: VideoType; path: string): VNode =
  buildHtml(tdiv(class="video-overlay")):
    case playbackType
    of mp4:
      p: text "mp4 playback disabled in preferences"
    of m3u8, vmap:
      buttonReferer "/enablehls", "Enable hls playback", path

proc renderVideoUnavailable(video: Video): VNode =
  buildHtml(tdiv(class="video-overlay")):
    case video.reason
    of "dmcaed":
      p: text "This media has been disabled in response to a report by the copyright owner"
    else:
      p: text "This media is unavailable"

proc renderVideo*(video: Video; prefs: Prefs; path: string): VNode =
  let
    container = if video.description.len == 0 and video.title.len == 0: ""
                else: " card-container"
    playbackType = if not prefs.proxyVideos and video.hasMp4Url: mp4
                   else: video.playbackType

  buildHtml(tdiv(class="attachments card")):
    tdiv(class="gallery-video" & container):
      tdiv(class="attachment video-container"):
        let thumb = getSmallPic(video.thumb)
        if not video.available:
          img(src=thumb)
          renderVideoUnavailable(video)
        elif not prefs.isPlaybackEnabled(playbackType):
          img(src=thumb)
          renderVideoDisabled(playbackType, path)
        else:
          let
            vars = video.variants.filterIt(it.contentType == playbackType)
            vidUrl = vars.sortedByIt(it.resolution)[^1].url
            source = if prefs.proxyVideos: getVidUrl(vidUrl)
                     else: vidUrl
          case playbackType
          of mp4:
            video(poster=thumb, controls="", muted=prefs.muteVideos):
              source(src=source, `type`="video/mp4")
          of m3u8, vmap:
            video(poster=thumb, data-url=source, data-autoload="false", muted=prefs.muteVideos)
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
        video(class="gif", poster=getSmallPic(gif.thumb), autoplay=prefs.autoplayGifs,
              controls="", muted="", loop=""):
          source(src=getPicUrl(gif.url), `type`="video/mp4")

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
      text &"{insertSep($poll.votes, ',')} votes • {poll.status}"

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
  let url = replaceUrls(card.url, prefs)

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

func formatStat(stat: int): string =
  if stat > 0: insertSep($stat, ',')
  else: ""

proc renderStats(stats: TweetStats; views: string): VNode =
  buildHtml(tdiv(class="tweet-stats")):
    span(class="tweet-stat"): icon "comment", formatStat(stats.replies)
    span(class="tweet-stat"): icon "retweet", formatStat(stats.retweets)
    span(class="tweet-stat"): icon "quote", formatStat(stats.quotes)
    span(class="tweet-stat"): icon "heart", formatStat(stats.likes)
    if views.len > 0:
      span(class="tweet-stat"): icon "play", insertSep(views, ',')

proc renderReply(tweet: Tweet): VNode =
  buildHtml(tdiv(class="replying-to")):
    text "Replying to "
    for i, u in tweet.reply:
      if i > 0: text " "
      a(href=("/" & u)): text "@" & u

proc renderAttribution(user: User; prefs: Prefs): VNode =
  buildHtml(a(class="attribution", href=("/" & user.username))):
    renderMiniAvatar(user, prefs)
    strong: text user.fullname
    verifiedIcon(user)

proc renderMediaTags(tags: seq[User]): VNode =
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
        renderMiniAvatar(quote.user, prefs)
        linkUser(quote.user, class="fullname")
        linkUser(quote.user, class="username")

      span(class="tweet-date"):
        a(href=getLink(quote), title=quote.getTime):
          text quote.getShortTime

    if quote.reply.len > 0:
      renderReply(quote)

    if quote.text.len > 0:
      tdiv(class="quote-text", dir="auto"):
        verbatim replaceUrls(quote.text, prefs)

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

  let
    fullTweet = tweet
    pinned = tweet.pinned

  var retweet: string
  var tweet = fullTweet
  if tweet.retweet.isSome:
    tweet = tweet.retweet.get
    retweet = fullTweet.user.fullname

  buildHtml(tdiv(class=("timeline-item " & divClass))):
    if not mainTweet:
      a(class="tweet-link", href=getLink(tweet))

    tdiv(class="tweet-body"):
      var views = ""
      renderHeader(tweet, retweet, pinned, prefs)

      if not afterTweet and index == 0 and tweet.reply.len > 0 and
         (tweet.reply.len > 1 or tweet.reply[0] != tweet.user.username):
        renderReply(tweet)

      var tweetClass = "tweet-content media-body"
      if prefs.bidiSupport:
        tweetClass &= " tweet-bidi"

      tdiv(class=tweetClass, dir="auto"):
        verbatim replaceUrls(tweet.text, prefs) & renderLocation(tweet)

      if tweet.attribution.isSome:
        renderAttribution(tweet.attribution.get(), prefs)

      if tweet.card.isSome and tweet.card.get().kind != hidden:
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
        p(class="tweet-published"): text &"{getTime(tweet)}"

      if tweet.mediaTags.len > 0:
        renderMediaTags(tweet.mediaTags)

      if not prefs.hideTweetStats:
        renderStats(tweet.stats, views)

      if showThread:
        a(class="show-thread", href=("/i/status/" & $tweet.threadId)):
          text "Show this thread"

proc renderTweetEmbed*(tweet: Tweet; path: string; prefs: Prefs; cfg: Config; req: Request): string =
  let node = buildHtml(html(lang="en")):
    renderHead(prefs, cfg, req)

    body:
      tdiv(class="tweet-embed"):
        renderTweet(tweet, prefs, path, mainTweet=true)

  result = doctype & $node
