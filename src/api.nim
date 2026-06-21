# SPDX-License-Identifier: AGPL-3.0-only
import asyncdispatch, httpclient, strutils, sequtils, sugar
import packedjson
import types, query, formatters, consts, apiutils, parser, utils
import experimental/parser

# Helper to generate params object for GraphQL requests
proc genParams(variables: string; fieldToggles = ""): seq[(string, string)] =
  result.add ("variables", variables)
  result.add ("features", gqlFeatures)
  if fieldToggles.len > 0:
    result.add ("fieldToggles", fieldToggles)

proc apiUrl(endpoint, variables: string; fieldToggles = ""; skipTid = false): ApiUrl =
  return ApiUrl(endpoint: endpoint, params: genParams(variables, fieldToggles), skipTid: skipTid)

proc apiReq(endpoint, variables: string; fieldToggles = ""; skipTid = false): ApiReq =
  let url = apiUrl(endpoint, variables, fieldToggles, skipTid)
  return ApiReq(cookie: url, oauth: url)

proc cursorParam(after: string): string =
  ## JSON-escape the user-supplied cursor so it cannot break out of the GraphQL
  ## variables object (same input-validation class as the #1411 media SSRF).
  if after.len > 0: "\"cursor\":" & $(%after) & "," else: ""

proc mediaUrl(id, cursor: string; count=20): ApiReq =
  result = ApiReq(
    cookie: apiUrl(graphUserMedia, userMediaVars % [id, cursor, $count]),
    oauth: apiUrl(graphUserMediaV2, restIdVars % [id, cursor, $count])
  )

proc userTweetsUrl(id: string; cursor: string): ApiReq =
  return apiReq(graphUserTweetsV2, restIdVars % [id, cursor, "20"], userTweetsFieldToggles)

proc userTweetsAndRepliesUrl(id: string; cursor: string): ApiReq =
  return apiReq(graphUserTweetsAndRepliesV2, restIdVars % [id, cursor, "20"], userTweetsFieldToggles, skipTid=true)

proc tweetDetailUrl(id: string; cursor: string): ApiReq =
  return apiReq(graphTweet, tweetVars % [id, cursor])
  # let cookieVars = tweetDetailVars % [id, cursor]
  # result = ApiReq(
  #   cookie: apiUrl(graphTweetDetail, cookieVars, tweetDetailFieldToggles),
  #   oauth: apiUrl(graphTweet, tweetVars % [id, cursor])
  # )

proc userUrl(username: string): ApiReq =
  let cookieVars = $(%*{"screen_name": username, "withGrokTranslatedBio": false})
  result = ApiReq(
    cookie: apiUrl(graphUser, cookieVars, tweetDetailFieldToggles),
    oauth: apiUrl(graphUserV2, $(%*{"screen_name": username}))
  )

proc getGraphUser*(username: string): Future[User] {.async.} =
  if username.len == 0: return
  let js = await fetchRaw(userUrl(username))
  result = parseGraphUser(js)

proc getGraphUserById*(id: string): Future[User] {.async.} =
  if id.len == 0 or id.any(c => not c.isDigit): return
  let
    url = apiReq(graphUserById, """{"rest_id": "$1"}""" % id)
    js = await fetchRaw(url)
  result = parseGraphUser(js)

proc getAboutAccount*(username: string): Future[AccountInfo] {.async.} =
  if username.len == 0: return
  let
    url = apiReq(graphAboutAccount, $(%*{"screenName": username}))
    js = await fetch(url)
  result = parseAboutAccount(js)

proc restReq(endpoint: string; params: seq[(string, string)] = @[]): ApiReq =
  let url = ApiUrl(endpoint: endpoint, params: params)
  ApiReq(cookie: url, oauth: url)

proc getBroadcastInfo*(id: string): Future[Broadcast] {.async.} =
  if id.len == 0: return
  let
    req = apiReq(graphBroadcast, $(%*{"id": id}))
    js = await fetch(req)
  result = parseBroadcastInfo(js)

proc fetchBroadcastStream*(mediaKey: string): Future[string] {.async.} =
  if mediaKey.len == 0: return
  let
    streamReq = restReq(restLiveStream & mediaKey)
    streamJs = await fetch(streamReq)
  result = streamJs{"source", "noRedirectPlaybackUrl"}.getStr(
    streamJs{"source", "location"}.getStr)

proc getAudioSpace*(id: string): Future[AudioSpace] {.async.} =
  if id.len == 0: return
  let
    variables = %*{
      "id": id,
      "isMetatagsQuery": false,
      "withReplays": true,
      "withListeners": true
    }
    req = apiReq(graphAudioSpace, $variables)
    js = await fetch(req)
  result = parseAudioSpace(js)

