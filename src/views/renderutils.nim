import strutils, strformat, xmltree
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

proc linkText*(text: string; class=""): VNode =
  let url = if "http" notin text: "http://" & text else: text
  buildHtml():
    a(href=url, class=class): text text

proc hiddenField*(name, value: string): VNode =
  buildHtml():
    verbatim "<input name=\"$1\" style=\"display: none\" value=\"$2\"/>" % [name, value]

proc refererField*(path: string): VNode =
  hiddenField("referer", path)

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

proc genCheckbox*(pref, label: string; state: bool): VNode =
  buildHtml(label(class="pref-group checkbox-container")):
    text label
    if state: input(name=pref, `type`="checkbox", checked="")
    else: input(name=pref, `type`="checkbox")
    span(class="checkbox")

proc genInput*(pref, label, state, placeholder: string; class=""; autofocus=false): VNode =
  let s = xmltree.escape(state)
  let p = xmltree.escape(placeholder)
  let a = if autofocus: "autofocus" else: ""
  buildHtml(tdiv(class=("pref-group pref-input " & class))):
    if label.len > 0:
      label(`for`=pref): text label
    verbatim &"<input name={pref} type=\"text\" placeholder=\"{p}\" value=\"{s}\" {a}/>"

proc genSelect*(pref, label, state: string; options: seq[string]): VNode =
  buildHtml(tdiv(class="pref-group")):
    label(`for`=pref): text label
    select(name=pref):
      for opt in options:
        if opt == state:
          option(value=opt, selected=""): text opt
        else:
          option(value=opt): text opt

proc genDate*(pref, state: string): VNode =
  buildHtml(span(class="date-input")):
    if state.len > 0:
      verbatim &"<input name={pref} type=\"date\" value=\"{state}\"/>"
    else:
      verbatim &"<input name={pref} type=\"date\"/>"
    icon "calendar"

proc genImg*(url: string; class=""): VNode =
  buildHtml():
    img(src=getPicUrl(url), class=class, alt="Image")

proc getTabClass*(query: Query; tab: QueryKind): string =
  result = "tab-item"
  if query.kind == tab:
    result &= " active"
