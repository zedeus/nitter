import strutils, strformat, sequtils, htmlgen, xmltree, times, uri, tables
import regex

import types, utils, query

from unicode import Rune, `$`

const
  urlRegex = re"((https?|ftp)://(-\.)?([^\s/?\.#]+\.?)+([/\?][^\s\)]*)?)"
  emailRegex = re"([a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+)"
  usernameRegex = re"(^|[^A-z0-9_?\/])@([A-z0-9_]+)"
  picRegex = re"pic.twitter.com/[^ ]+"
  ellipsisRegex = re" ?…"
  hashtagRegex = re"([^\S]|^)([#$]\w+)"
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

proc toLink*(url, text: string): string =
  a(text, href=url)

proc reUrlToShortLink*(m: RegexMatch; s: string): string =
  let url = s[m.group(0)[0]]
  toLink(url, shortLink(url))

proc reUrlToLink*(m: RegexMatch; s: string): string =
  let url = s[m.group(0)[0]]
  toLink(url, url.replace(re"https?://(www.)?", ""))

proc reEmailToLink*(m: RegexMatch; s: string): string =
  let url = s[m.group(0)[0]]
  toLink("mailto://" & url, url)

proc reHashtagToLink*(m: RegexMatch; s: string): string =
  result = if m.group(0).len > 0: s[m.group(0)[0]] else: ""
  let hash = s[m.group(1)[0]]
  let link = toLink("/search?q=" & encodeUrl(hash), hash)
  if hash.any(isAlphaAscii):
    result &= link
  else:
    result &= hash

proc reUsernameToLink*(m: RegexMatch; s: string): string =
  var username = ""
  var pretext = ""

  let pre = m.group(0)
  let match = m.group(1)

  username = s[match[0]]

  if pre.len > 0:
    pretext = s[pre[0]]

  pretext & toLink("/" & username, "@" & username)

proc reUsernameToFullLink*(m: RegexMatch; s: string): string =
  result = reUsernameToLink(m, s)
  result = result.replace("href=\"/", &"href=\"https://{hostname}/")

proc replaceUrl*(url: string; prefs: Prefs): string =
  result = url
  if prefs.replaceYouTube.len > 0:
    result = result.replace(ytRegex, prefs.replaceYouTube)
  if prefs.replaceTwitter.len > 0:
    result = result.replace(twRegex, prefs.replaceTwitter)

proc linkifyText*(text: string; prefs: Prefs; rss=false): string =
  result = xmltree.escape(stripText(text))
  result = result.replace(ellipsisRegex, " ")
  result = result.replace(emailRegex, reEmailToLink)
  if rss:
    result = result.replace(urlRegex, reUrlToLink)
    result = result.replace(usernameRegex, reUsernameToFullLink)
  else:
    result = result.replace(urlRegex, reUrlToShortLink)
    result = result.replace(usernameRegex, reUsernameToLink)
  result = result.replace(hashtagRegex, reHashtagToLink)
  result = result.replace(re"([^\s\(\n%])<a", "$1 <a")
  result = result.replace(re"</a>\s+([;.,!\)'%]|&apos;)", "</a>$1")
  result = result.replace(re"^\. <a", ".<a")
  result = result.replaceUrl(prefs)

proc stripTwitterUrls*(text: string): string =
  result = text
  result = result.replace(picRegex, "")
  result = result.replace(ellipsisRegex, "")

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

  var after = params.getOrDefault("after", "0")
  if query.kind notin {userList, users} and "/members" notin path:
    after = after.genPos()

  var paramList = filterParams(params).mapIt(
    if it[0] == "after": ("max_position", after) else: it)

  if "/search" notin path:
    return $(twitter / path ? paramList)

  let p = {
    "f": $query.kind,
    "q": genQueryParam(query),
    "src": "typd",
    "max_position": after
  }

  result = $(parseUri("https://twitter.com") / path ? p)
  if username.len > 0:
    result = result.replace("/" & username, "")
