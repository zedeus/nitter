import tables, macros
import karax/[karaxdsl, vdom, vstyles]

import ../types, ../prefs

proc genCheckbox(pref, label: string; state: bool): VNode =
  buildHtml(tdiv(class="pref-group")):
    if state:
      input(name=pref, `type`="checkbox", checked="")
    else:
      input(name=pref, `type`="checkbox")
    label(`for`=pref): text label

proc genSelect(pref, label, state: string; options: seq[string]): VNode =
  buildHtml(tdiv(class="pref-group")):
    select(name=pref):
      for opt in options:
        if opt == state:
          option(value=opt, selected=""): text opt
        else:
          option(value=opt): text opt
    label(`for`=pref): text label

proc genInput(pref, label, state, placeholder: string): VNode =
  buildHtml(tdiv(class="pref-group")):
    input(name=pref, `type`="text", placeholder=placeholder, value=state)
    label(`for`=pref): text label

macro renderPrefs*(): untyped =
  result = nnkCall.newTree(
    ident("buildHtml"), ident("tdiv"), nnkStmtList.newTree())

  for header, options in prefList:
    result[2].add nnkCall.newTree(
      ident("legend"),
      nnkStmtList.newTree(
        nnkCommand.newTree(ident("text"), newLit(header))))

    for pref in options:
      let procName = ident("gen" & capitalizeAscii($pref.kind))
      let state = nnkDotExpr.newTree(ident("prefs"), ident(pref.name))
      var stmt = nnkStmtList.newTree(
        nnkCall.newTree(procName, newLit(pref.name), newLit(pref.label), state))

      case pref.kind
      of checkbox: discard
      of select: stmt[0].add newLit(pref.options)
      of input: stmt[0].add newLit(pref.placeholder)

      result[2].add stmt

proc renderPreferences*(prefs: Prefs): VNode =
  buildHtml(tdiv(class="preferences-container")):
    form(class="preferences", `method`="post", action="saveprefs"):
      fieldset:
        renderPrefs()

        button(`type`="submit", class="pref-submit"):
          text "Save preferences"
