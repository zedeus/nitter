# SPDX-License-Identifier: AGPL-3.0-only
import strutils, strformat, sequtils, unicode, tables, options
import karax/[karaxdsl, vdom]

import renderutils, timeline
import ".."/[types, query]

const toggles = {
  "nativeretweets": "Retweets",
  "media": "Media",
  "videos": "Videos",
  "news": "News",
  "native_video": "Native videos",
  "replies": "Replies",
  "links": "Links",
  "images": "Images",
  "quote": "Quotes",
  "spaces": "Spaces"
}.toOrderedTable

proc renderSearch*(): VNode =
  buildHtml(tdiv(class="panel-container")):
    tdiv(class="search-bar"):
      form(`method`="get", action="/search", autocomplete="off"):
        hiddenField("f", "tweets")
        input(`type`="text", name="q", autofocus="",
              placeholder="Search...", dir="auto")
        button(`type`="submit"): icon "search"

proc renderProfileTabs*(query: Query; username: string): VNode =
  let link = "/" & username
  buildHtml(ul(class="tab")):
    li(class=query.getTabClass(posts)):
      a(href=link): text "Tweets"
    li(class=(query.getTabClass(replies) & " wide")):
      a(href=(link & "/with_replies")): text "Tweets & Replies"
    li(class=query.getTabClass(media)):
      a(href=(link & "/media")): text "Media"
    li(class=query.getTabClass(tweets)):
      a(href=(link & "/search")): text "Search"

proc renderSearchTabs*(query: Query): VNode =
  var q = query
  buildHtml(ul(class="tab")):
    li(class=query.getTabClass(tweets)):
      q.kind = tweets
      a(href=("?" & genQueryUrl(q))): text "Tweets"
    li(class=query.getTabClass(users)):
      q.kind = users
      a(href=("?" & genQueryUrl(q))): text "Users"

proc isPanelOpen(q: Query): bool =
  q.fromUser.len == 0 and (q.filters.len > 0 or q.excludes.len > 0 or
  @[q.minLikes, q.until, q.since].anyIt(it.len > 0))

proc renderSearchPanel*(query: Query): VNode =
  let user = query.fromUser.join(",")
  let action = if user.len > 0: &"/{user}/search" else: "/search"
  buildHtml(form(`method`="get", action=action,
                 class="search-field", autocomplete="off")):
    hiddenField("f", "tweets")
    genInput("q", "", query.text, "Enter search...", class="pref-inline")
    button(`type`="submit"): icon "search"

    input(id="search-panel-toggle", `type`="checkbox", checked=isPanelOpen(query))
    label(`for`="search-panel-toggle"): icon "down"

    tdiv(class="search-panel"):
      for f in @["filter", "exclude"]:
        span(class="search-title"): text capitalize(f)
        tdiv(class="search-toggles"):
          for k, v in toggles:
            let state =
              if f == "filter": k in query.filters
              else: k in query.excludes
            genCheckbox(&"{f[0]}-{k}", v, state)

      tdiv(class="search-row"):
        tdiv:
          span(class="search-title"): text "Time range"
          tdiv(class="date-range"):
            genDate("since", query.since)
            span(class="search-title"): text "-"
            genDate("until", query.until)
        tdiv:
          span(class="search-title"): text "Minimum likes"
          genNumberInput("min_faves", "", query.minLikes, "Number...", autofocus=false)

proc renderTweetSearch*(results: Timeline; prefs: Prefs; path: string;
                        pinned=none(Tweet)): VNode =
  let query = results.query
  buildHtml(tdiv(class="timeline-container")):
    if query.fromUser.len > 1:
      tdiv(class="timeline-header"):
        text query.fromUser.join(" | ")

    if query.fromUser.len > 0:
      renderProfileTabs(query, query.fromUser.join(","))

    if query.fromUser.len == 0 or query.kind == tweets:
      tdiv(class="timeline-header"):
        renderSearchPanel(query)

    if query.fromUser.len == 0:
      renderSearchTabs(query)

    renderTimelineTweets(results, prefs, path, pinned)

proc renderUserSearch*(results: Result[User]; prefs: Prefs): VNode =
  buildHtml(tdiv(class="timeline-container")):
    tdiv(class="timeline-header"):
      form(`method`="get", action="/search", class="search-field", autocomplete="off"):
        hiddenField("f", "users")
        genInput("q", "", results.query.text, "Enter username...", class="pref-inline")
        button(`type`="submit"): icon "search"

    renderSearchTabs(results.query)
    renderTimelineUsers(results, prefs)
