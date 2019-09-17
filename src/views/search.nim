import strutils, strformat, unicode
import karax/[karaxdsl, vdom, vstyles]

import renderutils, timeline
import ".."/[types, formatters, query]

proc renderSearch*(): VNode =
  buildHtml(tdiv(class="panel-container")):
    tdiv(class="search-bar"):
      form(`method`="get", action="/search"):
        hiddenField("kind", "users")
        input(`type`="text", name="text", autofocus="", placeholder="Enter username...")
        button(`type`="submit"): icon "search"

proc renderTimelineSearch*(timeline: Timeline; prefs: Prefs; path: string): VNode =
  let users =
    if timeline.query.isSome: get(timeline.query).fromUser
    else: @[]

  buildHtml(tdiv(class="timeline-container")):
    tdiv(class="timeline-header"):
      text users.join(" | ")

    renderProfileTabs(timeline.query, users.join(","))
    renderTimelineTweets(timeline, prefs, path)

proc renderTweetSearch*(tweets: Result[Tweet]; prefs: Prefs; path: string): VNode =
  let query = if tweets.query.isSome: get(tweets.query) else: Query(kind: custom)

  buildHtml(tdiv(class="timeline-container")):
    tdiv(class="timeline-header"):
      form(`method`="get", action="/search", class="search-field"):
        hiddenField("kind", "custom")
        genInput("text", "", query.text, "Enter search...", class="pref-inline")
        button(`type`="submit"): icon "search"
        input(id="panel-toggle", `type`="checkbox")
        label(`for`="panel-toggle", class="panel-label"):
          icon "down"
        tdiv(class="search-panel"):
          tdiv:
            span(class="search-title"): text "Include: "
            genCheckbox("retweets", "Retweets", "nativeretweets" in query.includes)
            genCheckbox("replies", "Replies", "replies" in query.includes)

          for f in @["filter", "exclude"]:
            tdiv:
              span(class="search-title"): text capitalize(f) & ":"
              for i in commonFilters:
                let state =
                  if f == "filter": i in query.filters
                  else: i in query.excludes
                genCheckbox(&"{f[0]}-{i}", capitalize(i), state)
              input(id=(&"{f}-toggle"), `type`="checkbox")
              label(`for`=(&"{f}-toggle"), class=(&"{f}-label")):
                icon "down"
              tdiv(class=(&"{f}-extras")):
                for i in advancedFilters:
                  let state =
                    if f == "filter": i in query.filters
                    else: i in query.excludes
                  genCheckbox(&"{f[0]}-{i}", i, state)

    renderSearchTabs(tweets.query)
    renderTimelineTweets(tweets, prefs, path)

proc renderUserSearch*(users: Result[Profile]; prefs: Prefs): VNode =
  let searchText =
    if users.query.isSome: get(users.query).text
    else: ""

  buildHtml(tdiv(class="timeline-container")):
    tdiv(class="timeline-header"):
      form(`method`="get", action="/search", class="search-field"):
        hiddenField("kind", "users")
        genInput("text", "", searchText, "Enter username...", class="pref-inline")
        button(`type`="submit"): icon "search"
        input(id="panel-toggle", `type`="checkbox")
        label(`for`="panel-toggle", class="panel-label"):
          icon "down"

    renderSearchTabs(users.query)
    renderTimelineUsers(users, prefs)
