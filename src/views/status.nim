import strutils, strformat
import karax/[karaxdsl, vdom]

import ../types
import tweet, renderutils

proc renderMoreReplies(thread: Thread): VNode =
  let num = if thread.more != -1: $thread.more & " " else: ""
  let reply = if thread.more == 1: "reply" else: "replies"
  buildHtml(tdiv(class="status-el more-replies")):
    a(class="more-replies-text", title="Not implemented yet"):
      text $num & "more " & reply

proc renderReplyThread(thread: Thread; prefs: Prefs): VNode =
  buildHtml(tdiv(class="reply thread thread-line")):
    for i, tweet in thread.tweets:
      let last = (i == thread.tweets.high and thread.more == 0)
      renderTweet(tweet, prefs, index=i, last=last)

    if thread.more != 0:
      renderMoreReplies(thread)

proc renderConversation*(conversation: Conversation; prefs: Prefs): VNode =
  let hasAfter = conversation.after != nil
  buildHtml(tdiv(class="conversation", id="posts")):
    tdiv(class="main-thread"):
      if conversation.before != nil:
        tdiv(class="before-tweet thread-line"):
          for i, tweet in conversation.before.tweets:
            renderTweet(tweet, prefs, index=i)

      tdiv(class="main-tweet"):
        let afterClass = if hasAfter: "thread thread-line" else: ""
        renderTweet(conversation.tweet, prefs, class=afterClass)

      if hasAfter:
        tdiv(class="after-tweet thread-line"):
          let total = conversation.after.tweets.high
          let more = conversation.after.more
          for i, tweet in conversation.after.tweets:
            renderTweet(tweet, prefs, index=i, last=(i == total and more == 0))

          if more != 0:
            renderMoreReplies(conversation.after)

    if conversation.replies.len > 0:
      tdiv(class="replies"):
        for thread in conversation.replies:
          renderReplyThread(thread, prefs)
