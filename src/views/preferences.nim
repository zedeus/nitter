import tables, macros, strutils, renderutils
import karax/[karaxdsl, vdom]
import ".."/[types, prefs_impl, language]

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
      of input: stmt[0].add newLit(pref.placeholder)
      of select:
        if pref.name == "theme":
          stmt[0].add ident("themes")
        else:
          stmt[0].add newLit(pref.options)

      result[2].add stmt

proc renderPreferences*(prefs: Prefs; path: string; themes: seq[string]): VNode =
  buildHtml(tdiv(class="overlay-panel")):
    fieldset(class="preferences"):
      form(`method`="post", action="/saveprefs"):
        refererField path

        renderPrefs()

        h4(class="cookie-note"):
          text lang["Preferences are stored client-side using cookies without any personal information."]

        button(`type`="submit", class="pref-submit"):
          text lang["Save preferences"]

      buttonReferer "/resetprefs", lang["Reset Preferences"], path, class="pref-reset"
