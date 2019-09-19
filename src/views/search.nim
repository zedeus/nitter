import strutils, strformat, unicode, tables
import karax/[karaxdsl, vdom, vstyles]

import renderutils, timeline
import ".."/[types, formatters, query]

let toggles = {
  "nativeretweets": "Retweets",
  "media": "Media",
  "videos": "Videos",
  "news": "News",
  "verified": "Verified",
  "native_video": "Native videos",
  "replies": "Replies",
  "links": "Links",
  "images": "Images",
  "safe": "Safe",
  "quote": "Quotes",
  "pro_video": "Pro videos"
}.toOrderedTable

proc renderSearch*(): VNode =
  buildHtml(tdiv(class="panel-container")):
    tdiv(class="search-bar"):
      form(`method`="get", action="/search"):
        hiddenField("kind", "users")
        input(`type`="text", name="text", autofocus="", placeholder="Enter username...")
        button(`type`="submit"): icon "search"

proc getTabClass(query: Query; tab: QueryKind): string =
  var classes = @["tab-item"]
  if query.kind == tab:
    classes.add "active"
  return classes.join(" ")

proc renderProfileTabs*(query: Query; username: string): VNode =
  let link = "/" & username
  buildHtml(ul(class="tab")):
    li(class=query.getTabClass(posts)):
      a(href=link): text "Tweets"
    li(class=query.getTabClass(replies)):
      a(href=(link & "/replies")): text "Tweets & Replies"
    li(class=query.getTabClass(media)):
      a(href=(link & "/media")): text "Media"
    li(class=query.getTabClass(custom)):
      a(href=(link & "/search")): text "Custom"

proc renderSearchTabs*(query: Query): VNode =
  var q = query
  buildHtml(ul(class="tab")):
    li(class=query.getTabClass(custom)):
      q.kind = custom
      a(href=genQueryUrl(q)): text "Tweets"
    li(class=query.getTabClass(users)):
      q.kind = users
      a(href=genQueryUrl(q)): text "Users"

proc renderSearchPanel*(query: Query): VNode =
  let user = query.fromUser.join(",")
  let action = if user.len > 0: &"/{user}/search" else: "/search"
  buildHtml(form(`method`="get", action=action, class="search-field")):
    hiddenField("kind", "custom")
    genInput("text", "", query.text, "Enter search...", class="pref-inline")
    button(`type`="submit"): icon "search"
    input(id="search-panel-toggle", `type`="checkbox")
    label(`for`="search-panel-toggle"):
      icon "down"
    tdiv(class="search-panel"):
      for f in @["filter", "exclude"]:
        span(class="search-title"): text capitalize(f)
        tdiv(class="search-toggles"):
          for k, v in toggles:
            let state =
              if f == "filter": k in query.filters
              else: k in query.excludes
            genCheckbox(&"{f[0]}-{k}", v, state)

proc renderTweetSearch*(tweets: Result[Tweet]; prefs: Prefs; path: string): VNode =
  let query = tweets.query
  buildHtml(tdiv(class="timeline-container")):
    if query.fromUser.len > 1:
      tdiv(class="timeline-header"):
        text query.fromUser.join(" | ")
    if query.fromUser.len == 0 or query.kind == custom:
      tdiv(class="timeline-header"):
        renderSearchPanel(query)

    if query.fromUser.len > 0:
      renderProfileTabs(query, query.fromUser.join(","))
    else:
      renderSearchTabs(query)

    renderTimelineTweets(tweets, prefs, path)

proc renderUserSearch*(users: Result[Profile]; prefs: Prefs): VNode =
  buildHtml(tdiv(class="timeline-container")):
    tdiv(class="timeline-header"):
      form(`method`="get", action="/search", class="search-field"):
        hiddenField("kind", "users")
        genInput("text", "", users.query.text, "Enter username...", class="pref-inline")
        button(`type`="submit"): icon "search"

    renderSearchTabs(users.query)
    renderTimelineUsers(users, prefs)