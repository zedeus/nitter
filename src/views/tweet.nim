# SPDX-License-Identifier: AGPL-3.0-only
import strutils, sequtils, strformat, options, algorithm
import karax/[karaxdsl, vdom, vstyles]
from jester import Request

import renderutils
import ".."/[types, utils, formatters]
import general

const doctype = "<!DOCTYPE html>\n"

proc renderMiniAvatar(user: User; prefs: Prefs): VNode =
  genImg(user.getUserPic("_mini"), class=(prefs.getAvatarClass & " mini"))

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
          verifiedIcon(tweet.user)
          linkUser(tweet.user, class="username")

        span(class="tweet-date"):
          a(href=getLink(tweet), title=tweet.getTime):
            text tweet.getShortTime

proc renderAltText(altText: string): VNode =
  buildHtml(p(class="alt-text")):
    text "ALT  " & altText

proc renderPhotoAttachment(photo: Photo): VNode =
  buildHtml(tdiv(class="attachment")):
    let
      named = "name=" in photo.url
      small = if named: photo.url else: photo.url & smallWebp
    a(href=getOrigPicUrl(photo.url), class="still-image", target="_blank"):
      genImg(small, alt=photo.altText)
    if photo.altText.len > 0:
      renderAltText(photo.altText)

proc isPlaybackEnabled(prefs: Prefs; playbackType: VideoType): bool =
  case playbackType
  of mp4: prefs.mp4Playback
  of m3u8, vmap: prefs.hlsPlayback

proc hasMp4Url(video: Video): bool =
  video.variants.anyIt(it.contentType == mp4)

proc renderVideoDisabled(playbackType: VideoType; path=""): VNode =
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

proc renderVideoAttachment(videoData: Video; prefs: Prefs; path=""): VNode =
  let
    playbackType = if not prefs.proxyVideos and videoData.hasMp4Url: mp4
                   else: videoData.playbackType
    thumb = getSmallPic(videoData.thumb)

  buildHtml(tdiv(class="attachment")):
    if not videoData.available:
      img(src=thumb, loading="lazy")
      renderVideoUnavailable(videoData)
    elif not prefs.isPlaybackEnabled(playbackType):
      img(src=thumb, loading="lazy")
      renderVideoDisabled(playbackType, path)
    else:
      let
        vars = videoData.variants.filterIt(it.contentType == playbackType)
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
        tdiv(class="overlay-duration"): text getDuration(videoData)
        verbatim "</div>"

proc renderVideo*(video: Video; prefs: Prefs; path: string): VNode =
  let hasCardContent = video.description.len > 0 or video.title.len > 0

  buildHtml(tdiv(class="attachments card")):
    tdiv(class=("gallery-video" & (if hasCardContent: " card-container" else: ""))):
      renderVideoAttachment(video, prefs, path)
      if hasCardContent:
        tdiv(class="card-content"):
          h2(class="card-title"): text video.title
          if video.description.len > 0:
            p(class="card-description"): text video.description

proc renderGifAttachment(gif: Gif; prefs: Prefs): VNode =
  let thumb = getSmallPic(gif.thumb)

  buildHtml(tdiv(class="attachment")):
    if not prefs.mp4Playback:
      img(src=thumb, loading="lazy")
      renderVideoDisabled(mp4)
    elif prefs.autoplayGifs:
      video(class="gif", poster=thumb, autoplay="", muted="", loop=""):
        source(src=getPicUrl(gif.url), `type`="video/mp4")
    else:
      video(class="gif", poster=thumb, controls="", muted="", loop=""):
        source(src=getPicUrl(gif.url), `type`="video/mp4")
    if gif.altText.len > 0:
      renderAltText(gif.altText)

proc renderGif(gif: Gif; prefs: Prefs): VNode =
  buildHtml(tdiv(class="attachments media-gif")):
    renderGifAttachment(gif, prefs)

proc renderMedia(media: seq[Media]; prefs: Prefs; path: string): VNode =
  if media.len == 0:
    return nil

  if media.len == 1:
    let item = media[0]
    if item.kind == videoMedia:
      return renderVideo(item.video, prefs, path)
    if item.kind == gifMedia:
      return renderGif(item.gif, prefs)

  let
    groups = if media.len < 3: @[media]
             else: media.distribute(2)

  buildHtml(tdiv(class="attachments")):
    for i, mediaGroup in groups:
      let margin = if i > 0: ".25em" else: ""
      let rowClass = "gallery-row" &
                     (if mediaGroup.allIt(it.kind == photoMedia): "" else: " mixed-row")
      tdiv(class=rowClass, style={marginTop: margin}):
        for mediaItem in mediaGroup:
          case mediaItem.kind
          of photoMedia:
            renderPhotoAttachment(mediaItem.photo)
          of videoMedia:
            renderVideoAttachment(mediaItem.video, prefs, path)
          of gifMedia:
            renderGifAttachment(mediaItem.gif, prefs)

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
      genImg(card.image)
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

