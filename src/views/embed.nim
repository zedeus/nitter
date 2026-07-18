# SPDX-License-Identifier: AGPL-3.0-only
import karax/[karaxdsl, vdom]
from jester import Request

import ".."/[types, formatters]
import general, tweet

const
  doctype = "<!DOCTYPE html>\n"
  embedResizeJs = staticRead("../../public/js/embedResize.js")
  embedTweetJs = embedResizeJs & staticRead("../../public/js/embedTweet.js")
  embedErrorJs = embedResizeJs & ";requestAnimationFrame(arguments[0]);"

proc renderVideoEmbed*(tweet: Tweet; cfg: Config; req: Request): string =
  let
    video = tweet.getVideos()[0]
    thumb = video.thumb
    vidUrl = getVideoEmbed(cfg, tweet.id)
    prefs = Prefs(hlsPlayback: true, mp4Playback: true)

  let node = buildHtml(html(lang="en")):
    renderHead(prefs, cfg, req, video=vidUrl, images=(@[thumb]))

    body:
      tdiv(class="embed-video"):
        renderVideo(video, prefs, "")

      script:
        verbatim embedResizeJs

  result = doctype & $node

proc renderTweetEmbed*(tweet: Tweet; path: string; prefs: Prefs; cfg: Config; req: Request): string =
  let node = buildHtml(html(lang="en")):
    renderHead(prefs, cfg, req)

    body:
      tdiv(class="tweet-embed"):
        a(class="tweet-link", href=getLink(tweet), target="_blank")
        renderTweet(tweet, prefs, path, mainTweet=true)
        a(class="embed-footer", href=getLink(tweet), target="_blank"):
          text "Read more on " & cfg.hostname

      script:
        verbatim embedTweetJs

  result = doctype & $node

proc renderErrorEmbed*(error: string; prefs: Prefs; cfg: Config; req: Request): string =
  let node = buildHtml(html(lang="en")):
    renderHead(prefs, cfg, req)

    body:
      tdiv(class="tweet-embed error-embed"):
        tdiv(class="error-panel"):
          span: text error

      script:
        verbatim embedErrorJs

  result = doctype & $node
