# SPDX-License-Identifier: AGPL-3.0-only
import options
import karax/[karaxdsl, vdom]
from jester import Request

import ".."/[types, formatters]
import general, tweet

const doctype = "<!DOCTYPE html>\n"

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

  result = doctype & $node
