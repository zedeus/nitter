import asyncdispatch, strutils, uri, options
import jester, karax/vdom

import router_utils
import ".."/views/[general, tweet]
import ".."/[types, api]

export vdom
export router_utils
export api, tweet, general

proc createEmbedTweetRouter*(cfg: Config) =
  router embedtweet:
    get "/embed/Tweet.html":
      let
        prefs = cookiePrefs() 
        t = (await getTweet(@"id")).tweet

      resp ($renderHead(prefs, cfg) & $renderTweet(t, prefs, getPath(), mainTweet=true))

 

