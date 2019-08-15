import asyncdispatch, times, macros, tables, xmltree
import types

withCustomDb("prefs.db", "", "", ""):
  try:
    createTables()
  except DbError:
    discard

type
  PrefKind* = enum
    checkbox, select, input

  Pref* = object
    name*: string
    label*: string
    case kind*: PrefKind
    of checkbox:
      defaultState*: bool
    of select:
      defaultOption*: string
      options*: seq[string]
    of input:
      defaultInput*: string
      placeholder*: string

const prefList*: Table[string, seq[Pref]] = {
  "Privacy": @[
    Pref(kind: input, name: "replaceTwitter",
         label: "Replace Twitter links with Nitter (blank to disable)",
         defaultInput: "nitter.net", placeholder: "Nitter hostname"),

    Pref(kind: input, name: "replaceYouTube",
         label: "Replace YouTube links with Invidious (blank to disable)",
         defaultInput: "invidio.us", placeholder: "Invidious hostname")
  ],

  "Media": @[
    Pref(kind: checkbox, name: "videoPlayback",
         label: "Enable hls.js video playback (requires JavaScript)",
         defaultState: false),

    Pref(kind: checkbox, name: "autoplayGifs", label: "Autoplay gifs",
         defaultState: true),
  ],

  "Display": @[
    Pref(kind: checkbox, name: "hideTweetStats",
         label: "Hide tweet stats (replies, retweets, likes)",
         defaultState: false),

    Pref(kind: checkbox, name: "hideBanner", label: "Hide profile banner",
         defaultState: false),

    Pref(kind: checkbox, name: "stickyProfile",
         label: "Make profile sidebar stick to top",
         defaultState: true)
  ]
}.toTable

iterator allPrefs(): Pref =
  for k, v in prefList:
    for pref in v:
      yield pref

macro genDefaultPrefs*(): untyped =
  result = nnkObjConstr.newTree(ident("Prefs"))

  for pref in allPrefs():
    result.add nnkExprColonExpr.newTree(
      ident(pref.name),
      case pref.kind
      of checkbox: newLit(pref.defaultState)
      of select: newLit(pref.defaultOption)
      of input: newLit(pref.defaultInput))

proc cache*(prefs: var Prefs) =
  withCustomDb("prefs.db", "", "", ""):
    try:
      doAssert prefs.id != 0
      discard Prefs.getOne("id = ?", prefs.id)
      prefs.update()
    except AssertionError, KeyError:
      prefs.insert()

proc getPrefs*(id: string): Prefs =
  if id.len == 0: return genDefaultPrefs()

  withCustomDb("prefs.db", "", "", ""):
    try:
      result.getOne("id = ?", id)
    except KeyError:
      result = genDefaultPrefs()
      cache(result)

macro genUpdatePrefs*(): untyped =
  result = nnkStmtList.newTree()

  for pref in allPrefs():
    let ident = ident(pref.name)
    let value = nnkPrefix.newTree(ident("@"), newLit(pref.name))

    case pref.kind
    of checkbox:
      result.add quote do: prefs.`ident` = `value` == "on"
    of input:
      result.add quote do: prefs.`ident` = xmltree.escape(strip(`value`))
    of select:
      let options = pref.options
      let default = pref.defaultOption
      result.add quote do:
        if `value` in `options`: prefs.`ident` = `value`
        else: prefs.`ident` = `default`

  result.add quote do:
    cache(prefs)
