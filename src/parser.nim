import strutils, options, tables, times, math
import packedjson
import packedjson / deserialiser
import types, parserutils, utils

proc parseProfile(js: JsonNode; id=""): Profile =
  if js.isNull: return
  result = Profile(
    id: if id.len > 0: id else: js{"id_str"}.getStr,
    username: js{"screen_name"}.getStr,
    fullname: js{"name"}.getStr,
    location: js{"location"}.getStr,
    bio: js{"description"}.getStr,
    userpic: js{"profile_image_url_https"}.getImageStr.replace("_normal", ""),
    banner: js.getBanner,
    following: $js{"friends_count"}.getInt,
    followers: $js{"followers_count"}.getInt,
    tweets: $js{"statuses_count"}.getInt,
    likes: $js{"favourites_count"}.getInt,
    media: $js{"media_count"}.getInt,
    verified: js{"verified"}.getBool,
    protected: js{"protected"}.getBool,
    joinDate: js{"created_at"}.getTime
  )

  result.expandProfileEntities(js)

proc parseUserShow*(js: JsonNode; username: string): Profile =
  if js.isNull:
    return Profile(username: username)

  with error, js{"errors"}:
    result = Profile(username: username)
    if error.getError == suspended:
      result.suspended = true
    return

  result = parseProfile(js)

proc parseGraphProfile*(js: JsonNode; username: string): Profile =
  if js.isNull: return
  with error, js{"errors"}:
    result = Profile(username: username)
    if error.getError == suspended:
      result.suspended = true
    return

  let user = js{"data", "user", "legacy"}
  let id = js{"data", "user", "rest_id"}.getStr
  result = parseProfile(user, id)

proc parseGraphList*(js: JsonNode): List =
  if js.isNull: return

  var list = js{"data", "user_by_screen_name", "list"}
  if list.isNull:
    list = js{"data", "list"}
  if list.isNull:
    return

  result = List(
    id: list{"id_str"}.getStr,
    name: list{"name"}.getStr.replace(' ', '-'),
    username: list{"user", "legacy", "screen_name"}.getStr,
    userId: list{"user", "legacy", "id_str"}.getStr,
    description: list{"description"}.getStr,
    members: list{"member_count"}.getInt,
    banner: list{"custom_banner_media", "media_info", "url"}.getImageStr
  )

proc parseListMembers*(js: JsonNode; cursor: string): Result[Profile] =
  result = Result[Profile](
    beginning: cursor.len == 0,
    query: Query(kind: userList)
  )

  if js.isNull: return

  result.top = js{"previous_cursor_str"}.getStr
  result.bottom = js{"next_cursor_str"}.getStr
  if result.bottom.len == 1:
    result.bottom.setLen 0

  for u in js{"users"}:
    result.content.add parseProfile(u)

proc parsePoll(js: JsonNode): Poll =
  let vals = js{"binding_values"}
  # name format is pollNchoice_*
  for i in '1' .. js{"name"}.getStr[4]:
    let choice = "choice" & i
    result.values.add parseInt(vals{choice & "_count"}.getStrVal("0"))
    result.options.add vals{choice & "_label"}.getStrVal

  let time = vals{"end_datetime_utc", "string_value"}.getDateTime
  if time > getTime():
    let timeLeft = $(time - getTime())
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
    videoId: js{"id_str"}.getStr,
    thumb: js{"media_url_https"}.getImageStr,
    views: js{"ext", "mediaStats", "r", "ok", "viewCount"}.getStr,
    available: js{"ext_media_availability", "status"}.getStr == "available",
    title: js{"ext_alt_text"}.getStr,
    durationMs: js{"duration_millis"}.getInt
    # playbackType: mp4
  )

  with title, js{"additional_media_info", "title"}:
    result.title = title.getStr

  for v in js{"video_info", "variants"}:
    result.variants.add VideoVariant(
      videoType: parseEnum[VideoType](v{"content_type"}.getStr("summary")),
      bitrate: v{"bitrate"}.getInt,
      url: v{"url"}.getStr
    )

proc parsePromoVideo(js: JsonNode): Video =
  result = Video(
    thumb: js{"player_image_large"}.getImageVal,
    available: true,
    durationMs: js{"content_duration_seconds"}.getStrVal("0").parseInt * 1000,
    playbackType: vmap,
    videoId: js{"player_content_id"}.getStrVal(js{"card_id"}.getStrVal(
        js{"amplify_content_id"}.getStrVal())),
  )

  var variant = VideoVariant(
    videoType: vmap,
    url: js{"player_hls_url"}.getStrVal(js{"player_stream_url"}.getStrVal(
        js{"amplify_url_vmap"}.getStrVal()))
  )

  if "m3u8" in variant.url:
    variant.videoType = m3u8
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
    video: some Video(videoId: js{"broadcast_media_id"}.getStrVal, thumb: image)
  )

