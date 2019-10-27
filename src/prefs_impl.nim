import macros, tables, strutils, xmltree

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

# TODO: write DSL to simplify this
const prefList*: OrderedTable[string, seq[Pref]] = {
  "Privacy": @[
    Pref(kind: input, name: "replaceTwitter",
         label: "Replace Twitter links with Nitter (blank to disable)",
         defaultInput: "nitter.net", placeholder: "Nitter hostname"),

    Pref(kind: input, name: "replaceYouTube",
         label: "Replace YouTube links with Invidious (blank to disable)",
         defaultInput: "invidio.us", placeholder: "Invidious hostname")
  ],

  "Media": @[
    Pref(kind: checkbox, name: "mp4Playback",
         label: "Enable mp4 video playback",
         defaultState: true),

    Pref(kind: checkbox, name: "hlsPlayback",
         label: "Enable hls video streaming (requires JavaScript)",
         defaultState: false),

    Pref(kind: checkbox, name: "proxyVideos",
         label: "Proxy video streaming through the server (might be slow)",
         defaultState: true),

    Pref(kind: checkbox, name: "muteVideos",
         label: "Mute videos by default",
         defaultState: false),

    Pref(kind: checkbox, name: "autoplayGifs", label: "Autoplay gifs",
         defaultState: true)
  ],

  "Display": @[
    Pref(kind: select, name: "theme", label: "Theme",
         defaultOption: "Nitter"),

    Pref(kind: checkbox, name: "hideTweetStats",
         label: "Hide tweet stats (replies, retweets, likes)",
         defaultState: false),

    Pref(kind: checkbox, name: "hideBanner", label: "Hide profile banner",
         defaultState: false),

    Pref(kind: checkbox, name: "stickyProfile",
         label: "Make profile sidebar stick to top",
         defaultState: true)
  ]
}.toOrderedTable

iterator allPrefs*(): Pref =
  for k, v in prefList:
    for pref in v:
      yield pref

macro genDefaultPrefs*(): untyped =
  result = nnkObjConstr.newTree(ident("Prefs"))

  for pref in allPrefs():
    let default =
      case pref.kind
      of checkbox: newLit(pref.defaultState)
      of select: newLit(pref.defaultOption)
      of input: newLit(pref.defaultInput)

    result.add nnkExprColonExpr.newTree(ident(pref.name), default)

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
      let name = pref.name
      let options = pref.options
      let default = pref.defaultOption
      result.add quote do:
        if `name` == "theme": prefs.`ident` = `value`
        elif `value` in `options`: prefs.`ident` = `value`
        else: prefs.`ident` = `default`

  result.add quote do:
    cache(prefs)

macro genPrefsType*(): untyped =
  let name = nnkPostfix.newTree(ident("*"), ident("Prefs"))
  result = quote do:
    type `name` = object
      id* {.pk, ro.}: int

  for pref in allPrefs():
    result[0][2][2].add nnkIdentDefs.newTree(
      nnkPostfix.newTree(ident("*"), ident(pref.name)),
      (case pref.kind
       of checkbox: ident("bool")
       of input, select: ident("string")),
      newEmptyNode())
