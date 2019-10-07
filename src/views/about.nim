import karax/[karaxdsl, vdom]
import markdown

const
  hash = staticExec("git log -1 --format=\"%h\"")
  link = "https://github.com/zedeus/nitter/commit/" & hash

let
  about = markdown(readFile("public/md/about.md"))
  feature = markdown(readFile("public/md/feature.md"))

proc renderAbout*(): VNode =
  buildHtml(tdiv(class="overlay-panel")):
    verbatim about
    h2: text "Instance info"
    p:
      text "Commit "
      a(href=link): text hash

proc renderFeature*(): VNode =
  buildHtml(tdiv(class="overlay-panel")):
    verbatim feature
