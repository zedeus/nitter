import strutils, times, macros, htmlgen, unicode, options, algorithm
import regex, packedjson
import types, utils, formatters

const
  unRegex = re"(^|[^A-z0-9-_./?])@([A-z0-9_]{1,15})"
  unReplace = "$1<a href=\"/$2\">@$2</a>"

type
  ReplaceSliceKind = enum
    rkRemove, rkUrl, rkHashtag, rkMention

  ReplaceSlice = object
    slice: Slice[int]
    kind: ReplaceSliceKind
    url, display: string

template isNull*(js: JsonNode): bool = js.kind == JNull
template notNull*(js: JsonNode): bool = js.kind != JNull

template `?`*(js: JsonNode): untyped =
  let j = js
  if j.isNull: return
  j

template `with`*(ident, value, body): untyped =
  block:
    let ident {.inject.} = value
    if ident != nil: body

template `with`*(ident; value: JsonNode; body): untyped =
  block:
    let ident {.inject.} = value
    if value.notNull: body

template getCursor*(js: JsonNode): string =
  js{"content", "operation", "cursor", "value"}.getStr

template getError*(js: JsonNode): Error =
  if js.kind != JArray or js.len == 0: null
  else: Error(js[0]{"code"}.getInt)

template parseTime(time: string; f: static string; flen: int): Time =
  if time.len != flen: return
  parse(time, f).toTime

proc getDateTime*(js: JsonNode): Time =
  parseTime(js.getStr, "yyyy-MM-dd\'T\'HH:mm:ss\'Z\'", 20)

proc getTime*(js: JsonNode): Time =
  parseTime(js.getStr, "ddd MMM dd hh:mm:ss \'+0000\' yyyy", 30)

proc getId*(id: string): string {.inline.} =
  let start = id.rfind("-")
  if start < 0: return id
  id[start + 1 ..< id.len]

proc getId*(js: JsonNode): int64 {.inline.} =
  case js.kind
  of JString: return parseBiggestInt(js.getStr("0"))
  of JInt: return js.getBiggestInt()
  else: return 0

proc getEntryId*(js: JsonNode): string {.inline.} =
  let entry = js{"entryId"}.getStr
  if entry.len == 0: return

  if "tweet" in entry or "sq-I-t" in entry:
    return entry.getId
  elif "tombstone" in entry:
    return js{"content", "item", "content", "tombstone", "tweet", "id"}.getStr
  else:
    echo "unknown entry: ", entry
    return

template getStrVal*(js: JsonNode; default=""): string =
  js{"string_value"}.getStr(default)

proc getImageStr*(js: JsonNode): string =
  result = js.getStr
  result.removePrefix(https)
  result.removePrefix(twimg)

template getImageVal*(js: JsonNode): string =
  js{"image_value", "url"}.getImageStr

proc getCardUrl*(js: JsonNode; kind: CardKind): string =
  result = js{"website_url"}.getStrVal
  if kind == promoVideoConvo:
    result = js{"thank_you_url"}.getStrVal(result)
  if result.startsWith("card://"):
    result = ""

proc getCardDomain*(js: JsonNode; kind: CardKind): string =
  result = js{"vanity_url"}.getStrVal(js{"domain"}.getStr)
  if kind == promoVideoConvo:
    result = js{"thank_you_vanity_url"}.getStrVal(result)

proc getCardTitle*(js: JsonNode; kind: CardKind): string =
  result = js{"title"}.getStrVal
  if kind == promoVideoConvo:
    result = js{"thank_you_text"}.getStrVal(result)
  elif kind == liveEvent:
    result = js{"event_category"}.getStrVal
  elif kind in {videoDirectMessage, imageDirectMessage}:
    result = js{"cta1"}.getStrVal

proc getBanner*(js: JsonNode): string =
  let url = js{"profile_banner_url"}.getImageStr
  if url.len > 0:
    return url & "/1500x500"

  let color = js{"profile_link_color"}.getStr
  if color.len > 0:
    return '#' & color

  # use primary color from profile picture color histrogram
  with p, js{"profile_image_extensions", "mediaColor", "r", "ok", "palette"}:
    if p.len > 0:
      let pal = p[0]{"rgb"}
      result = "#"
      result.add toHex(pal{"red"}.getInt, 2)
      result.add toHex(pal{"green"}.getInt, 2)
      result.add toHex(pal{"blue"}.getInt, 2)
      return

  return "#161616"

proc getTombstone*(js: JsonNode): string =
  result = js{"tombstoneInfo", "richText", "text"}.getStr
  result.removeSuffix(" Learn more")

proc extractSlice(js: JsonNode): Slice[int] =
  result = js["indices"][0].getInt..<js["indices"][1].getInt

