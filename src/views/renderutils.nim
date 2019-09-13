import strutils
import karax/[karaxdsl, vdom]

import ../types, ../utils

proc icon*(icon: string; text=""; title=""; class=""; href=""): VNode =
  var c = "icon-" & icon
  if class.len > 0: c = c & " " & class
  buildHtml(tdiv(class="icon-container")):
    if href.len > 0:
      a(class=c, title=title, href=href)
    else:
      span(class=c, title=title)

    if text.len > 0:
      text " " & text

proc linkUser*(profile: Profile, class=""): VNode =
  let
    isName = "username" notin class
    href = "/" & profile.username
    nameText = if isName: profile.fullname
               else: "@" & profile.username

  buildHtml(a(href=href, class=class, title=nameText)):
    text nameText
    if isName and profile.verified:
      icon "ok", class="verified-icon", title="Verified account"
    if isName and profile.protected:
      text " "
      icon "lock-circled", title="Protected account"

proc genImg*(url: string; class=""): VNode =
  buildHtml():
    img(src=getPicUrl(url), class=class, alt="Image")

proc linkText*(text: string; class=""): VNode =
  let url = if "http" notin text: "http://" & text else: text
  buildHtml():
    a(href=url, class=class): text text

proc refererField*(path: string): VNode =
  buildHtml():
    verbatim "<input name=\"referer\" style=\"display: none\" value=\"$1\"/>" % path

proc iconReferer*(icon, action, path: string, title=""): VNode =
  buildHtml(form(`method`="get", action=action, class="icon-button")):
    refererField path
    button(`type`="submit"):
      icon icon, title=title

proc buttonReferer*(action, text, path: string; class=""; `method`="post"): VNode =
  buildHtml(form(`method`=`method`, action=action, class=class)):
    refererField path
    button(`type`="submit"):
      text text
