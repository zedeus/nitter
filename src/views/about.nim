import karax/[karaxdsl, vdom]
import markdown

let
  about = markdown(readFile("public/md/about.md"))
  feature = markdown(readFile("public/md/feature.md"))

proc renderAbout*(): VNode =
  buildHtml(tdiv(class="overlay-panel")):
    verbatim about

proc renderFeature*(): VNode =
  buildHtml(tdiv(class="overlay-panel")):
    verbatim feature
