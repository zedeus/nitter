import tables, macros, strformat, xmltree
import karax/[karaxdsl, vdom, vstyles]

import ../types, ../prefs

proc genCheckbox(pref, label: string; state: bool): VNode =
  buildHtml(tdiv(class="pref-group")):
    label(class="checkbox-container"):
      text label
      if state: input(name=pref, `type`="checkbox", checked="")
      else: input(name=pref, `type`="checkbox")
      span(class="checkbox")

proc genSelect(pref, label, state: string; options: seq[string]): VNode =
  buildHtml(tdiv(class="pref-group")):
    label(`for`=pref): text label
    select(name=pref):
      for opt in options:
        if opt == state:
          option(value=opt, selected=""): text opt
        else:
          option(value=opt): text opt

proc genInput(pref, label, state, placeholder: string): VNode =
  let s = xmltree.escape(state)
  let p = xmltree.escape(placeholder)
  buildHtml(tdiv(class="pref-group pref-input")):
    label(`for`=pref): text label
    verbatim &"<input name={pref} type=\"text\" placeholder=\"{p}\" value=\"{s}\"/>"

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
    fieldset(class="preferences"):
      form(`method`="post", action="saveprefs"):
        renderPrefs()

        button(`type`="submit"):
          text "Save preferences"

      form(`method`="post", action="resetprefs", class="pref-reset"):
        button(`type`="submit"):
          text "Reset preferences"