proc getGraphUserTweets*(id: string; kind: TimelineKind; after=""): Future[Profile] {.async.} =
  if id.len == 0: return
  let
    cursor = cursorParam(after)
    url = case kind
      of TimelineKind.tweets: userTweetsUrl(id, cursor)
      of TimelineKind.replies: userTweetsAndRepliesUrl(id, cursor)
      of TimelineKind.media: mediaUrl(id, cursor, 100)
    js = await fetch(url)
  result = parseGraphTimeline(js, after)

proc getGraphCommunity*(id: string): Future[Community] {.async.} =
  if id.len == 0: return
  let
    url = apiReq(graphCommunity, $(%*{"communityId": id}))
    js = await fetch(url)
  result = parseGraphCommunity(js)

proc getGraphCommunityTweets*(id: string; rankingMode: string; after=""): Future[Timeline] {.async.} =
  if id.len == 0: return
  let
    cursor = cursorParam(after)
    url = apiReq(graphCommunityTweets, communityTweetsVars % [id, cursor, rankingMode])
    js = await fetch(url)
  result = parseGraphCommunityTimeline(js, after)

proc getGraphCommunityMedia*(id: string; after=""): Future[Timeline] {.async.} =
  if id.len == 0: return
  let
    cursor = cursorParam(after)
    url = apiReq(graphCommunityMedia, communityMediaVars % [id, cursor])
    js = await fetch(url)
  result = parseGraphCommunityTimeline(js, after)

proc communitySliceReq(endpoint, variables: string): ApiReq =
  let url = ApiUrl(endpoint: endpoint, params: @[("variables", variables)])
  ApiReq(cookie: url, oauth: url)

proc getGraphCommunityMembers*(id: string; after=""): Future[Result[User]] {.async.} =
  if id.len == 0: return
  let
    cursor = if after.len > 0: $(%after) else: "null"
    url = communitySliceReq(graphCommunityMembers, communityMembersVars % [id, cursor])
    js = await fetch(url)
  result = parseGraphCommunityMembers(js, after)

proc getGraphCommunityModerators*(id: string): Future[Result[User]] {.async.} =
  if id.len == 0: return
  let
    url = communitySliceReq(graphCommunityModerators, communityMembersVars % [id, "null"])
    js = await fetch(url)
  result = parseGraphCommunityMembers(js)

proc getGraphCommunityHashtags*(id, hashtag: string; after=""): Future[Timeline] {.async.} =
  if id.len == 0 or hashtag.len == 0: return
  let
    safeTag = multiReplace(hashtag, ("\"", ""), ("\\", ""))
    cursor = cursorParam(after)
    url = apiReq(graphCommunityHashtags, communityHashtagsVars % [id, cursor, safeTag])
    js = await fetch(url)
  result = parseGraphCommunityTimeline(js, after)

proc getGraphListTweets*(id: string; after=""): Future[Timeline] {.async.} =
  if id.len == 0: return
  let
    cursor = cursorParam(after)
    url = apiReq(graphListTweets, restIdVars % [id, cursor, "20"])
    js = await fetch(url)
  result = parseGraphTimeline(js, after).tweets

proc getGraphListBySlug*(name, list: string): Future[List] {.async.} =
  let
    variables = %*{"screenName": name, "listSlug": list}
    url = apiReq(graphListBySlug, $variables)
    js = await fetch(url)
  result = parseGraphList(js)

proc getGraphList*(id: string): Future[List] {.async.} =
  let 
    url = apiReq(graphListById, $(%*{"listId": id}))
    js = await fetch(url)
  result = parseGraphList(js)

proc getGraphListMembers*(list: List; after=""): Future[Result[User]] {.async.} =
  if list.id.len == 0: return
  var
    variables = %*{
      "listId": list.id,
      "withBirdwatchPivots": false,
      "withDownvotePerspective": false,
      "withReactionsMetadata": false,
      "withReactionsPerspective": false
    }
  if after.len > 0:
    variables["cursor"] = % after
  let 
    url = apiReq(graphListMembers, $variables)
    js = await fetchRaw(url)
  result = parseGraphListMembers(js, after)

proc getGraphUserConnections(userId: string; endpoint: string; kind: QueryKind;
                              after=""): Future[Result[User]] {.async.} =
  if userId.len == 0: return
  var variables = %*{
    "userId": userId,
    "count": 20,
    "includePromotedContent": false,
    "withGrokTranslatedBio": true
  }
  if after.len > 0:
    variables["cursor"] = %after
  let
    url = apiReq(endpoint, $variables)
    js = await fetchRaw(url)
  result = parseGraphFollowers(js, after, kind)

