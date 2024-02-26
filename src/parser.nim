# SPDX-License-Identifier: AGPL-3.0-only
import strutils, options, times, math
import packedjson, packedjson/deserialiser
import types, parserutils, utils
import experimental/parser/unifiedcard

proc parseGraphTweet(js: JsonNode; isLegacy=false): Tweet

proc parseUser(js: JsonNode; id=""): User =
  if js.isNull: return
  result = User(
    id: if id.len > 0: id else: js{"id_str"}.getStr,
    username: js{"screen_name"}.getStr,
    fullname: js{"name"}.getStr,
    location: js{"location"}.getStr,
    bio: js{"description"}.getStr,
    userPic: js{"profile_image_url_https"}.getImageStr.replace("_normal", ""),
    banner: js.getBanner,
    following: js{"friends_count"}.getInt,
    followers: js{"followers_count"}.getInt,
    tweets: js{"statuses_count"}.getInt,
    likes: js{"favourites_count"}.getInt,
    media: js{"media_count"}.getInt,
    verifiedType: parseEnum[VerifiedType](js{"verified_type"}.getStr("None")),
    protected: js{"protected"}.getBool,
    joinDate: js{"created_at"}.getTime
  )

  result.expandUserEntities(js)

proc parseGraphUser(js: JsonNode): User =
  var user = js{"user_result", "result"}
  if user.isNull:
    user = ? js{"user_results", "result"}
  result = parseUser(user{"legacy"}, user{"rest_id"}.getStr)

  if result.verifiedType == VerifiedType.none and user{"is_blue_verified"}.getBool(false):
    result.verifiedType = blue

proc parseGraphList*(js: JsonNode): List =
  if js.isNull: return

  var list = js{"data", "user_by_screen_name", "list"}
  if list.isNull:
    list = js{"data", "list"}
  if list.isNull:
    return

  result = List(
    id: list{"id_str"}.getStr,
    name: list{"name"}.getStr,
    username: list{"user_results", "result", "legacy", "screen_name"}.getStr,
    userId: list{"user_results", "result", "rest_id"}.getStr,
    description: list{"description"}.getStr,
    members: list{"member_count"}.getInt,
    banner: list{"custom_banner_media", "media_info", "original_img_url"}.getImageStr
  )

proc parsePoll(js: JsonNode): Poll =
  let vals = js{"binding_values"}
  # name format is pollNchoice_*
  for i in '1' .. js{"name"}.getStr[4]:
    let choice = "choice" & i
    result.values.add parseInt(vals{choice & "_count"}.getStrVal("0"))
    result.options.add vals{choice & "_label"}.getStrVal

  let time = vals{"end_datetime_utc", "string_value"}.getDateTime
  if time > now():
    let timeLeft = $(time - now())
    result.status = timeLeft[0 ..< timeLeft.find(",")]
  else:
    result.status = "Final results"

  result.leader = result.values.find(max(result.values))
  result.votes = result.values.sum

proc parseGif(js: JsonNode): Gif =
  result = Gif(
    url: js{"video_info", "variants"}[0]{"url"}.getImageStr,
    thumb: js{"media_url_https"}.getImageStr
  )

proc parseVideo(js: JsonNode): Video =
  result = Video(
    thumb: js{"media_url_https"}.getImageStr,
    views: getVideoViewCount(js),
    available: true,
    title: js{"ext_alt_text"}.getStr,
    durationMs: js{"video_info", "duration_millis"}.getInt
    # playbackType: mp4
  )

  with status, js{"ext_media_availability", "status"}:
    if status.getStr.len > 0 and status.getStr.toLowerAscii != "available":
      result.available = false

  with title, js{"additional_media_info", "title"}:
    result.title = title.getStr

  with description, js{"additional_media_info", "description"}:
    result.description = description.getStr

  for v in js{"video_info", "variants"}:
    let
      contentType = parseEnum[VideoType](v{"content_type"}.getStr("summary"))
      url = v{"url"}.getStr

    result.variants.add VideoVariant(
      contentType: contentType,
      bitrate: v{"bitrate"}.getInt,
      url: url,
      resolution: if contentType == mp4: getMp4Resolution(url) else: 0
    )