proc parseCard(js: JsonNode; urls: JsonNode): Card =
  const imageTypes = ["summary_photo_image", "player_image", "promo_image",
                      "photo_image_full_size", "thumbnail_image", "thumbnail",
                      "event_thumbnail", "image"]
  let
    vals = ? js{"binding_values"}
    name = js{"name"}.getStr
    kind = parseEnum[CardKind](name[(name.find(":") + 1) ..< name.len], unknown)

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
  of unified, unknown:
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

proc parseTweet(js: JsonNode): Tweet =
  if js.isNull: return
  result = Tweet(
    id: js{"id_str"}.getId,
    threadId: js{"conversation_id_str"}.getId,
    replyId: js{"in_reply_to_status_id_str"}.getId,
    text: js{"full_text"}.getStr,
    time: js{"created_at"}.getTime,
    hasThread: js{"self_thread"}.notNull,
    available: true,
    profile: Profile(id: js{"user_id_str"}.getStr),
    stats: TweetStats(
      replies: js{"reply_count"}.getInt,
      retweets: js{"retweet_count"}.getInt,
      likes: js{"favorite_count"}.getInt,
      quotes: js{"quote_count"}.getInt
    )
  )

  result.expandTweetEntities(js)

  if js{"is_quote_status"}.getBool:
    result.quote = some Tweet(id: js{"quoted_status_id_str"}.getId)

  with rt, js{"retweeted_status_id_str"}:
    result.retweet = some Tweet(id: rt.getId)
    return

  with jsCard, js{"card"}:
    let name = jsCard{"name"}.getStr
    if "poll" in name:
      if "image" in name:
        result.photos.add jsCard{"binding_values", "image_large"}.getImageVal

      result.poll = some parsePoll(jsCard)
    elif name == "amplify":
      result.video = some(parsePromoVideo(jsCard{"binding_values"}))
    else:
      result.card = some parseCard(jsCard, js{"entities", "urls"})

  with jsMedia, js{"extended_entities", "media"}:
    for m in jsMedia:
      case m{"type"}.getStr
      of "photo":
        result.photos.add m{"media_url_https"}.getImageStr
      of "video":
        result.video = some(parseVideo(m))
        with user, m{"additional_media_info", "source_user"}:
          result.attribution = some(parseProfile(user))
      of "animated_gif":
        result.gif = some(parseGif(m))
      else: discard

  let withheldInCountries = (
    if js{"withheld_in_countries"}.kind == JArray:
      js{"withheld_in_countries"}.to(seq[string])
    else:
      newSeq[string]()
  )

  if js{"withheld_copyright"}.getBool or
     # XX - Content is withheld in all countries
     "XX" in withheldInCountries or
     # XY - Content is withheld due to a DMCA request.
     "XY" in withheldInCountries or
     (withheldInCountries.len > 0 and "withheld" in result.text):
    result.available = false

proc finalizeTweet(global: GlobalObjects; id: string): Tweet =
  let intId = if id.len > 0: parseBiggestInt(id) else: 0
  result = global.tweets.getOrDefault(id, Tweet(id: intId))

  if result.quote.isSome:
    let quote = get(result.quote).id
    if $quote in global.tweets:
      result.quote = some global.tweets[$quote]
    else:
      result.quote = some Tweet()

  if result.retweet.isSome:
    let rt = get(result.retweet).id
    if $rt in global.tweets:
      result.retweet = some finalizeTweet(global, $rt)
    else:
      result.retweet = some Tweet()

proc parsePin(js: JsonNode; global: GlobalObjects): Tweet =
  let pin = js{"pinEntry", "entry", "entryId"}.getStr
  if pin.len == 0: return

  let id = pin.getId
  if id notin global.tweets: return

  global.tweets[id].pinned = true
  return finalizeTweet(global, id)

proc parseGlobalObjects(js: JsonNode): GlobalObjects =
  result = GlobalObjects()
  let
    tweets = ? js{"globalObjects", "tweets"}
    users = ? js{"globalObjects", "users"}

  for k, v in users:
    result.users[k] = parseProfile(v, k)

  for k, v in tweets:
    var tweet = parseTweet(v)
    if tweet.profile.id in result.users:
      tweet.profile = result.users[tweet.profile.id]
    result.tweets[k] = tweet

