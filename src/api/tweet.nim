import asyncdispatch, strutils, uri, httpclient, json, xmltree, htmlparser

import ".."/[types, parser]
import utils, consts, media

proc getTweet*(username, id, after, agent: string): Future[Conversation] {.async.} =
  let
    headers = genHeaders({
      "pragma": "no-cache",
      "x-previous-page-name": "profile",
      "accept": htmlAccept
    }, agent, base, xml=true)

    url = base / username / tweetUrl / id ? {"max_position": after}

  newClient()
  var html: XmlNode
  try:
    let resp = await client.get($url)
    if resp.code == Http403 and "suspended" in (await resp.body):
      return Conversation(tweet: Tweet(tombstone: "User has been suspended"))
    html = parseHtml(await resp.body)
  except:
    discard

  if html == nil: return

  result = parseConversation(html, after)

  await all(getConversationVideos(result, agent),
            getConversationCards(result, agent),
            getConversationPolls(result, agent))