proc parsePromoVideo(js: JsonNode): Video =
  result = Video(
    thumb: js{"player_image_large"}.getImageVal,
    available: true,
    durationMs: js{"content_duration_seconds"}.getStrVal("0").parseInt * 1000,
    playbackType: vmap
  )

  var variant = VideoVariant(
    contentType: vmap,
    url: js{"player_hls_url"}.getStrVal(js{"player_stream_url"}.getStrVal(
        js{"amplify_url_vmap"}.getStrVal()))
  )

  if "m3u8" in variant.url:
    variant.contentType = m3u8
    result.playbackType = m3u8

  result.variants.add variant

proc parseBroadcast(js: JsonNode): Card =
  let image = js{"broadcast_thumbnail_large"}.getImageVal
  result = Card(
    kind: broadcast,
    url: js{"broadcast_url"}.getStrVal,
    title: js{"broadcaster_display_name"}.getStrVal,
    text: js{"broadcast_title"}.getStrVal,
    image: image,
    video: some Video(thumb: image)
  )

proc parseCard(js: JsonNode; urls: JsonNode): Card =
  const imageTypes = ["summary_photo_image", "player_image", "promo_image",
                      "photo_image_full_size", "thumbnail_image", "thumbnail",
                      "event_thumbnail", "image"]
  let
    vals = ? js{"binding_values"}
    name = js{"name"}.getStr
    kind = parseEnum[CardKind](name[(name.find(":") + 1) ..< name.len], unknown)

  if kind == unified:
    return parseUnifiedCard(vals{"unified_card", "string_value"}.getStr)

  result = Card(
    kind: kind,
    url: vals.getCardUrl(kind),
    dest: vals.getCardDomain(kind),
    title: vals.getCardTitle(kind),
    text: vals{"description"}.getStrVal
  )

  if result.url.len == 0:
    result.url = js{"url"}.getStr

  case kind
  of promoVideo, promoVideoConvo, appPlayer, videoDirectMessage:
    result.video = some parsePromoVideo(vals)
    if kind == appPlayer:
      result.text = vals{"app_category"}.getStrVal(result.text)
  of broadcast:
    result = parseBroadcast(vals)
  of liveEvent:
    result.text = vals{"event_title"}.getStrVal
  of player:
    result.url = vals{"player_url"}.getStrVal
    if "youtube.com" in result.url:
      result.url = result.url.replace("/embed/", "/watch?v=")
  of audiospace, unknown:
    result.title = "This card type is not supported."
  else: discard

  for typ in imageTypes:
    with img, vals{typ & "_large"}:
      result.image = img.getImageVal
      break

  for u in ? urls:
    if u{"url"}.getStr == result.url:
      result.url = u{"expanded_url"}.getStr
      break

  if kind in {videoDirectMessage, imageDirectMessage}:
    result.url.setLen 0

  if kind in {promoImageConvo, promoImageApp, imageDirectMessage} and
     result.url.len == 0 or result.url.startsWith("card://"):
    result.url = getPicUrl(result.image)

proc parseTweet(js: JsonNode; jsCard: JsonNode = newJNull()): Tweet =
  if js.isNull: return
  result = Tweet(
    id: js{"id_str"}.getId,
    threadId: js{"conversation_id_str"}.getId,
    replyId: js{"in_reply_to_status_id_str"}.getId,
    text: js{"full_text"}.getStr,
    time: js{"created_at"}.getTime,
    hasThread: js{"self_thread"}.notNull,
    available: true,
    user: User(id: js{"user_id_str"}.getStr),
    stats: TweetStats(
      replies: js{"reply_count"}.getInt,
      retweets: js{"retweet_count"}.getInt,
      likes: js{"favorite_count"}.getInt,
      quotes: js{"quote_count"}.getInt
    )
  )

  # fix for pinned threads
  if result.hasThread and result.threadId == 0:
    result.threadId = js{"self_thread", "id_str"}.getId

  if "retweeted_status" in js:
    result.retweet = some Tweet()
  elif js{"is_quote_status"}.getBool:
    result.quote = some Tweet(id: js{"quoted_status_id_str"}.getId)

  # legacy
  with rt, js{"retweeted_status_id_str"}:
    result.retweet = some Tweet(id: rt.getId)
    return

  # graphql
  with rt, js{"retweeted_status_result", "result"}:
    # needed due to weird edgecase where the actual tweet data isn't included
    if "legacy" in rt:
      result.retweet = some parseGraphTweet(rt)
      return

  if jsCard.kind != JNull:
    let name = jsCard{"name"}.getStr
    if "poll" in name:
      if "image" in name:
        result.photos.add jsCard{"binding_values", "image_large"}.getImageVal

      result.poll = some parsePoll(jsCard)
    elif name == "amplify":
      result.video = some(parsePromoVideo(jsCard{"binding_values"}))
    else:
      result.card = some parseCard(jsCard, js{"entities", "urls"})

  result.expandTweetEntities(js)

  with jsMedia, js{"extended_entities", "media"}:
    for m in jsMedia:
      case m{"type"}.getStr
      of "photo":
        result.photos.add m{"media_url_https"}.getImageStr
      of "video":
        result.video = some(parseVideo(m))
        with user, m{"additional_media_info", "source_user"}:
          if user{"id"}.getInt > 0:
            result.attribution = some(parseUser(user))
          else:
            result.attribution = some(parseGraphUser(user))
      of "animated_gif":
        result.gif = some(parseGif(m))
      else: discard

      with url, m{"url"}:
        if result.text.endsWith(url.getStr):
          result.text.removeSuffix(url.getStr)
          result.text = result.text.strip()

  with jsWithheld, js{"withheld_in_countries"}:
    let withheldInCountries: seq[string] =
      if jsWithheld.kind != JArray: @[]
      else: jsWithheld.to(seq[string])

    # XX - Content is withheld in all countries
    # XY - Content is withheld due to a DMCA request.
    if js{"withheld_copyright"}.getBool or
       withheldInCountries.len > 0 and ("XX" in withheldInCountries or
                                        "XY" in withheldInCountries or
                                        "withheld" in result.text):
      result.text.removeSuffix(" Learn more.")
      result.available = false

