import strformat
import karax/[karaxdsl, vdom]

import renderutils
import ".."/[types]

proc renderListTabs*(query: Query; path: string): VNode =
  buildHtml(ul(class="tab")):
    li(class=query.getTabClass(posts)):
      a(href=(path)): text "Tweets"
    li(class=query.getTabClass(users)):
      a(href=(path & "/members")): text "Members"

proc renderList*(body: VNode; query: Query; name, list: string): VNode =
  buildHtml(tdiv(class="timeline-container")):
    tdiv(class="timeline-header"):
      text &"\"{list}\" by @{name}"

    renderListTabs(query, &"/{name}/lists/{list}")
    body
