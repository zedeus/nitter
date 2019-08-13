import tables, macros
import karax/[karaxdsl, vdom, vstyles]

import ../types, ../prefs

proc genCheckbox(pref: string; label: string; state: bool): VNode =
  buildHtml(tdiv(class="pref-group")):
    if state:
      input(name=pref, `type`="checkbox", checked="")
    else:
      input(name=pref, `type`="checkbox")
    label(`for`=pref): text label

proc genSelect(pref: string; label: string; options: seq[string]; state: string): VNode =
  buildHtml(tdiv(class="pref-group")):
    select(name=pref):
      for opt in options:
        if opt == state:
          option(value=opt, selected=""): text opt
        else:
          option(value=opt): text opt
    label(`for`=pref): text label

proc genInput(pref: string; label: string; placeholder, state: string): VNode =
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
      let name = newLit(pref.name)
      let label = newLit(pref.label)
      let field = ident(pref.name)
      case pref.kind
      of checkbox:
        result[2].add nnkStmtList.newTree(
          nnkCall.newTree(
            ident("genCheckbox"), name, label,
            nnkDotExpr.newTree(ident("prefs"), field)))
      of select:
        let options = newLit(pref.options)
        result[2].add nnkStmtList.newTree(
          nnkCall.newTree(
            ident("genSelect"), name, label, options,
            nnkDotExpr.newTree(ident("prefs"), field)))
      of input:
        let placeholder = newLit(pref.placeholder)
        result[2].add nnkStmtList.newTree(
          nnkCall.newTree(
            ident("genInput"), name, label, placeholder,
            nnkDotExpr.newTree(ident("prefs"), field)))

proc renderPreferences*(prefs: Prefs): VNode =
  buildHtml(tdiv(class="preferences-container")):
    form(class="preferences", `method`="post", action="saveprefs"):
      fieldset:
        renderPrefs()

        button(`type`="submit", class="pref-submit"):
          text "Save preferences"
