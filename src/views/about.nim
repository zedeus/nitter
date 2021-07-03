import os
import karax/[karaxdsl, vdom]
import markdown

import ".."/[types]

const
  hash = staticExec("git log -1 --format=\"%h\"")
  link = "https://github.com/zedeus/nitter/commit/" & hash

var about, feature: string

proc renderAbout*(cfg: Config): VNode =
  if about.len == 0:
    about = markdown(readFile(cfg.staticDir / "md/about.md"))
  buildHtml(tdiv(class="overlay-panel")):
    verbatim about
    h2: text "Instance info"
    p:
      text "Commit "
      a(href=link): text hash

proc renderFeature*(cfg: Config): VNode =
  if feature.len == 0:
    feature = markdown(readFile(cfg.staticDir / "md/feature.md"))
  buildHtml(tdiv(class="overlay-panel")):
    verbatim feature
