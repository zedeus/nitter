# SPDX-License-Identifier: AGPL-3.0-only
import karax/[karaxdsl, vdom]
from jester import Request

import ".."/[types, formatters]
import general, tweet

const
  doctype = "<!DOCTYPE html>\n"
  embedResizeJs = staticRead("../../public/js/embedResize.js")

proc renderVideoEmbed*(tweet: Tweet; cfg: Config; req: Request): string =
  let
    video = tweet.getVideos()[0]
    thumb = video.thumb
    vidUrl = getVideoEmbed(cfg, tweet.id)
    prefs = Prefs(hlsPlayback: true, mp4Playback: true, proxyVideos: true)
    tweetUrl = getLink(tweet)

  let node = buildHtml(html(lang="en")):
    renderHead(prefs, cfg, req, video=vidUrl, images=(@[thumb]))
    base(target="_blank")

    body:
      tdiv(class="embed-video"):
        renderVideo(video, prefs, "")
        a(class="video-overlay-link", href=tweetUrl):
          text "Watch on " & cfg.hostname

      script:
        verbatim embedResizeJs

  result = doctype & $node

proc renderTweetEmbed*(tweet: Tweet; path: string; prefs: Prefs; cfg: Config; req: Request): string =
  let node = buildHtml(html(lang="en")):
    renderHead(prefs, cfg, req)
    base(target="_blank")

    body:
      tdiv(class="embed-wrapper"):
        tdiv(class="tweet-embed"):
          a(class="tweet-link", href=getLink(tweet))
          renderTweet(tweet, prefs, path, mainTweet=true)
        a(class="embed-footer", href=getLink(tweet)):
          text "Read more on " & cfg.hostname

      script:
        verbatim embedResizeJs

  result = doctype & $node

proc renderErrorEmbed*(error: string; prefs: Prefs; cfg: Config; req: Request;
                       tweetId = ""; username = ""): string =
  let link = if tweetId.len > 0:
               if username.len > 0: "/" & username & "/status/" & tweetId
               else: "/i/status/" & tweetId
             else: "/"

  let node = buildHtml(html(lang="en")):
    renderHead(prefs, cfg, req)
    base(target="_blank")

    body:
      tdiv(class="embed-wrapper"):
        tdiv(class="tweet-embed error-embed"):
          a(class="tweet-link", href=link)
          tdiv(class="error-panel"):
            span: text error
        a(class="embed-footer", href=link):
          text "Read more on " & cfg.hostname

      script:
        verbatim embedResizeJs

  result = doctype & $node
