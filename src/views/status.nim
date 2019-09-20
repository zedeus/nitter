import karax/[karaxdsl, vdom]

import ../types
import tweet

proc renderMoreReplies(thread: Thread): VNode =
  let num = if thread.more != -1: $thread.more & " " else: ""
  let reply = if thread.more == 1: "reply" else: "replies"
  buildHtml(tdiv(class="timeline-item more-replies")):
    a(class="more-replies-text", title="Not implemented yet"):
      text $num & "more " & reply

proc renderReplyThread(thread: Thread; prefs: Prefs; path: string): VNode =
  buildHtml(tdiv(class="reply thread thread-line")):
    for i, tweet in thread.content:
      let last = (i == thread.content.high and thread.more == 0)
      renderTweet(tweet, prefs, path, index=i, last=last)

    if thread.more != 0:
      renderMoreReplies(thread)

proc renderConversation*(conversation: Conversation; prefs: Prefs; path: string): VNode =
  let hasAfter = conversation.after != nil
  buildHtml(tdiv(class="conversation")):
    tdiv(class="main-thread"):
      if conversation.before != nil:
        tdiv(class="before-tweet thread-line"):
          for i, tweet in conversation.before.content:
            renderTweet(tweet, prefs, path, index=i)

      tdiv(class="main-tweet"):
        let afterClass = if hasAfter: "thread thread-line" else: ""
        renderTweet(conversation.tweet, prefs, path, class=afterClass)

      if hasAfter:
        tdiv(class="after-tweet thread-line"):
          let total = conversation.after.content.high
          let more = conversation.after.more
          for i, tweet in conversation.after.content:
            renderTweet(tweet, prefs, path, index=i, last=(i == total and more == 0))

          if more != 0:
            renderMoreReplies(conversation.after)

    if conversation.replies.len > 0:
      tdiv(class="replies"):
        for thread in conversation.replies:
          if thread == nil: continue
          renderReplyThread(thread, prefs, path)
