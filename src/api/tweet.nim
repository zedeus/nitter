import httpclient, asyncdispatch, strutils, uri

import ".."/[types, parser]
import utils, consts, media

proc getTweet*(username, id, after, agent: string): Future[Conversation] {.async.} =
  let
    headers = genHeaders({
      "pragma": "no-cache",
      "x-previous-page-name": "profile"
    }, agent, base, xml=true)

    url = base / username / tweetUrl / id ? {"max_position": after}
    html = await fetchHtml(url, headers)

  if html == nil: return

  result = parseConversation(html, after)

  let
    vidsFut = getConversationVideos(result, agent)
    pollFut = getConversationPolls(result, agent)
    cardFut = getConversationCards(result, agent)

  await all(vidsFut, pollFut, cardFut)
