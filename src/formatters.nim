# SPDX-License-Identifier: AGPL-3.0-only
import strutils, strformat, times, uri, tables, xmltree, htmlparser, htmlgen
import std/enumerate
import regex
import types, utils, query

const
  ytRegex = re"([A-z.]+\.)?youtu(be\.com|\.be)"
  igRegex = re"(www\.)?instagram\.com"

  rdRegex = re"(?<![.b])((www|np|new|amp|old)\.)?reddit.com"
  rdShortRegex = re"(?<![.b])redd\.it\/"
  # Videos cannot be supported uniformly between Teddit and Libreddit,
  # so v.redd.it links will not be replaced.
  # Images aren't supported due to errors from Teddit when the image
  # wasn't first displayed via a post on the Teddit instance.

  twRegex = re"(?<=(?<!\S)https:\/\/|(?<=\s))(www\.|mobile\.)?twitter\.com"
  twLinkRegex = re"""<a href="https:\/\/twitter.com([^"]+)">twitter\.com(\S+)</a>"""

  cards = "cards.twitter.com/cards"
  tco = "https://t.co"

  wwwRegex = re"https?://(www[0-9]?\.)?"
  m3u8Regex = re"""url="(.+.m3u8)""""
  manifestRegex = re"\/(.+(.ts|.m4s|.m3u8|.vmap|.mp4))"
  userPicRegex = re"_(normal|bigger|mini|200x200|400x400)(\.[A-z]+)$"
  extRegex = re"(\.[A-z]+)$"
  illegalXmlRegex = re"[^\x09\x0A\x0D\x20-\uD7FF\uE000-\uFFFD\u10000-\u10FFFF]"

  twitter = parseUri("https://twitter.com")

proc getUrlPrefix*(cfg: Config): string =
  if cfg.useHttps: https & cfg.hostname
  else: "http://" & cfg.hostname

proc stripHtml*(text: string): string =
  var html = parseHtml(text)
  for el in html.findAll("a"):
    let link = el.attr("href")
    if "http" in link:
      if el.len == 0: continue
      el[0].text = link
  html.innerText()

proc sanitizeXml*(text: string): string =
  text.replace(illegalXmlRegex, "")

proc shortLink*(text: string; length=28): string =
  result = text.replace(wwwRegex, "")
  if result.len > length:
    result = result[0 ..< length] & "…"

proc replaceUrls*(body: string; prefs: Prefs; absolute=""): string =
  result = body

  if prefs.replaceYouTube.len > 0 and ytRegex in result:
    result = result.replace(ytRegex, prefs.replaceYouTube)
    if prefs.replaceYouTube in result:
      result = result.replace("/c/", "/")

  if prefs.replaceTwitter.len > 0 and
     (twRegex in result or twLinkRegex in result or tco in result):
    result = result.replace(tco, https & prefs.replaceTwitter & "/t.co")
    result = result.replace(cards, prefs.replaceTwitter & "/cards")
    result = result.replace(twRegex, prefs.replaceTwitter)
    result = result.replace(twLinkRegex, a(
      prefs.replaceTwitter & "$2", href = https & prefs.replaceTwitter & "$1"))

  if prefs.replaceReddit.len > 0 and (rdRegex in result or "redd.it" in result):
    result = result.replace(rdShortRegex, prefs.replaceReddit & "/comments/")
    result = result.replace(rdRegex, prefs.replaceReddit)
    if prefs.replaceReddit in result and "/gallery/" in result:
      result = result.replace("/gallery/", "/comments/")

  if prefs.replaceInstagram.len > 0 and igRegex in result:
    result = result.replace(igRegex, prefs.replaceInstagram)

  if absolute.len > 0 and "href" in result:
    result = result.replace("href=\"/", "href=\"" & absolute & "/")

proc getM3u8Url*(content: string): string =
  var m: RegexMatch
  if content.find(m3u8Regex, m):
    result = content[m.group(0)[0]]

proc proxifyVideo*(manifest: string; proxy: bool): string =
  proc cb(m: RegexMatch; s: string): string =
    result = "https://video.twimg.com/" & s[m.group(0)[0]]
    if proxy: result = getVidUrl(result)
  result = manifest.replace(manifestRegex, cb)

proc getUserPic*(userPic: string; style=""): string =
  let pic = userPic.replace(userPicRegex, "$2")
  pic.replace(extRegex, style & "$1")

proc getUserPic*(profile: Profile; style=""): string =
  getUserPic(profile.userPic, style)

proc getVideoEmbed*(cfg: Config; id: int64): string =
  &"{getUrlPrefix(cfg)}/i/videos/{id}"

proc pageTitle*(profile: Profile): string =
  &"{profile.fullname} (@{profile.username})"

proc pageTitle*(tweet: Tweet): string =
  &"{pageTitle(tweet.profile)}: \"{stripHtml(tweet.text)}\""

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
  tweet.time.format("MMM d', 'YYYY' · 'h:mm tt' UTC'")

proc getRfc822Time*(tweet: Tweet): string =
  tweet.time.format("ddd', 'dd MMM yyyy HH:mm:ss 'GMT'")

proc getShortTime*(tweet: Tweet): string =
  let now = now()
  let since = now - tweet.time

  if now.year != tweet.time.year:
    result = tweet.time.format("d MMM yyyy")
  elif since.inDays >= 1:
    result = tweet.time.format("MMM d")
  elif since.inHours >= 1:
    result = $since.inHours & "h"
  elif since.inMinutes >= 1:
    result = $since.inMinutes & "m"
  elif since.inSeconds > 1:
    result = $since.inSeconds & "s"
  else:
    result = "now"

proc getLink*(tweet: Tweet; focus=true): string =
  if tweet.id == 0: return
  var username = tweet.profile.username
  if username.len == 0:
    username = "i"
  result = &"/{username}/status/{tweet.id}"
  if focus: result &= "#m"

proc getTwitterLink*(path: string; params: Table[string, string]): string =
  var
    username = params.getOrDefault("name")
    query = initQuery(params, username)
    path = path

  if "," in username:
    query.fromUser = username.split(",")
    path = "/search"

  if "/search" notin path and query.fromUser.len < 2:
    return $(twitter / path)

  let p = {
    "f": if query.kind == users: "user" else: "live",
    "q": genQueryParam(query),
    "src": "typed_query"
  }

  result = $(twitter / path ? p)
  if username.len > 0:
    result = result.replace("/" & username, "")

proc getLocation*(u: Profile | Tweet): (string, string) =
  if "://" in u.location: return (u.location, "")
  let loc = u.location.split(":")
  let url = if loc.len > 1: "/search?q=place:" & loc[1] else: ""
  (loc[0], url)

proc getSuspended*(username: string): string =
  &"User \"{username}\" has been suspended"

proc titleize*(str: string): string =
  const
    lowercase = {'a'..'z'}
    delims = {' ', '('}

  result = str
  for i, c in enumerate(str):
    if c in lowercase and (i == 0 or str[i - 1] in delims):
      result[i] = c.toUpperAscii
