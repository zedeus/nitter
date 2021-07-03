import os
import karax/[karaxdsl, vdom]
import markdown

import ".."/[types]

const
  hash = staticExec("git log -1 --format=\"%h\"")
  link = "https://github.com/zedeus/nitter/commit/" & hash

proc renderAbout*(cfg: Config): VNode =
  buildHtml(tdiv(class="overlay-panel")):
    verbatim markdown(readFile(cfg.staticDir / "md/about.md"))
    h2: text "Instance info"
    p:
      text "Commit "
      a(href=link): text hash

proc renderFeature*(cfg: Config): VNode =
  buildHtml(tdiv(class="overlay-panel")):
    verbatim markdown(readFile(cfg.staticDir / "md/feature.md"))
