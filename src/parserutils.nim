import json, strutils, times, tables, macros, htmlgen, uri, unicode, options
import regex
import types, utils, formatters

const
  unRegex = re"(^|[^A-z0-9-_./?])@([A-z0-9_]{1,15})"
  unReplace = "$1<a href=\"/$2\">@$2</a>"

  htRegex = re"(^|[^A-z0-9-_./?])#([A-z0-9_]+)"
  htReplace = "$1<a href=\"/search?q=%23$2\">#$2</a>"

template `?`*(js: JsonNode): untyped =
  let j = js
  if j == nil: return
  else: j

template `with`*(ident, value, body): untyped =
  block:
    let ident {.inject.} = value
    if ident != nil:
      body

template `with`*(ident; value: JsonNode; body): untyped =
  block:
    let ident {.inject.} = value
    if ident != nil and ident.kind != JNull:
      body

proc getCursor*(js: JsonNode): string =
  js{"content", "operation", "cursor", "value"}.getStr

proc parseTime(time: string; f: static string; flen: int): Time =
  if time.len != flen: return
  parseTime(time, f, utc())

proc getDateTime*(js: JsonNode): Time =
  parseTime(js.getStr, "yyyy-MM-dd\'T\'HH:mm:ss\'Z\'", 20)

proc getTime*(js: JsonNode): Time =
  parseTime(js.getStr, "ddd MMM dd hh:mm:ss \'+0000\' yyyy", 30)

proc getId*(id: string): string =
  let start = id.rfind("-")
  if start < 0: return id
  id[start + 1 ..< id.len]

proc getId*(js: JsonNode): int64 =
  if js == nil: return
  case js.kind
  of JString: return parseBiggestInt(js.getStr("0"))
  of JInt: return js.getBiggestInt()
  else: return 0

proc getStrVal*(js: JsonNode; default=""): string =
  if js == nil: return default
  js{"string_value"}.getStr(default)

proc getCardUrl*(js: JsonNode; kind: CardKind): string =
  result = js{"website_url"}.getStrVal
  if kind == promoVideoConvo:
    result = js{"thank_you_url"}.getStrVal(result)

proc getCardDomain*(js: JsonNode; kind: CardKind): string =
  result = js{"vanity_url"}.getStrVal(js{"domain"}.getStr)
  if kind == promoVideoConvo:
    result = js{"thank_you_vanity_url"}.getStrVal(result)

proc getCardTitle*(js: JsonNode; kind: CardKind): string =
  result = js{"title"}.getStrVal
  if kind == promoVideoConvo:
    result = js{"thank_you_text"}.getStrVal(result)

proc getBanner*(js: JsonNode): string =
  let url = js{"profile_banner_url"}.getStr
  if url.len > 0:
    return url & "/1500x500"

  let color = js{"profile_link_color"}.getStr
  if color.len > 0:
    return '#' & color

  # use primary color from profile picture color histrogram
  with p, js{"profile_image_extensions", "mediaColor", "r", "ok", "palette"}:
    if p.len > 0:
      let pal = p[0]{"rgb"}.getFields
      result = "#"
      result.add toHex(pal["red"].getInt, 2)
      result.add toHex(pal["green"].getInt, 2)
      result.add toHex(pal["blue"].getInt, 2)
      return

  return "#161616"

proc getTombstone*(js: JsonNode): string =
  let epitaph = js{"epitaph"}.getStr
  case epitaph
  of "Suspended":
    result = "This tweet is from a suspended account."
  of "Protected":
    result = "This account owner limits who can view their tweets."
  of "Missing":
    result = "This tweet is unavailable."
  else:
    result = js{"tombstoneInfo", "richText", "text"}.getStr
    if epitaph.len > 0 or result.len > 0:
      echo "Unknown tombstone (", epitaph, "): ", result

template getSlice(text: string; slice: seq[int]): string =
  text.runeSubStr(slice[0], slice[1] - slice[0])

proc getSlice(text: string; js: JsonNode): string =
  if js == nil or js.kind != JArray or js.len < 2 or
    js[0].kind != JInt: return text

  let slice = js.to(seq[int])
  text.getSlice(slice)

proc expandUrl(text: var string; js: JsonNode; tLen: int; hideTwitter=false) =
  let u = js{"url"}.getStr
  if u.len == 0 or u notin text:
    return

  let
    url = js{"expanded_url"}.getStr
    slice = js{"indices"}.to(seq[int])

  if hideTwitter and slice[1] >= tLen and url.isTwitterUrl:
    text = text.replace(u, "")
    text.removeSuffix(' ')
    text.removeSuffix('\n')
  else:
    text = text.replace(u, a(shortLink(url), href=url))

proc expandTag(text: var string; js: JsonNode; prefix: char) =
  let
    tag = prefix & js{"text"}.getStr
    html = a(tag, href=("/search?q=" & encodeUrl(tag)))
    oldLen = text.len

  text = text.replaceWord(tag, html)

  # for edgecases with emojis or other characters around the tag
  if text.len == oldLen:
    text = text.replace(tag, html)

proc expandMention(text: var string; orig: string; js: JsonNode) =
  let
    name = js{"name"}.getStr
    href = '/' & js{"screen_name"}.getStr
    uname = orig.getSlice(js{"indices"})
  text = text.replace(uname, a(uname, href=href, title=name))

proc expandProfileEntities*(profile: var Profile; js: JsonNode) =
  let
    orig = profile.bio
    ent = ? js{"entities"}

  with urls, ent{"url", "urls"}:
    profile.website = urls[0]{"expanded_url"}.getStr

  with urls, ent{"description", "urls"}:
    for u in urls: profile.bio.expandUrl(u, orig.high)

  profile.bio = profile.bio.replace(unRegex, unReplace)
                           .replace(htRegex, htReplace)

  for mention in ? ent{"user_mentions"}:
    profile.bio.expandMention(orig, mention)

proc expandTweetEntities*(tweet: Tweet; js: JsonNode) =
  let
    orig = tweet.text
    slice = js{"display_text_range"}.to(seq[int])
    hasQuote = js{"is_quote_status"}.getBool
    hasCard = tweet.card.isSome

  tweet.text = tweet.text.getSlice(slice)

  var replyTo = ""
  if tweet.replyId != 0:
    with reply, js{"in_reply_to_screen_name"}:
      tweet.reply.add reply.getStr
      replyTo = reply.getStr

  let ent = ? js{"entities"}

  with urls, ent{"urls"}:
    for u in urls:
      tweet.text.expandUrl(u, slice[1], hasQuote)
      if hasCard and u{"url"}.getStr == get(tweet.card).url:
        get(tweet.card).url = u{"expanded_url"}.getStr

  with media, ent{"media"}:
    for m in media: tweet.text.expandUrl(m, slice[1], hideTwitter=true)

  with hashes, ent{"hashtags"}:
    for h in hashes: tweet.text.expandTag(h, '#')

  with symbols, ent{"symbols"}:
    for s in symbols: tweet.text.expandTag(s, '$')

  for mention in ? ent{"user_mentions"}:
    let
      name = mention{"screen_name"}.getStr
      idx = tweet.reply.find(name)

    if mention{"indices"}[0].getInt >= slice[0]:
      tweet.text.expandMention(orig, mention)
      if idx > -1 and name != replyTo:
        tweet.reply.delete idx
    elif idx == -1 and tweet.replyId != 0:
      tweet.reply.add name
