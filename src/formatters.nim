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
  htmlgen.a(text, class=class, href=url)

proc reUrlToLink*(m: RegexMatch; s: string): string =
  let url = s[m.group(0)[0]]
  toLink(url, " " & shortLink(url))

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
  result = text.replace("\n", "<br>")
  result = result.replace(ellipsisRegex, "")
  result = result.replace(usernameRegex, reUsernameToLink)
  result = result.replace(emailRegex, reEmailToLink)
  result = result.replace(urlRegex, reUrlToLink)

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

proc getGifSrc*(tweet: Tweet): string =
  fmt"https://video.twimg.com/tweet_video/{tweet.gif}.mp4"

proc getGifThumb*(tweet: Tweet): string =
  fmt"https://pbs.twimg.com/tweet_video_thumb/{tweet.gif}.jpg"

proc formatName*(profile: Profile): string =
  result = xmltree.escape(profile.fullname)
  if profile.verified:
    result &= htmlgen.span("✔", class="verified-icon")
  elif profile.protected:
    result &= " 🔒"

proc linkUser*(profile: Profile; h: string; username=true; class=""): string =
  let text =
    if username: "@" & profile.username
    else: formatName(profile)

  if h == "":
    return htmlgen.a(text, href = &"/{profile.username}", class=class)

  let element = &"<{h} class=\"{class}\">{text}</{h}>"
  htmlgen.a(element, href = &"/{profile.username}")
