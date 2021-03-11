import karax/[karaxdsl, vdom]
import ../types

proc renderHome*(): VNode =
  buildHtml(tdiv(class="overlay-panel")):
    h2: text "Timeline"
    p: text "Coming soon!"