proc getGraphFollowers*(userId: string; after=""): Future[Result[User]] {.async.} =
  result = await getGraphUserConnections(userId, graphFollowers, followers, after)

proc getGraphFollowing*(userId: string; after=""): Future[Result[User]] {.async.} =
  result = await getGraphUserConnections(userId, graphFollowing, following, after)

proc getGraphTweetResult*(id: string): Future[Tweet] {.async.} =
  if id.len == 0: return
  let
    url = apiReq(graphTweetResult, $(%*{"rest_id": id}))
    js = await fetch(url)
  result = parseGraphTweetResult(js)

proc getGraphTweet(id: string; after=""): Future[Conversation] {.async.} =
  if id.len == 0: return
  let
    cursor = cursorParam(after)
    js = await fetch(tweetDetailUrl(id, cursor))
  result = parseGraphConversation(js, id)

proc getReplies*(id, after: string): Future[Result[Chain]] {.async.} =
  result = (await getGraphTweet(id, after)).replies
  result.beginning = after.len == 0

proc getTweet*(id: string; after=""): Future[Conversation] {.async.} =
  result = await getGraphTweet(id)
  if after.len > 0:
    result.replies = await getReplies(id, after)

proc getGraphEditHistory*(id: string): Future[EditHistory] {.async.} =
  if id.len == 0: return
  let
    url = apiReq(graphTweetEditHistory, tweetEditHistoryVars % id)
    js = await fetch(url)
  result = parseGraphEditHistory(js, id)

proc getGraphTweetSearch*(query: Query; after=""): Future[Timeline] {.async.} =
  # workaround for #1372
  let maxId =
    if not after.startsWith("maxid:"): ""
    else: validateNumber(after[6..^1])

  let q = genQueryParam(query, maxId)
  if q.len == 0 or q == emptyQuery:
    return Timeline(query: query, beginning: true)

  var
    variables = %*{
      "rawQuery": q,
      "count": 20,
      "querySource": "typed_query",
      "product": "Latest",
      "withGrokTranslatedBio":true,
      "withQuickPromoteEligibilityTweetFields":false
    }

  if after.len > 0 and maxId.len == 0:
    variables["cursor"] = % after
  let
    url = apiReq(graphSearchTimeline, $variables)
    js = await fetch(url)
  result = parseGraphSearch[Tweets](js, after)
  result.query = query

  # when no more items are available the API just returns the last page in
  # full. this detects that and clears the page instead.
  if after.len > 0 and result.bottom.len > 0 and maxId.len == 0 and
     after[0..<64] == result.bottom[0..<64]:
    result.content.setLen(0)

proc getGraphUserSearch*(query: Query; after=""): Future[Result[User]] {.async.} =
  if query.text.len == 0:
    return Result[User](query: query, beginning: true)

  var
    variables = %*{
      "rawQuery": query.text,
      "count": 20,
      "querySource": "typed_query",
      "product": "People",
      "withGrokTranslatedBio":true,
      "withQuickPromoteEligibilityTweetFields":false
    }
  if after.len > 0:
    variables["cursor"] = % after
    result.beginning = false

  let 
    url = apiReq(graphSearchTimeline, $variables)
    js = await fetch(url)
  result = parseGraphSearch[User](js, after)
  result.query = query

proc getPhotoRail*(id: string): Future[PhotoRail] {.async.} =
  if id.len == 0: return
  let js = await fetch(mediaUrl(id, "", 30))
  result = parseGraphPhotoRail(js)

proc getGraphArticle*(id: string): Future[Article] {.async.} =
  if id.len == 0: return
  let
    url = apiReq(graphTweetResultByRestId, articleVars % id, articleFieldToggles)
    json = await fetchRaw(url)
  result = parseGraphArticle(json)

proc getGraphTweetResults*(ids: seq[string]): Future[seq[Tweet]] {.async.} =
  if ids.len == 0: return
  let
    idsJson = "[" & ids.mapIt("\"" & it & "\"").join(",") & "]"
    url = apiReq(graphTweetResultsByRestIds, articleBatchVars % idsJson, articleFieldToggles)
    js = await fetch(url)
  result = parseGraphTweetResults(js)

proc resolve*(url: string; prefs: Prefs): Future[string] {.async.} =
  let client = newAsyncHttpClient(maxRedirects=0)
  try:
    let resp = await client.request(url, HttpHead)
    result = resp.headers["location"].replaceUrls(prefs)
  except:
    discard
  finally:
    client.close()
