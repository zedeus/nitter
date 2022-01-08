# SPDX-License-Identifier: AGPL-3.0-only
import os, strformat
import karax/[karaxdsl, vdom], markdown

import ".."/[types]

const
  date = staticExec("git show -s --format=\"%cd\" --date=format:\"%Y.%m.%d\"")
  hash = staticExec("git show -s --format=\"%h\"")
  link = "https://github.com/zedeus/nitter/commit/" & hash
  version = &"{date}-{hash}"

var about, feature: string

proc renderAbout*(cfg: Config): VNode =
  if about.len == 0:
    about = markdown(readFile(cfg.staticDir / "md/about.md"))
  buildHtml(tdiv(class="overlay-panel")):
    verbatim about
    h2: text "Instance info"
    p:
      text "Version "
      a(href=link): text version

proc renderFeature*(cfg: Config): VNode =
  if feature.len == 0:
    feature = markdown(readFile(cfg.staticDir / "md/feature.md"))
  buildHtml(tdiv(class="overlay-panel")):
    verbatim feature
