import karax/[karaxdsl, vdom]
import markdown

let about = markdown(readFile("public/md/about.md"))

proc renderAbout*(): VNode =
  buildHtml(tdiv(class="overlay-panel")):
    verbatim about