proc parsePhotoRail*(js: JsonNode): PhotoRail =
  with error, js{"error"}:
    if error.getStr == "Not authorized.":
      return

  for tweet in js:
    let
      t = parseTweet(tweet, js{"tweet_card"})
      url = if t.photos.len > 0: t.photos[0]
            elif t.video.isSome: get(t.video).thumb
            elif t.gif.isSome: get(t.gif).thumb
            elif t.card.isSome: get(t.card).image
            else: ""

    if url.len == 0: continue
    result.add GalleryPhoto(url: url, tweetId: $t.id)

proc parseGraphTweet(js: JsonNode; isLegacy=false): Tweet =
  if js.kind == JNull:
    return Tweet()

  case js{"__typename"}.getStr
  of "TweetUnavailable":
    return Tweet()
  of "TweetTombstone":
    with text, js{"tombstone", "richText"}:
      return Tweet(text: text.getTombstone)
    with text, js{"tombstone", "text"}:
      return Tweet(text: text.getTombstone)
    return Tweet()
  of "TweetPreviewDisplay":
    return Tweet(text: "You're unable to view this Tweet because it's only available to the Subscribers of the account owner.")
  of "TweetWithVisibilityResults":
    return parseGraphTweet(js{"tweet"}, isLegacy)
  else:
    discard

  if not js.hasKey("legacy"):
    return Tweet()

  var jsCard = copy(js{if isLegacy: "card" else: "tweet_card", "legacy"})
  if jsCard.kind != JNull:
    var values = newJObject()
    for val in jsCard["binding_values"]:
      values[val["key"].getStr] = val["value"]
    jsCard["binding_values"] = values

  result = parseTweet(js{"legacy"}, jsCard)
  result.id = js{"rest_id"}.getId
  result.user = parseGraphUser(js{"core"})

  with noteTweet, js{"note_tweet", "note_tweet_results", "result"}:
    result.expandNoteTweetEntities(noteTweet)

  if result.quote.isSome:
    result.quote = some(parseGraphTweet(js{"quoted_status_result", "result"}, isLegacy))

proc parseGraphThread(js: JsonNode): tuple[thread: Chain; self: bool] =
  for t in js{"content", "items"}:
    let entryId = t{"entryId"}.getStr
    if "cursor-showmore" in entryId:
      let cursor = t{"item", "content", "value"}
      result.thread.cursor = cursor.getStr
      result.thread.hasMore = true
    elif "tweet" in entryId:
      let
        isLegacy = t{"item"}.hasKey("itemContent")
        (contentKey, resultKey) = if isLegacy: ("itemContent", "tweet_results")
                                  else: ("content", "tweetResult")

      with content, t{"item", contentKey}:
        result.thread.content.add parseGraphTweet(content{resultKey, "result"}, isLegacy)

        if content{"tweetDisplayType"}.getStr == "SelfThread":
          result.self = true

