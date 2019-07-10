import xmltree, strutils, strformat, uri, algorithm, times
import karax/[karaxdsl, vdom, vstyles]

import ../types
import tweet, renderutils

proc renderReplyThread(thread: Thread): VNode =
  buildHtml(tdiv(class="reply thread thread-line")):
    for i, tweet in thread.tweets:
      let last = (i == thread.tweets.high and thread.more == 0)
      renderTweet(tweet, index=i, last=last)

    if thread.more != 0:
      let num = if thread.more != -1: $thread.more & " " else: ""
      let reply = if thread.more == 1: "reply" else: "replies"
      tdiv(class="status-el more-replies"):
        a(class="more-replies-text", title="Not implemented yet"):
          text $num & "more " & reply

proc renderConversation*(conversation: Conversation): VNode =
  let hasAfter = conversation.after != nil
  buildHtml(tdiv(class="conversation", id="tweets")):
    tdiv(class="main-thread"):
      if conversation.before != nil:
        tdiv(class="before-tweet thread-line"):
          for i, tweet in conversation.before.tweets:
            renderTweet(tweet, index=i)

      tdiv(class="main-tweet"):
        let afterClass = if hasAfter: "thread thread-line" else: ""
        renderTweet(conversation.tweet, class=afterClass)

      if hasAfter:
        tdiv(class="after-tweet thread-line"):
          let total = conversation.after.tweets.high
          for i, tweet in conversation.after.tweets:
            renderTweet(tweet, index=i, total=total)

    if conversation.replies.len > 0:
      tdiv(class="replies"):
        for thread in conversation.replies:
          renderReplyThread(thread)
