import strutils, strformat, htmlgen, xmltree
import regex

import ./types, ./utils

const
  urlRegex = re"((https?|ftp)://(-\.)?([^\s/?\.#]+\.?)+(/[^\s]*)?)"
  emailRegex = re"([a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+)"
  usernameRegex = re"(^|[^\S\n]|\.)@([A-z0-9_]+)"
  picRegex = re"pic.twitter.com/[^ ]+"
  cardRegex = re"(https?://)?cards.twitter.com/[^ ]+"
  ellipsisRegex = re" ?…"

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
  var
    username = ""
    pretext = ""

  let
    pre = m.group(0)
    match = m.group(1)

  username = s[match[0]]

  if pre.len > 0:
    pretext = s[pre[0]]

  pretext & toLink("/" & username, "@" & username)

proc linkifyText*(text: string): string =
  result = text.strip()
  result = result.replace("\n", "<br>")
  result = result.replace(ellipsisRegex, "")
  result = result.replace(usernameRegex, reUsernameToLink)
  result = result.replace(emailRegex, reEmailToLink)
  result = result.replace(urlRegex, reUrlToLink)
  result = result.replace(re"([A-z0-9\):.])<a", "$1 <a")
  result = result.replace(re"</a> ([.,\)])", "</a>$1")

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
