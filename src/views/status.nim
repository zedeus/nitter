import uri
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
    if thread.content[^1].available:
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
      if thread.content.len == 0: continue
      renderReplyThread(thread, prefs, path)

    if replies.bottom.len > 0:
      renderMore(Query(), encodeUrl(replies.bottom), focus="#r")

proc renderConversation*(conv: Conversation; prefs: Prefs; path: string): VNode =
  let hasAfter = conv.after.content.len > 0
  let threadId = conv.tweet.threadId
  buildHtml(tdiv(class="conversation")):
    tdiv(class="main-thread"):
      if conv.before.content.len > 0:
        tdiv(class="before-tweet thread-line"):
          let first = conv.before.content[0]
          if threadId != first.id and (first.replyId > 0 or not first.available):
            renderEarlier(conv.before)
          for i, tweet in conv.before.content:
            renderTweet(tweet, prefs, path, index=i)

      tdiv(class="main-tweet", id="m"):
        let afterClass = if hasAfter: "thread thread-line" else: ""
        renderTweet(conv.tweet, prefs, path, class=afterClass, mainTweet=true)

      if hasAfter:
        tdiv(class="after-tweet thread-line"):
          let
            total = conv.after.content.high
            more = conv.after.more
          for i, tweet in conv.after.content:
            renderTweet(tweet, prefs, path, index=i,
                        last=(i == total and more == 0), afterTweet=true)

          if more != 0:
            renderMoreReplies(conv.after)

    if not prefs.hideReplies:
      if not conv.replies.beginning:
        renderNewer(Query(), getLink(conv.tweet), focus="#r")
      if conv.replies.content.len > 0 or conv.replies.bottom.len > 0:
        renderReplies(conv.replies, prefs, path)

    renderToTop(focus="#m")
