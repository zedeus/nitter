# SPDX-License-Identifier: AGPL-3.0-only
import std/[times, macros, htmlgen, options, algorithm, re]
import std/strutils except escape
import std/unicode except strip
from xmltree import escape
import packedjson
import types, utils, formatters

const
  unicodeOpen = "\uFFFA"
  unicodeClose = "\uFFFB"
  xmlOpen = escape("<")
  xmlClose = escape(">")

let
  unRegex = re"(^|[^A-z0-9-_./?])@([A-z0-9_]{1,15})"
  unReplace = "$1<a href=\"/$2\">@$2</a>"

  htRegex = re"(^|[^\w-_./?])([#$]|＃)([\w_]+)"
  htReplace = "$1<a href=\"/search?q=%23$3\">$2$3</a>"

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

template select*(a, b: JsonNode): untyped =
  if a.notNull: a else: b

template select*(a, b, c: JsonNode): untyped =
  if a.notNull: a elif b.notNull: b else: c

template with*(ident, value, body): untyped =
  if true:
    let ident {.inject.} = value
    if ident != nil: body

template with*(ident; value: JsonNode; body): untyped =
  if true:
    let ident {.inject.} = value
    if value.notNull: body

template getCursor*(js: JsonNode): string =
  js{"content", "operation", "cursor", "value"}.getStr

template getError*(js: JsonNode): Error =
  if js.kind != JArray or js.len == 0: null
  else: Error(js[0]{"code"}.getInt)

proc getTweetResult*(js: JsonNode; root="content"): JsonNode =
  select(
    js{root, "content", "tweet_results", "result"},
    js{root, "itemContent", "tweet_results", "result"},
    js{root, "content", "tweetResult", "result"}
  )

template getTypeName*(js: JsonNode): string =
  js{"__typename"}.getStr(js{"type"}.getStr)

template getEntryId*(e: JsonNode): string =
  e{"entryId"}.getStr(e{"entry_id"}.getStr)


template parseTime(time: string; f: static string; flen: int): DateTime =
  if time.len != flen: return
  parse(time, f, utc())

proc getDateTime*(js: JsonNode): DateTime =
  parseTime(js.getStr, "yyyy-MM-dd\'T\'HH:mm:ss\'Z\'", 20)

proc getTime*(js: JsonNode): DateTime =
  parseTime(js.getStr, "ddd MMM dd hh:mm:ss \'+0000\' yyyy", 30)

proc getTimeFromMs*(js: JsonNode): DateTime =
  let ms = js.getInt(0)
  if ms == 0: return
  let seconds = ms div 1000
  return fromUnix(seconds).utc()

proc getId*(id: string): int64 {.inline.} =
  let start = id.rfind("-")
  if start < 0:
    return parseBiggestInt(id)
  return parseBiggestInt(id[start + 1 ..< id.len])

proc getId*(js: JsonNode): int64 {.inline.} =
  case js.kind
  of JString: return js.getStr("0").getId
  of JInt: return js.getBiggestInt()
  else: return 0

template getStrVal*(js: JsonNode; default=""): string =
  js{"string_value"}.getStr(default)

proc getImageStr*(js: JsonNode): string =
  result = js.getStr
  result.removePrefix(https)
  result.removePrefix(twimg)

template getImageVal*(js: JsonNode): string =
  js{"image_value", "url"}.getImageStr

template getExpandedUrl*(js: JsonNode; fallback=""): string =
  js{"expanded_url"}.getStr(js{"url"}.getStr(fallback))

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

  # use primary color from profile picture color histogram
  with p, js{"profile_image_extensions", "mediaColor", "r", "ok", "palette"}:
    if p.len > 0:
      let pal = p[0]{"rgb"}
      result = "#"
      result.add toHex(pal{"red"}.getInt, 2)
      result.add toHex(pal{"green"}.getInt, 2)
      result.add toHex(pal{"blue"}.getInt, 2)
      return

proc getTombstone*(js: JsonNode): string =
  result = js{"text"}.getStr
  result.removeSuffix(" Learn more")

proc getMp4Resolution*(url: string): int =
  # parses the height out of a URL like this one:
  # https://video.twimg.com/ext_tw_video/<tweet-id>/pu/vid/720x1280/<random>.mp4
  const vidSep = "/vid/"
  let
    vidIdx = url.find(vidSep) + vidSep.len
    resIdx = url.find('x', vidIdx) + 1
    res = url[resIdx ..< url.find("/", resIdx)]

  try:
    return parseInt(res)
  except ValueError:
    # cannot determine resolution (e.g. m3u8/non-mp4 video)
    return 0

proc extractSlice(js: JsonNode): Slice[int] =
  result = js["indices"][0].getInt ..< js["indices"][1].getInt

proc extractUrls(result: var seq[ReplaceSlice]; js: JsonNode;
                 textLen: int; hideTwitter = false) =
  let
    url = js.getExpandedUrl
    slice = js.extractSlice

  if hideTwitter and slice.b.succ >= textLen and url.isTwitterUrl:
    if slice.a < textLen:
      result.add ReplaceSlice(kind: rkRemove, slice: slice)
  else:
    result.add ReplaceSlice(kind: rkUrl, url: url,
                            display: url.shortLink, slice: slice)

