import strutils, strformat
import karax/[karaxdsl, vdom, vstyles]

import renderutils, timeline
import ".."/[types, formatters, query]

proc renderSearch*(): VNode =
  buildHtml(tdiv(class="panel-container")):
    tdiv(class="search-panel"):
      form(`method`="get", action="/search"):
        verbatim "<input name=\"kind\" style=\"display: none\" value=\"users\"/>"
        input(`type`="text", name="text", autofocus="", placeholder="Enter username...")
        button(`type`="submit"): icon "search"

proc renderTweetSearch*(timeline: Timeline; prefs: Prefs; path: string): VNode =
  let users = get(timeline.query).fromUser
  buildHtml(tdiv(class="timeline-container")):
    tdiv(class="timeline-header"):
      text users.join(" | ")

    renderProfileTabs(timeline.query, users.join(","))
    renderTimelineTweets(timeline, prefs, path)

proc renderUserSearch*(users: Result[Profile]; prefs: Prefs): VNode =
  let searchText =
    if users.query.isSome: get(users.query).text
    else: ""

  buildHtml(tdiv(class="timeline-container")):
    tdiv(class="timeline-header"):
      form(`method`="get", action="/search"):
        verbatim "<input name=\"kind\" style=\"display: none\" value=\"users\"/>"
        verbatim "<input type=\"text\" name=\"text\" value=\"$1\"/>" % searchText
        button(`type`="submit"): icon "search"

    renderSearchTabs(users.query)

    renderTimelineUsers(users, prefs)
