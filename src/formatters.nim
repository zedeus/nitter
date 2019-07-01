import strutils, strformat, htmlgen, xmltree, times
import regex

import ./types, ./utils

from unicode import Rune, `$`

const
  urlRegex = re"((https?|ftp)://(-\.)?([^\s/?\.#]+\.?)+([/\?][^\s\)]*)?)"
  emailRegex = re"([a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+)"
  usernameRegex = re"(^|[\s\.,>])@([A-z0-9_]+)"
  picRegex = re"pic.twitter.com/[^ ]+"
  cardRegex = re"(https?://)?cards.twitter.com/[^ ]+"
  ellipsisRegex = re" ?…"
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

proc linkifyText*(text: string): string =
  result = xmltree.escape(stripText(text))
  result = result.replace(ellipsisRegex, "")
  result = result.replace(emailRegex, reEmailToLink)
  result = result.replace(urlRegex, reUrlToLink)
  result = result.replace(usernameRegex, reUsernameToLink)
  result = result.replace(re"([^\s\(\n%])<a", "$1 <a")
  result = result.replace(re"</a>\s+([;.,!\)'%]|&apos;)", "</a>$1")

proc stripTwitterUrls*(text: string): string =
  result = text
  result = result.replace(picRegex, "")
  result = result.replace(cardRegex, "")
  result = result.replace(ellipsisRegex, "")

proc getUserpic*(userpic: string; style=""): string =
  let pic = userpic.replace(re"_(normal|bigger|mini|200x200)(\.[A-z]+)$", "$2")
  pic.replace(re"(\.[A-z]+)$", style & "$1")

proc getUserpic*(profile: Profile; style=""): string =
  getUserPic(profile.userpic, style)

proc genImg*(url: string; class=""): string =
  result = img(src = url.getSigUrl("pic"), class = class, alt = "Image")

proc linkUser*(profile: Profile; class=""): string =
  let
    username = "username" in class
    href = &"/{profile.username}"
    text = if username: "@" & profile.username
           else: xmltree.escape(profile.fullname)

  result = a(text, href = href, class = class, title = text)

  if not username and profile.verified:
    result &= span("✔", class="icon verified-icon", title="Verified account")
  if not username and profile.protected:
    result &= span("🔒", class="icon protected-icon", title="Protected account")

proc pageTitle*(profile: Profile): string =
  &"{profile.fullname} (@{profile.username}) | Nitter"

proc pageTitle*(page: string): string =
  &"{page} | Nitter"

proc getTime*(tweet: Tweet): string =
  tweet.time.format("d/M/yyyy', ' HH:mm:ss")

proc getLink*(tweet: Tweet | Quote): string =
  &"{tweet.profile.username}/status/{tweet.id}"
