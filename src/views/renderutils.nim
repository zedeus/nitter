import karax/[karaxdsl, vdom, vstyles]

import ../types, ../utils

proc linkUser*(profile: Profile, class=""): VNode =
  let
    isName = "username" notin class
    href = "/" & profile.username
    nameText = if isName: profile.fullname
               else: "@" & profile.username

  buildHtml(a(href=href, class=class, title=nameText)):
    text nameText
    if isName and profile.verified:
      span(class="icon verified-icon", title="Verified account"): text "✔"
    if isName and profile.protected:
      span(class="icon protected-icon", title="Protected account"): text "🔒"

proc genImg*(url: string; class=""): VNode =
  buildHtml():
    img(src=url.getSigUrl("pic"), class=class, alt="Image")

proc linkText*(text: string; class=""): VNode =
  let url = if "http" notin text: "http://" & text else: text
  buildHtml():
    a(href=url, class=class): text text
