# SPDX-License-Identifier: AGPL-3.0-only
import strutils, strformat
import karax/[karaxdsl, vdom, vstyles]
import ".."/[types, utils]

const smallWebp* = "?name=small&format=webp"

proc getSmallPic*(url: string): string =
  result = url
  if "?" notin url and not url.endsWith("placeholder.png"):
    result &= smallWebp
  result = getPicUrl(result)

proc icon*(icon: string; text=""; title=""; class=""; href=""): VNode =
  var c = "icon-" & icon
  if class.len > 0: c = &"{c} {class}"
  buildHtml(tdiv(class="icon-container")):
    if href.len > 0:
      a(class=c, title=title, href=href)
    else:
      span(class=c, title=title)

    if text.len > 0:
      text " " & text

proc linkUser*(user: User, class=""): VNode =
  let
    isName = "username" notin class
    href = "/" & user.username
    nameText = if isName: user.fullname
               else: "@" & user.username

  buildHtml(a(href=href, class=class, title=nameText)):
    text nameText
    if isName and user.verified:
      icon "ok", class="verified-icon", title="Verified account"
    if isName and user.protected:
      text " "
      icon "lock", title="Protected account"

proc linkText*(text: string; class=""): VNode =
  let url = if "http" notin text: https & text else: text
  buildHtml():
    a(href=url, class=class): text text

proc hiddenField*(name, value: string): VNode =
  buildHtml():
    input(name=name, style={display: "none"}, value=value)

proc refererField*(path: string): VNode =
  hiddenField("referer", path)

proc buttonReferer*(action, text, path: string; class=""; `method`="post"): VNode =
  buildHtml(form(`method`=`method`, action=action, class=class)):
    refererField path
    button(`type`="submit"):
      text text

proc genCheckbox*(pref, label: string; state: bool): VNode =
  buildHtml(label(class="pref-group checkbox-container")):
    text label
    if state: input(name=pref, `type`="checkbox", checked="")
    else: input(name=pref, `type`="checkbox")
    span(class="checkbox")

proc genInput*(pref, label, state, placeholder: string; class=""; autofocus=true): VNode =
  let p = placeholder
  buildHtml(tdiv(class=("pref-group pref-input " & class))):
    if label.len > 0:
      label(`for`=pref): text label
    if autofocus and state.len == 0:
      input(name=pref, `type`="text", placeholder=p, value=state, autofocus="")
    else:
      input(name=pref, `type`="text", placeholder=p, value=state)

proc genSelect*(pref, label, state: string; options: seq[string]): VNode =
  buildHtml(tdiv(class="pref-group pref-input")):
    label(`for`=pref): text label
    select(name=pref):
      for opt in options:
        if opt == state:
          option(value=opt, selected=""): text opt
        else:
          option(value=opt): text opt

proc genDate*(pref, state: string): VNode =
  buildHtml(span(class="date-input")):
    input(name=pref, `type`="date", value=state)
    icon "calendar"

proc genImg*(url: string; class=""): VNode =
  buildHtml():
    img(src=getPicUrl(url), class=class, alt="")

proc getTabClass*(query: Query; tab: QueryKind): string =
  result = "tab-item"
  if query.kind == tab:
    result &= " active"

proc getAvatarClass*(prefs: Prefs): string =
  if prefs.squareAvatars:
    "avatar"
  else:
    "avatar round"