proc renderStats(stats: TweetStats): VNode =
  buildHtml(tdiv(class="tweet-stats")):
    span(class="tweet-stat"): icon "comment", formatStat(stats.replies)
    span(class="tweet-stat"): icon "retweet", formatStat(stats.retweets)
    span(class="tweet-stat"): icon "heart", formatStat(stats.likes)
    span(class="tweet-stat"): icon "views", formatStat(stats.views)

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

proc renderLatestPost(username: string; id: int64): VNode =
  buildHtml(tdiv(class="latest-post-version")):
    text "There's a new version of this post. "
    a(href=getLink(id, username)):
      text "See the latest post"

proc renderQuoteMedia(quote: Tweet; prefs: Prefs; path: string): VNode =
  buildHtml(tdiv(class="quote-media-container")):
    renderMedia(quote.media, prefs, path)

proc renderCommunityNote(note: string; prefs: Prefs): VNode =
  buildHtml(tdiv(class="community-note")):
    tdiv(class="community-note-header"):
      icon "group"
      span: text "Community note"
    tdiv(class="community-note-text", dir="auto"):
      verbatim replaceUrls(note, prefs)

proc renderQuote(quote: Tweet; prefs: Prefs; path: string): VNode =
  if not quote.available:
    return buildHtml(tdiv(class="quote unavailable")):
      a(class="unavailable-quote", href=getLink(quote, focus=false)):
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
        verifiedIcon(quote.user)
        linkUser(quote.user, class="username")

      span(class="tweet-date"):
        a(href=getLink(quote), title=quote.getTime):
          text quote.getShortTime

    if quote.reply.len > 0:
      renderReply(quote)

    if quote.text.len > 0:
      tdiv(class="quote-text", dir="auto"):
        verbatim replaceUrls(quote.text, prefs)

    if quote.media.len > 0:
      renderQuoteMedia(quote, prefs, path)

    if quote.note.len > 0 and not prefs.hideCommunityNotes:
      renderCommunityNote(quote.note, prefs)

    if quote.hasThread:
      a(class="show-thread", href=getLink(quote)):
        text "Show this thread"

    if quote.history.len > 0 and quote.id != max(quote.history):
      tdiv(class="quote-latest"):
        text "There's a new version of this post"

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
                  last=false; mainTweet=false; afterTweet=false): VNode =
  var divClass = class
  if index == -1 or last:
    divClass = "thread-last " & class

  if not tweet.available:
    return buildHtml(tdiv(class=divClass & "unavailable timeline-item", data-username=tweet.user.username)):
      a(class="unavailable-box", href=getLink(tweet)):
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

  buildHtml(tdiv(class=("timeline-item " & divClass), data-username=tweet.user.username)):
    if not mainTweet:
      a(class="tweet-link", href=getLink(tweet))

    tdiv(class="tweet-body"):
      renderHeader(tweet, retweet, pinned, prefs)

      if not afterTweet and index == 0 and tweet.reply.len > 0 and
         (tweet.reply.len > 1 or tweet.reply[0] != tweet.user.username or pinned):
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

      if tweet.media.len > 0:
        renderMedia(tweet.media, prefs, path)

      if tweet.poll.isSome:
        renderPoll(tweet.poll.get())

      if tweet.quote.isSome:
        renderQuote(tweet.quote.get(), prefs, path)

      if tweet.note.len > 0 and not prefs.hideCommunityNotes:
        renderCommunityNote(tweet.note, prefs)

      let
        hasEdits = tweet.history.len > 1
        isLatest = hasEdits and tweet.id == max(tweet.history)

      if mainTweet:
        p(class="tweet-published"): 
          if hasEdits and isLatest:
            a(href=(getLink(tweet, focus=false) & "/history")):
              text &"Last edited {getTime(tweet)}"
          else:
            text &"{getTime(tweet)}"

        if hasEdits and not isLatest:
          renderLatestPost(tweet.user.username, max(tweet.history))

      if tweet.mediaTags.len > 0:
        renderMediaTags(tweet.mediaTags)

      if not prefs.hideTweetStats:
        renderStats(tweet.stats)

proc renderTweetEmbed*(tweet: Tweet; path: string; prefs: Prefs; cfg: Config; req: Request): string =
  let node = buildHtml(html(lang="en")):
    renderHead(prefs, cfg, req)

    body:
      tdiv(class="tweet-embed"):
        renderTweet(tweet, prefs, path, mainTweet=true)

  result = doctype & $node