proc extractUrls(result: var seq[ReplaceSlice]; js: JsonNode; textLen: int; hideTwitter = false) =
  let
    url = js["expanded_url"].getStr
    slice = js.extractSlice

  if hideTwitter and slice.b >= textLen and url.isTwitterUrl:
    if slice.a < textLen:
      result.add ReplaceSlice(kind: rkRemove, slice: slice)
  else:
    let display = url.shortLink
    result.add ReplaceSlice(kind: rkUrl, url: url, display: display, slice: slice)

proc extractHashtags(result: var seq[ReplaceSlice], js: JsonNode) =
  result.add ReplaceSlice(kind: rkHashtag, slice: js.extractSlice)

proc replacedWith(runes: seq[Rune], repls: openArray[ReplaceSlice],
                  textSlice: Slice[int]): string =
  result = newStringOfCap(runes.len)
  for i, rep in repls:
    let slice =
      if i == 0: textSlice.a ..< repls[i].slice.a
      else: repls[i - 1].slice.b.succ ..< rep.slice.a
    result.add $runes[slice]
    if rep.slice.a > textSlice.b: return
    case rep.kind
    of rkHashtag:
      let
        name = $runes[rep.slice.a.succ .. rep.slice.b]
        symbol = $runes[rep.slice.a]
      result.add a(symbol & name, href = name)
    of rkMention:
      result.add a($runes[rep.slice], href = rep.url, title = rep.display)
    of rkUrl:
      result.add a(rep.display, href = rep.url)
    of rkRemove:
      discard
  let lowerBound =
    if repls.len > 0: repls[^1].slice.b.succ
    else: textSlice.a
  result.add $runes[lowerBound ..< textSlice.b]

proc deduplicate(s: var seq[ReplaceSlice]) =
  var
    len = s.len
    i = 0
  while i < len:
    var j = i + 1
    while j < len:
      if s[i].slice.a == s[j].slice.a:
        s.del j
        dec len
        dec j
      inc j
    inc i

proc cmp(x, y: ReplaceSlice): int = cmp(x.slice.a, y.slice.b)

proc expandProfileEntities*(profile: var Profile; js: JsonNode) =
  let
    orig = profile.bio.toRunes
    ent = ? js{"entities"}

  with urls, ent{"url", "urls"}:
    profile.website = urls[0]{"expanded_url"}.getStr

  var replacements = newSeq[ReplaceSlice]()

  with urls, ent{"description", "urls"}:
    for u in urls:
      replacements.extractUrls(u, orig.high)

  if "user_mentions" in ent:
    for mention in ent["user_mentions"]:
      replacements.add ReplaceSlice(kind: rkMention, slice: mention.extractSlice,
        url: mention["screen_name"].getStr, display: mention["name"].getStr)

  replacements.deduplicate
  replacements.sort(cmp)

  profile.bio = orig.replacedWith(replacements, 0 .. orig.len)

  profile.bio = profile.bio.replace(unRegex, unReplace)

proc expandTweetEntities*(tweet: Tweet; js: JsonNode) =
  let
    orig = tweet.text.toRunes
    textRange = js{"display_text_range"}
    textSlice = textRange{0}.getInt .. textRange{1}.getInt
    hasQuote = js{"is_quote_status"}.getBool
    hasCard = tweet.card.isSome

  var replyTo = ""
  if tweet.replyId != 0:
    with reply, js{"in_reply_to_screen_name"}:
      tweet.reply.add reply.getStr
      replyTo = reply.getStr

  let ent = ? js{"entities"}

  var replacements = newSeq[ReplaceSlice]()

  with urls, ent{"urls"}:
    for u in urls:
      let urlStr = u["url"].getStr
      if urlStr.len == 0 or urlStr notin tweet.text:
        continue
      replacements.extractUrls(u, textSlice.b, hideTwitter = hasQuote)
      if hasCard and u{"url"}.getStr == get(tweet.card).url:
        get(tweet.card).url = u{"expanded_url"}.getStr

  with media, ent{"media"}:
    for m in media:
      replacements.extractUrls(m, textSlice.b, hideTwitter = true)

  if "hashtags" in ent:
    for hashtag in ent["hashtags"]:
      replacements.extractHashtags(hashtag)

  if "symbols" in ent:
    for symbol in ent["symbols"]:
      replacements.extractHashtags(symbol)

  if "user_mentions" in ent:
    for mention in ent["user_mentions"]:
      let
        name = mention{"screen_name"}.getStr
        slice = mention.extractSlice
        idx = tweet.reply.find(name)

      if slice.a >= textSlice.a:
        replacements.add ReplaceSlice(kind: rkMention, slice: slice,
          url: name, display: mention["name"].getStr)
        if idx > -1 and name != replyTo:
          tweet.reply.delete idx
      elif idx == -1 and tweet.replyId != 0:
        tweet.reply.add name

  replacements.deduplicate
  replacements.sort(cmp)

  tweet.text = orig.replacedWith(replacements, textSlice)