proc extractHashtags(result: var seq[ReplaceSlice]; js: JsonNode) =
  result.add ReplaceSlice(kind: rkHashtag, slice: js.extractSlice)

proc replacedWith(runes: seq[Rune]; repls: openArray[ReplaceSlice];
                  textSlice: Slice[int]): string =
  template extractLowerBound(i: int; idx): int =
    if i > 0: repls[idx].slice.b.succ else: textSlice.a

  result = newStringOfCap(runes.len)

  for i, rep in repls:
    result.add $runes[extractLowerBound(i, i - 1) ..< rep.slice.a]
    case rep.kind
    of rkHashtag:
      let
        name = $runes[rep.slice.a.succ .. rep.slice.b]
        symbol = $runes[rep.slice.a]
      result.add a(symbol & name, href = "/search?q=%23" & name)
    of rkMention:
      result.add a($runes[rep.slice], href = rep.url, title = rep.display)
    of rkUrl:
      result.add a(rep.display, href = rep.url)
    of rkRemove:
      discard

  let rest = extractLowerBound(repls.len, ^1) ..< textSlice.b
  if rest.a <= rest.b:
    result.add $runes[rest]

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
      else:
        inc j
    inc i

proc cmp(x, y: ReplaceSlice): int = cmp(x.slice.a, y.slice.b)

proc expandUserEntities*(user: var User; js: JsonNode) =
  let
    orig = user.bio.toRunes
    ent = ? js{"entities"}

  with urls, ent{"url", "urls"}:
    user.website = urls[0].getExpandedUrl

  var replacements = newSeq[ReplaceSlice]()

  with urls, ent{"description", "urls"}:
    for u in urls:
      replacements.extractUrls(u, orig.high)

  replacements.deduplicate
  replacements.sort(cmp)

  user.bio = orig.replacedWith(replacements, 0 .. orig.len)
  user.bio = user.bio.replacef(unRegex, unReplace)
                     .replacef(htRegex, htReplace)

proc expandTextEntities(tweet: Tweet; entities: JsonNode; text: string; textSlice: Slice[int];
                        replyTo=""; hasRedundantLink=false) =
  let hasCard = tweet.card.isSome

  var replacements = newSeq[ReplaceSlice]()

  with urls, entities{"urls"}:
    for u in urls:
      let urlStr = u["url"].getStr
      if urlStr.len == 0 or urlStr notin text:
        continue

      replacements.extractUrls(u, textSlice.b, hideTwitter = hasRedundantLink)

      if hasCard and u{"url"}.getStr == get(tweet.card).url:
        get(tweet.card).url = u.getExpandedUrl

  with media, entities{"media"}:
    for m in media:
      replacements.extractUrls(m, textSlice.b, hideTwitter = true)

  if "hashtags" in entities:
    for hashtag in entities["hashtags"]:
      replacements.extractHashtags(hashtag)

  if "symbols" in entities:
    for symbol in entities["symbols"]:
      replacements.extractHashtags(symbol)

  if "user_mentions" in entities:
    for mention in entities["user_mentions"]:
      let
        name = mention{"screen_name"}.getStr
        slice = mention.extractSlice
        idx = tweet.reply.find(name)

      if slice.a >= textSlice.a:
        replacements.add ReplaceSlice(kind: rkMention, slice: slice,
          url: "/" & name, display: mention["name"].getStr)
        if idx > -1 and name != replyTo:
          tweet.reply.delete idx
      elif idx == -1 and tweet.replyId != 0:
        tweet.reply.add name

  replacements.deduplicate
  replacements.sort(cmp)

  tweet.text = text.toRunes.replacedWith(replacements, textSlice).strip(leading=false)

proc expandTweetEntities*(tweet: Tweet; js: JsonNode) =
  let
    entities = ? js{"entities"}
    textRange = js{"display_text_range"}
    textSlice = textRange{0}.getInt .. textRange{1}.getInt
    hasQuote = js{"is_quote_status"}.getBool
    hasJobCard = tweet.card.isSome and get(tweet.card).kind == jobDetails

  var replyTo = ""
  if tweet.replyId != 0:
    with reply, js{"in_reply_to_screen_name"}:
      replyTo = reply.getStr
      tweet.reply.add replyTo

  tweet.expandTextEntities(entities, tweet.text, textSlice, replyTo, hasQuote or hasJobCard)

proc expandNoteTweetEntities*(tweet: Tweet; js: JsonNode) =
  let
    entities = ? js{"entity_set"}
    text = js{"text"}.getStr.multiReplace(("<", unicodeOpen), (">", unicodeClose))
    textSlice = 0..text.runeLen

  tweet.expandTextEntities(entities, text, textSlice)

  tweet.text = tweet.text.multiReplace((unicodeOpen, xmlOpen), (unicodeClose, xmlClose))

proc extractGalleryPhoto*(t: Tweet): GalleryPhoto =
  let url =
    if t.photos.len > 0: t.photos[0]
    elif t.video.isSome: get(t.video).thumb
    elif t.gif.isSome: get(t.gif).thumb
    elif t.card.isSome: get(t.card).image
    else: ""

  result = GalleryPhoto(url: url, tweetId: $t.id)
