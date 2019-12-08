import options
import karax/[karaxdsl, vdom]

import ".."/[types, formatters]
import general, tweet

const doctype = "<!DOCTYPE html>\n"

proc renderVideoEmbed*(cfg: Config; tweet: Tweet): string =
  let thumb = get(tweet.video).thumb
  let vidUrl = getVideoEmbed(cfg, tweet.id)
  let prefs = Prefs(hlsPlayback: true)
  let node = buildHtml(html(lang="en")):
    renderHead(prefs, cfg, video=vidUrl, images=(@[thumb]))

    tdiv(class="embed-video"):
      renderVideo(get(tweet.video), prefs, "")

  result = doctype & $node
