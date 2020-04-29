import karax/[karaxdsl, vdom]

import ".."/[types, formatters]
import tweet, timeline

proc renderEarlier(thread: Chain): VNode =
  buildHtml(tdiv(class="timeline-item more-replies earlier-replies")):
    a(class="more-replies-text", href=getLink(thread.content[0])):
      text "earlier replies"

proc renderMoreReplies(thread: Chain): VNode =
  let num = if thread.more != -1: $thread.more & " " else: ""
  let reply = if thread.more == 1: "reply" else: "replies"
  let link = getLink(thread.content[^1])
  buildHtml(tdiv(class="timeline-item more-replies")):
    if link.len > 0:
      a(class="more-replies-text", href=link):
        text $num & "more " & reply
    else:
      a(class="more-replies-text"):
        text $num & "more " & reply

proc renderReplyThread(thread: Chain; prefs: Prefs; path: string): VNode =
  buildHtml(tdiv(class="reply thread thread-line")):
    for i, tweet in thread.content:
      let last = (i == thread.content.high and thread.more == 0)
      renderTweet(tweet, prefs, path, index=i, last=last)

    if thread.more != 0:
      renderMoreReplies(thread)

proc renderReplies*(replies: Result[Chain]; prefs: Prefs; path: string): VNode =
  buildHtml(tdiv(class="replies", id="r")):
    for thread in replies.content:
      if thread == nil: continue
      renderReplyThread(thread, prefs, path)

    if replies.hasMore:
      renderMore(Query(), replies.minId, focus="#r")

proc renderConversation*(conversation: Conversation; prefs: Prefs; path: string): VNode =
  let hasAfter = conversation.after != nil
  let showReplies = not prefs.hideReplies
  buildHtml(tdiv(class="conversation")):
    tdiv(class="main-thread"):
      if conversation.before != nil:
        tdiv(class="before-tweet thread-line"):
          if conversation.before.more == -1:
            renderEarlier(conversation.before)
          for i, tweet in conversation.before.content:
            renderTweet(tweet, prefs, path, index=i)

      tdiv(class="main-tweet", id="m"):
        let afterClass = if hasAfter: "thread thread-line" else: ""
        renderTweet(conversation.tweet, prefs, path, class=afterClass,
                    mainTweet=true)

      if hasAfter:
        tdiv(class="after-tweet thread-line"):
          let total = conversation.after.content.high
          let more = conversation.after.more
          for i, tweet in conversation.after.content:
            renderTweet(tweet, prefs, path, index=i, last=(i == total and more == 0))

          if more != 0:
            renderMoreReplies(conversation.after)

    if not conversation.replies.beginning and showReplies:
      renderNewer(Query(), getLink(conversation.tweet))

    if conversation.replies.content.len > 0 and showReplies:
      renderReplies(conversation.replies, prefs, path)
