import strutils, strformat, times, uri, tables
import xmltree, htmlparser
import regex

import types, utils, query

from unicode import Rune, `$`

const
  ytRegex = re"([A-z.]+\.)?youtu(be\.com|\.be)"
  twRegex = re"(www\.|mobile\.)?twitter\.com"
  igRegex = re"(www\.)?instagram.com"
  cards = "cards.twitter.com/cards"
  tco = "https://t.co"
  nbsp = $Rune(0x000A0)

  wwwRegex = re"https?://(www[0-9]?\.)?"
  manifestRegex = re"(.+(.ts|.m3u8|.vmap))"
  userpicRegex = re"_(normal|bigger|mini|200x200|400x400)(\.[A-z]+)$"
  extRegex = re"(\.[A-z]+)$"
  tombstoneRegex = re"\n* *Learn more"

proc stripText*(text: string): string =
  text.replace(nbsp, " ").strip()

proc stripHtml*(text: string): string =
  var html = parseHtml(text)
  for el in html.findAll("a"):
    let link = el.attr("href")
    if "http" in link:
      el[0].text = link
  html.innerText()

proc shortLink*(text: string; length=28): string =
  result = text.replace(wwwRegex, "")
  if result.len > length:
    result = result[0 ..< length] & "…"

proc replaceUrl*(url: string; prefs: Prefs; absolute=""): string =
  result = url
  if prefs.replaceYouTube.len > 0:
    result = result.replace(ytRegex, prefs.replaceYouTube)
    if prefs.replaceYouTube in result:
      result = result.replace("/c/", "/")
  if prefs.replaceInstagram.len > 0:
    result = result.replace(igRegex, prefs.replaceInstagram)
  if prefs.replaceTwitter.len > 0:
    result = result.replace(tco, "https://" & prefs.replaceTwitter & "/t.co")
    result = result.replace(cards, prefs.replaceTwitter & "/cards")
    result = result.replace(twRegex, prefs.replaceTwitter)
  if absolute.len > 0:
    result = result.replace("href=\"/", "href=\"https://" & absolute & "/")

proc proxifyVideo*(manifest: string; proxy: bool): string =
  proc cb(m: RegexMatch; s: string): string =
    result = "https://video.twimg.com" & s[m.group(0)[0]]
    if proxy: result = getVidUrl(result)
  result = manifest.replace(manifestRegex, cb)

proc getUserpic*(userpic: string; style=""): string =
  let pic = userpic.replace(userpicRegex, "$2")
  pic.replace(extRegex, style & "$1")

proc getUserpic*(profile: Profile; style=""): string =
  getUserPic(profile.userpic, style)

proc getVideoEmbed*(cfg: Config; id: int64): string =
  &"https://{cfg.hostname}/i/videos/{id}"

proc pageTitle*(profile: Profile): string =
  &"{profile.fullname} (@{profile.username})"

proc pageDesc*(profile: Profile): string =
  if profile.bio.len > 0:
    stripHtml(profile.bio)
  else:
    "The latest tweets from " & profile.fullname

proc getJoinDate*(profile: Profile): string =
  profile.joinDate.format("'Joined' MMMM YYYY")

proc getJoinDateFull*(profile: Profile): string =
  profile.joinDate.format("h:mm tt - d MMM YYYY")

proc getTime*(tweet: Tweet): string =
  tweet.time.format("d/M/yyyy', 'HH:mm:ss")

proc getRfc822Time*(tweet: Tweet): string =
  tweet.time.format("ddd', 'd MMM yyyy HH:mm:ss 'GMT'")

proc getTweetTime*(tweet: Tweet): string =
  tweet.time.format("h:mm tt' · 'MMM d', 'YYYY")

proc getLink*(tweet: Tweet | Quote; focus=true): string =
  if tweet.id == 0: return
  result = &"/{tweet.profile.username}/status/{tweet.id}"
  if focus: result &= "#m"

proc getTombstone*(text: string): string =
  text.replace(tombstoneRegex, "").stripText().strip(chars={' ', '\n'})

proc getTwitterLink*(path: string; params: Table[string, string]): string =
  let
    twitter = parseUri("https://twitter.com")
    username = params.getOrDefault("name")
    query = initQuery(params, username)

  if "/search" notin path:
    return $(twitter / path ? filterParams(params))

  let p = {
    "f": $query.kind,
    "q": genQueryParam(query),
    "src": "typd",
    "max_position": params.getOrDefault("max_position", "0")
  }

  result = $(parseUri("https://twitter.com") / path ? p)
  if username.len > 0:
    result = result.replace("/" & username, "")

proc getLocation*(u: Profile | Tweet): (string, string) =
  if "://" in u.location: return (u.location, "")
  let loc = u.location.split(":")
  let url = if loc.len > 1: "/search?q=place:" & loc[1] else: ""
  (loc[0], url)
