#? stdtmpl(subsChar = '$', metaChar = '#')
#import xmltree, strutils, times, sequtils, uri
#import ../types, ../formatters, ../utils
#
#proc renderHeading(tweet: Tweet): string =
#if tweet.retweetBy != "":
  <div class="retweet">
    <span>🔄 ${tweet.retweetBy} retweeted</span>
  </div>
#end if
#if tweet.pinned:
  <div class="pinned">
    <span>📌 Pinned Tweet</span>
  </div>
#end if
<div class="media-heading">
  <div class="heading-name-row">
    <img class="avatar" src=${tweet.profile.getUserpic("_bigger").getSigUrl("pic")}>
    <div class="name-and-account-name">
      ${linkUser(tweet.profile, "h4", class="username", username=false)}
      ${linkUser(tweet.profile, "", class="account-name")}
    </div>
    <span class="heading-right">
      <a href="${tweet.link}" class="timeago faint-link">
        <time title="${tweet.time.format("d/M/yyyy', ' HH:mm:ss")}">${tweet.shortTime}</time>
      </a>
    </span>
  </div>
</div>
#end proc
#
#proc renderMediaGroup(tweet: Tweet): string =
#let groups = if tweet.photos.len > 2: tweet.photos.distribute(2) else: @[tweet.photos]
#let groupStyle = if groups.len == 1 and groups[0].len < 2: "" else: "background-color: #0f0f0f;"
#var first = true
<div class="attachments media-body" style="${groupStyle}">
#for photos in groups:
  #let style = if first: "" else: "margin-top: .25em;"
  <div class="gallery-row cover-fit" style="${style}">
    #for photo in photos:
    <div class="attachment image">
      ##TODO: why doesn't this work?
      <a href=${getSigUrl(photo & ":large", "pic")} target="_blank" class="image-attachment">
        #let style = if photos.len > 1 or groups.len > 1: "display: flex;" else: ""
        #let istyle = if photos.len > 1 or groups.len > 1: "" else: "border-radius: 7px;"
        <div class="still-image" style="${style}">
          <img src=${getSigUrl(photo, "pic")} referrerpolicy="" style="${istyle}">
        </div>
      </a>
    </div>
    #end for
  </div>
  #first = false
#end for
</div>
#end proc
#
#proc renderVideo(tweet: Tweet): string =
<div class="attachments media-body">
  <div class="gallery-row" style="max-height: unset;">
    <div class="attachment image">
    <video poster=${tweet.videoThumb} style="width: 100%; height: 100%;" autoplay muted loop></video>
    <div class="video-overlay">
      <p>Video playback not supported</p>
    </div>
    </div>
  </div>
</div>
#end proc
#
#proc renderGif(tweet: Tweet): string =
#let thumbUrl = getGifThumb(tweet).getSigUrl("pic")
#let videoUrl = getGifSrc(tweet).getSigUrl("video")
<div class="attachments media-body">
  <div class="gallery-row" style="max-height: unset;">
    <div class="attachment image">
      <video poster=${thumbUrl} style="width: 100%; height: 100%;" autoplay muted loop>
        <source src=${videoUrl} type="video/mp4">
      </video>
    </div>
  </div>
</div>
#end proc
#
#proc renderStats(tweet: Tweet): string =
<div class="tweet-stats">
  <span class="tweet-stat">💬 ${$tweet.replies}</span>
  <span class="tweet-stat">🔄 ${$tweet.retweets}</span>
  <span class="tweet-stat">👍 ${$tweet.likes}</span>
</div>
#end proc
#
#proc renderTweet*(tweet: Tweet; class=""): string =
<div class="${class}">
  <div class="status-el">
    <div class="status-body">
      ${renderHeading(tweet)}
      <div class="status-content-wrapper">
        <div class="status-content media-body">
          ${linkifyText(tweet.text)}
        </div>
      </div>
      #if tweet.photos.len > 0:
        ${renderMediaGroup(tweet)}
      #elif tweet.videoThumb.len > 0:
        ${renderVideo(tweet)}
      #elif tweet.gif.len > 0:
        ${renderGif(tweet)}
      #end if
      ${renderStats(tweet)}
    </div>
  </div>
</div>
#end proc
