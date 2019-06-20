#? stdtmpl(subsChar = '$', metaChar = '#')
#import xmltree, strutils, uri
#import ../types, ../formatters, ./tweet
#
#proc renderConversation*(conversation: Conversation): string =
<div class="conversation" id="tweets">
  <div class="main-thread">
    #if conversation.before.len > 0:
    <div class="before-tweet">
      #for tweet in conversation.before:
      ${renderTweet(tweet)}
      #end for
    </div>
    #end if
    <div class="main-tweet">
      ${renderTweet(conversation.tweet)}
    </div>
    #if conversation.after.len > 0:
    <div class="after-tweet">
      #for tweet in conversation.after:
      ${renderTweet(tweet)}
      #end for
    </div>
    #end if
  </div>
  #if conversation.replies.len > 0:
  <div class="replies">
    #for thread in conversation.replies:
    <div class="thread">
      #for tweet in thread:
      ${renderTweet(tweet)}
      #end for
    </div>
    #end for
  </div>
  #end if
</div>
#end proc
