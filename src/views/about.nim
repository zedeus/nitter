# SPDX-License-Identifier: AGPL-3.0-only
import strformat
import karax/[karaxdsl, vdom]

const
  date = staticExec("git show -s --format=\"%cd\" --date=format:\"%Y.%m.%d\"")
  hash = staticExec("git show -s --format=\"%h\"")
  link = "https://github.com/zedeus/nitter/commit/" & hash
  version = &"{date}-{hash}"

let about =
  try:
    readFile("public/md/about.html")
  except IOError:
    stderr.write "public/md/about.html not found, please run `nimble md`\n"
    "<h1>About page is missing</h1><br><br>"

proc renderAbout*(): VNode =
  buildHtml(tdiv(class="overlay-panel")):
    verbatim about
    h2: text "Instance info"
    p:
      text "Version "
      a(href=link): text version
