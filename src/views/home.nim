import karax/[karaxdsl, vdom], strutils
import search, timeline
import ../types

proc renderHome*(results: Result[Tweet]; prefs: Prefs; path: string): VNode =
  let query = results.query
  buildHtml(tdiv(class="timeline-container")):
    if query.fromUser.len > 0:
      renderProfileTabs(query, query.fromUser.join(","))

    if query.fromUser.len == 0 or query.kind == tweets:
      tdiv(class="timeline-header"):
        renderSearchPanel(query)

    renderTimelineTweets(results, prefs, path)
