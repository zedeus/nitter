import karax/[karaxdsl, vdom]
import search, timeline, renderutils
import ../types

proc renderFollowingUsers*(results: seq[User]; prefs: Prefs): VNode =
  buildHtml(tdiv(class="timeline")):
    for user in results:
      renderUser(user, prefs)

proc renderHomeTabs*(query: Query): VNode =
  buildHtml(ul(class="tab")):
    li(class=query.getTabClass(posts)):
      a(href="/"): text "Tweets"
    li(class=query.getTabClass(userList)):
      a(href=("/following")): text "Following"

proc renderHome*(results: Result[Tweet]; prefs: Prefs; path: string): VNode =
  let query = results.query
  buildHtml(tdiv(class="timeline-container")):
    if query.fromUser.len > 0:
      renderHomeTabs(query)

    if query.fromUser.len == 0 or query.kind == tweets:
      tdiv(class="timeline-header"):
        renderSearchPanel(query)

    renderTimelineTweets(results, prefs, path)

proc renderFollowing*(query: Query; following: seq[User]; prefs: Prefs): VNode =
  buildHtml(tdiv(class="timeline-container")):
    renderHomeTabs(query)
    renderFollowingUsers(following, prefs)