proc parseThread(js: JsonNode; global: GlobalObjects): tuple[thread: Chain, self: bool] =
  result.thread = Chain()
  for t in js{"content", "timelineModule", "items"}:
    let content = t{"item", "content"}
    if "Self" in content{"tweet", "displayType"}.getStr:
      result.self = true

    let entry = t{"entryId"}.getStr
    if "show_more" in entry:
      let
        cursor = content{"timelineCursor"}
        more = cursor{"displayTreatment", "actionText"}.getStr
      result.thread.cursor = cursor{"value"}.getStr
      if more.len > 0 and more[0].isDigit():
        result.thread.more = parseInt(more[0 ..< more.find(" ")])
      else:
        result.thread.more = -1
    else:
      var tweet = finalizeTweet(global, t.getEntryId)
      if not tweet.available:
        tweet.tombstone = getTombstone(content{"tombstone"})
      result.thread.content.add tweet

proc parseConversation*(js: JsonNode; tweetId: string): Conversation =
  result = Conversation(replies: Result[Chain](beginning: true))
  let global = parseGlobalObjects(? js)

  let instructions = ? js{"timeline", "instructions"}
  if instructions.len == 0:
    return

  for e in instructions[0]{"addEntries", "entries"}:
    let entry = e{"entryId"}.getStr
    if "tweet" in entry or "tombstone" in entry:
      let tweet = finalizeTweet(global, e.getEntryId)
      if $tweet.id != tweetId:
        result.before.content.add tweet
      else:
        result.tweet = tweet
    elif "conversationThread" in entry:
      let (thread, self) = parseThread(e, global)
      if thread.content.len > 0:
        if self:
          result.after = thread
        else:
          result.replies.content.add thread
    elif "cursor-showMore" in entry:
      result.replies.bottom = e.getCursor
    elif "cursor-bottom" in entry:
      result.replies.bottom = e.getCursor

proc parseInstructions[T](res: var Result[T]; global: GlobalObjects; js: JsonNode) =
  if js.kind != JArray or js.len == 0:
    return

  for i in js:
    when T is Tweet:
      if res.beginning and i{"pinEntry"}.notNull:
        with pin, parsePin(i, global):
          res.content.add pin

    with r, i{"replaceEntry", "entry"}:
      if "top" in r{"entryId"}.getStr:
        res.top = r.getCursor
      elif "bottom" in r{"entryId"}.getStr:
        res.bottom = r.getCursor

proc parseUsers*(js: JsonNode; after=""): Result[Profile] =
  result = Result[Profile](beginning: after.len == 0)
  let global = parseGlobalObjects(? js)

  let instructions = ? js{"timeline", "instructions"}
  if instructions.len == 0: return

  result.parseInstructions(global, instructions)

  for e in instructions[0]{"addEntries", "entries"}:
    let entry = e{"entryId"}.getStr
    if "sq-I-u" in entry:
      let id = entry.getId
      if id in global.users:
        result.content.add global.users[id]
    elif "cursor-top" in entry:
      result.top = e.getCursor
    elif "cursor-bottom" in entry:
      result.bottom = e.getCursor

proc parseTimeline*(js: JsonNode; after=""): Timeline =
  result = Timeline(beginning: after.len == 0)
  let global = parseGlobalObjects(? js)

  let instructions = ? js{"timeline", "instructions"}
  if instructions.len == 0: return

  result.parseInstructions(global, instructions)

  for e in instructions[0]{"addEntries", "entries"}:
    let entry = e{"entryId"}.getStr
    if "tweet" in entry or "sq-I-t" in entry or "tombstone" in entry:
      let tweet = finalizeTweet(global, e.getEntryId)
      if not tweet.available: continue
      result.content.add tweet
    elif "cursor-top" in entry:
      result.top = e.getCursor
    elif "cursor-bottom" in entry:
      result.bottom = e.getCursor

proc parsePhotoRail*(js: JsonNode): PhotoRail =
  for tweet in js:
    let
      t = parseTweet(tweet)
      url = if t.photos.len > 0: t.photos[0]
            elif t.video.isSome: get(t.video).thumb
            elif t.gif.isSome: get(t.gif).thumb
            elif t.card.isSome: get(t.card).image
            else: ""

    if url.len == 0: continue
    result.add GalleryPhoto(url: url, tweetId: $t.id)