proc parseGraphTweetResult*(js: JsonNode): Tweet =
  with tweet, js{"data", "tweet_result", "result"}:
    result = parseGraphTweet(tweet, false)

proc parseGraphConversation*(js: JsonNode; tweetId: string): Conversation =
  result = Conversation(replies: Result[Chain](beginning: true))

  let instructions = ? js{"data", "threaded_conversation_with_injections_v2", "instructions"}
  if instructions.len == 0:
    return

  for e in instructions[0]{"entries"}:
    let entryId = e{"entryId"}.getStr
    if entryId.startsWith("tweet"):
      with tweetResult, e{"content", "itemContent", "tweet_results", "result"}:
        let tweet = parseGraphTweet(tweetResult, true)

        if not tweet.available:
          tweet.id = parseBiggestInt(entryId.getId())

        if $tweet.id == tweetId:
          result.tweet = tweet
        else:
          result.before.content.add tweet
    elif entryId.startsWith("tombstone"):
      let id = entryId.getId()
      let tweet = Tweet(
        id: parseBiggestInt(id),
        available: false,
        text: e{"content", "itemContent", "tombstoneInfo", "richText"}.getTombstone
      )

      if id == tweetId:
        result.tweet = tweet
      else:
        result.before.content.add tweet
    elif entryId.startsWith("conversationthread"):
      let (thread, self) = parseGraphThread(e)
      if self:
        result.after = thread
      else:
        result.replies.content.add thread
    elif entryId.startsWith("cursor-bottom"):
      result.replies.bottom = e{"content", "itemContent", "value"}.getStr

proc parseGraphTimeline*(js: JsonNode; root: string; after=""): Profile =
  result = Profile(tweets: Timeline(beginning: after.len == 0))

  let instructions =
    if root == "list": ? js{"data", "list", "timeline_response", "timeline", "instructions"}
    else: ? js{"data", "user_result", "result", "timeline_response", "timeline", "instructions"}

  if instructions.len == 0:
    return

  for i in instructions:
    if i{"__typename"}.getStr == "TimelineAddEntries":
      for e in i{"entries"}:
        let entryId = e{"entryId"}.getStr
        if entryId.startsWith("tweet"):
          with tweetResult, e{"content", "content", "tweetResult", "result"}:
            let tweet = parseGraphTweet(tweetResult, false)
            if not tweet.available:
              tweet.id = parseBiggestInt(entryId.getId())
            result.tweets.content.add tweet
        elif "-conversation-" in entryId or entryId.startsWith("homeConversation"):
          let (thread, self) = parseGraphThread(e)
          result.tweets.content.add thread.content
        elif entryId.startsWith("cursor-bottom"):
          result.tweets.bottom = e{"content", "value"}.getStr
    if after.len == 0 and i{"__typename"}.getStr == "TimelinePinEntry":
      with tweetResult, i{"entry", "content", "content", "tweetResult", "result"}:
        let tweet = parseGraphTweet(tweetResult, false)
        tweet.pinned = true
        if not tweet.available and tweet.tombstone.len == 0:
          let entryId = i{"entry", "entryId"}.getEntryId
          if entryId.len > 0:
            tweet.id = parseBiggestInt(entryId)
        result.pinned = some tweet

proc parseGraphSearch*[T: User | Tweets](js: JsonNode; after=""): Result[T] =
  result = Result[T](beginning: after.len == 0)

  let instructions = js{"data", "search_by_raw_query", "search_timeline", "timeline", "instructions"}
  if instructions.len == 0:
    return

  for instruction in instructions:
    let typ = instruction{"type"}.getStr
    if typ == "TimelineAddEntries":
      for e in instruction{"entries"}:
        let entryId = e{"entryId"}.getStr
        when T is Tweets:
          if entryId.startsWith("tweet"):
            with tweetRes, e{"content", "itemContent", "tweet_results", "result"}:
              let tweet = parseGraphTweet(tweetRes)
              if not tweet.available:
                tweet.id = parseBiggestInt(entryId.getId())
              result.content.add tweet
        elif T is User:
          if entryId.startsWith("user"):
            with userRes, e{"content", "itemContent"}:
              result.content.add parseGraphUser(userRes)

        if entryId.startsWith("cursor-bottom"):
          result.bottom = e{"content", "value"}.getStr
    elif typ == "TimelineReplaceEntry":
      if instruction{"entry_id_to_replace"}.getStr.startsWith("cursor-bottom"):
        result.bottom = instruction{"entry", "content", "value"}.getStr
