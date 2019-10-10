import strutils, strformat, sequtils, times, uri, tables
import xmltree, htmlparser, htmlgen
import regex

import types, utils, query

from unicode import Rune, `$`

const
  ytRegex = re"(www.|m.)?youtu(be.com|.be)"
  twRegex = re"(www.|mobile.)?twitter.com"
  nbsp = $Rune(0x000A0)

const hostname {.strdefine.} = "nitter.net"

proc stripText*(text: string): string =
  text.replace(nbsp, " ").strip()

proc shortLink*(text: string; length=28): string =
  result = text.replace(re"https?://(www.)?", "")
  if result.len > length:
    result = result[0 ..< length] & "…"

proc replaceUrl*(url: string; prefs: Prefs; rss=false): string =
  result = url
  if prefs.replaceYouTube.len > 0:
    result = result.replace(ytRegex, prefs.replaceYouTube)
  if prefs.replaceTwitter.len > 0:
    result = result.replace(twRegex, prefs.replaceTwitter)
  if rss:
    result = result.replace("href=\"/", "href=\"https://" & hostname & "/")

proc proxifyVideo*(manifest: string; proxy: bool): string =
  proc cb(m: RegexMatch; s: string): string =
    result = "https://video.twimg.com" & s[m.group(0)[0]]
    if proxy: result = getVidUrl(result)
  result = manifest.replace(re"(.+(.ts|.m3u8|.vmap))", cb)

proc getUserpic*(userpic: string; style=""): string =
  let pic = userpic.replace(re"_(normal|bigger|mini|200x200|400x400)(\.[A-z]+)$", "$2")
  pic.replace(re"(\.[A-z]+)$", style & "$1")

proc getUserpic*(profile: Profile; style=""): string =
  getUserPic(profile.userpic, style)

proc getVideoEmbed*(id: string): string =
  &"https://twitter.com/i/videos/{id}?embed_source=facebook"

proc pageTitle*(profile: Profile): string =
  &"{profile.fullname} (@{profile.username})"

proc pageDesc*(profile: Profile): string =
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

proc getLink*(tweet: Tweet | Quote): string =
  if tweet.id.len == 0: return
  &"/{tweet.profile.username}/status/{tweet.id}"

proc getTombstone*(text: string): string =
  text.replace(re"\n* *Learn more", "").stripText().strip(chars={' ', '\n'})

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

proc getTweetPreview*(text: string): string =
  let html = parseHtml(text)
  html.innerText()
