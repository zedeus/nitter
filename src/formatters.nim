import strutils, strformat, htmlgen, xmltree, times
import regex

import types, utils

from unicode import Rune, `$`

const
  urlRegex = re"((https?|ftp)://(-\.)?([^\s/?\.#]+\.?)+([/\?][^\s\)]*)?)"
  emailRegex = re"([a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+)"
  usernameRegex = re"(^|[^A-z0-9_?])@([A-z0-9_]+)"
  picRegex = re"pic.twitter.com/[^ ]+"
  ellipsisRegex = re" ?…"
  ytRegex = re"(www.)?youtu(be.com|.be)"
  twRegex = re"(www.)?twitter.com"
  nbsp = $Rune(0x000A0)

proc stripText*(text: string): string =
  text.replace(nbsp, " ").strip()

proc shortLink*(text: string; length=28): string =
  result = text.replace(re"https?://(www.)?", "")
  if result.len > length:
    result = result[0 ..< length] & "…"

proc toLink*(url, text: string; class="timeline-link"): string =
  a(text, class=class, href=url)

proc reUrlToLink*(m: RegexMatch; s: string): string =
  let url = s[m.group(0)[0]]
  toLink(url, shortLink(url))

proc reEmailToLink*(m: RegexMatch; s: string): string =
  let url = s[m.group(0)[0]]
  toLink("mailto://" & url, url)

proc reUsernameToLink*(m: RegexMatch; s: string): string =
  var username = ""
  var pretext = ""

  let pre = m.group(0)
  let match = m.group(1)

  username = s[match[0]]

  if pre.len > 0:
    pretext = s[pre[0]]

  pretext & toLink("/" & username, "@" & username)

proc linkifyText*(text: string; prefs: Prefs): string =
  result = xmltree.escape(stripText(text))
  result = result.replace(ellipsisRegex, "")
  result = result.replace(emailRegex, reEmailToLink)
  result = result.replace(urlRegex, reUrlToLink)
  result = result.replace(usernameRegex, reUsernameToLink)
  result = result.replace(re"([^\s\(\n%])<a", "$1 <a")
  result = result.replace(re"</a>\s+([;.,!\)'%]|&apos;)", "</a>$1")
  result = result.replace(re"^\. <a", ".<a")
  if prefs.replaceYouTube.len > 0:
    result = result.replace(ytRegex, prefs.replaceYouTube)
  if prefs.replaceTwitter.len > 0:
    result = result.replace(twRegex, prefs.replaceTwitter)

proc replaceUrl*(url: string; prefs: Prefs): string =
  result = url
  if prefs.replaceYouTube.len > 0:
    result = result.replace(ytRegex, prefs.replaceYouTube)
  if prefs.replaceTwitter.len > 0:
    result = result.replace(twRegex, prefs.replaceTwitter)

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
  tweet.time.format("d/M/yyyy', ' HH:mm:ss")

proc getLink*(tweet: Tweet | Quote): string =
  &"/{tweet.profile.username}/status/{tweet.id}"

proc getTombstone*(text: string): string =
  text.replace(re"\n* *Learn more", "").stripText().strip(chars={' ', '\n'})
