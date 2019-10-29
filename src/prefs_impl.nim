import macros, tables, strutils, xmltree

type
  PrefKind* = enum
    checkbox, select, input

  Pref* = object
    name*: string
    label*: string
    kind*: PrefKind
    options*: seq[string]
    placeholder*: string
    defaultState*: bool
    defaultOption*: string
    defaultInput*: string

macro genPrefs(prefDsl: untyped) =
  var table = nnkTableConstr.newTree()
  for category in prefDsl:
    table.add nnkExprColonExpr.newTree(newLit($category[0]))
    table[^1].add nnkPrefix.newTree(newIdentNode("@"), nnkBracket.newTree())
    for pref in category[1]:
      let
        name = newLit($pref[0])
        kind = pref[1]
        label = pref[3][0]
        default = pref[2]
        defaultField =
          case parseEnum[PrefKind]($kind)
          of checkbox: ident("defaultState")
          of select: ident("defaultOption")
          of input: ident("defaultInput")

      var newPref = quote do:
        Pref(kind: `kind`, name: `name`, label: `label`, `defaultField`: `default`)

      for node in pref[3]:
        if node.kind == nnkCall:
          newPref.add nnkExprColonExpr.newTree(node[0], node[1][0])
      table[^1][1][1].add newPref

  let name = ident("prefList")
  result = quote do:
    const `name`* = toOrderedTable(`table`)

genPrefs:
  Privacy:
    replaceTwitter(input, "nitter.net"):
      "Replace Twitter links with Nitter (blank to disable)"
      placeholder: "Nitter hostname"

    replaceYouTube(input, "invidio.us"):
      "Replace YouTube links with Invidious (blank to disable)"
      placeholder: "Invidious hostname"

  Media:
    mp4Playback(checkbox, true):
      "Enable mp4 video playback"

    hlsPlayback(checkbox, false):
      "Enable hls video streaming (requires JavaScript)"

    proxyVideos(checkbox, true):
      "Proxy video streaming through the server (might be slow)"

    muteVideos(checkbox, false):
      "Mute videos by default"

    autoplayGifs(checkbox, true):
      "Autoplay gifs"

  Display:
    theme(select, "Nitter"):
      "Theme"

    stickyProfile(checkbox, true):
      "Make profile sidebar stick to top"

    hideTweetStats(checkbox, false):
      "Hide tweet stats (replies, retweets, likes)"

    hideBanner(checkbox, false):
      "Hide profile banner"

    hidePins(checkbox, false):
      "Hide pinned tweets"

    hideReplies(checkbox, false):
      "Hide tweet replies"

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
