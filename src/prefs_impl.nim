# SPDX-License-Identifier: AGPL-3.0-only
import macros, tables, strutils, xmltree

type
  PrefKind* = enum
    checkbox, select, input

  Pref* = object
    name*: string
    label*: string
    kind*: PrefKind
    # checkbox
    defaultState*: bool
    # select
    defaultOption*: string
    options*: seq[string]
    # input
    defaultInput*: string
    placeholder*: string

  PrefList* = OrderedTable[string, seq[Pref]]

macro genPrefs*(prefDsl: untyped) =
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
    const `name`*: PrefList = toOrderedTable(`table`)

genPrefs:
  Display:
    theme(select, "Nitter"):
      "Theme"

    infiniteScroll(checkbox, false):
      "Infinite scrolling (experimental, requires JavaScript)"

    stickyProfile(checkbox, true):
      "Make profile sidebar stick to top"

    bidiSupport(checkbox, false):
      "Support bidirectional text (makes clicking on tweets harder)"

    hideTweetStats(checkbox, false):
      "Hide tweet stats (replies, retweets, likes)"

    hideBanner(checkbox, false):
      "Hide profile banner"

    hidePins(checkbox, false):
      "Hide pinned tweets"

    hideReplies(checkbox, false):
      "Hide tweet replies"

    squareAvatars(checkbox, false):
      "Square profile pictures"

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

  "Link replacements (blank to disable)":
    replaceTwitter(input, ""):
      "Twitter -> Nitter"
      placeholder: "Nitter hostname"

    replaceYouTube(input, ""):
      "YouTube -> Piped/Invidious"
      placeholder: "Piped hostname"

    replaceReddit(input, ""):
      "Reddit -> Teddit/Libreddit"
      placeholder: "Teddit hostname"

    replaceInstagram(input, ""):
      "Instagram -> Bibliogram"
      placeholder: "Bibliogram hostname"

iterator allPrefs*(): Pref =
  for k, v in prefList:
    for pref in v:
      yield pref

macro genDefaultPrefs*(): untyped =
  result = nnkStmtList.newTree()
  for pref in allPrefs():
    let
      ident = ident(pref.name)
      name = newLit(pref.name)
      default =
        case pref.kind
        of checkbox: newLit(pref.defaultState)
        of select: newLit(pref.defaultOption)
        of input: newLit(pref.defaultInput)

    result.add quote do:
      defaultPrefs.`ident` = cfg.get("Preferences", `name`, `default`)

macro genCookiePrefs*(cookies): untyped =
  result = nnkStmtList.newTree()
  for pref in allPrefs():
    let
      name = pref.name
      ident = ident(pref.name)
      kind = newLit(pref.kind)
      options = pref.options

    result.add quote do:
      if `name` in `cookies`:
        when `kind` == input or `name` == "theme":
          result.`ident` = `cookies`[`name`]
        elif `kind` == checkbox:
          result.`ident` = `cookies`[`name`] == "on"
        else:
          let value = `cookies`[`name`]
          if value in `options`: result.`ident` = value

macro genCookiePref*(cookies, prefName, res): untyped =
  result = nnkStmtList.newTree()
  for pref in allPrefs():
    let ident = ident(pref.name)
    if ident != prefName:
      continue

    let
      name = pref.name
      kind = newLit(pref.kind)
      options = pref.options

    result.add quote do:
      if `name` in `cookies`:
        when `kind` == input or `name` == "theme":
          `res` = `cookies`[`name`]
        elif `kind` == checkbox:
          `res` = `cookies`[`name`] == "on"
        else:
          let value = `cookies`[`name`]
          if value in `options`: `res` = value

macro genUpdatePrefs*(): untyped =
  result = nnkStmtList.newTree()
  let req = ident("request")
  for pref in allPrefs():
    let
      name = newLit(pref.name)
      kind = newLit(pref.kind)
      options = newLit(pref.options)
      default = nnkDotExpr.newTree(ident("defaultPrefs"), ident(pref.name))

    result.add quote do:
      let val = @`name`
      let isDefault =
        when `kind` == input or `name` == "theme":
          if `default`.len != val.len: false
          else: val == `default`
        elif `kind` == checkbox:
          (val == "on") == `default`
        else:
          val notin `options` or val == `default`

      if isDefault:
        savePref(`name`, "", `req`, expire=true)
      else:
        savePref(`name`, val, `req`)

macro genResetPrefs*(): untyped =
  result = nnkStmtList.newTree()
  let req = ident("request")
  for pref in allPrefs():
    let name = newLit(pref.name)
    result.add quote do:
      savePref(`name`, "", `req`, expire=true)

macro genPrefsType*(): untyped =
  let name = nnkPostfix.newTree(ident("*"), ident("Prefs"))
  result = quote do:
    type `name` = object
      discard

  for pref in allPrefs():
    result[0][2][2].add nnkIdentDefs.newTree(
      nnkPostfix.newTree(ident("*"), ident(pref.name)),
      (case pref.kind
       of checkbox: ident("bool")
       of input, select: ident("string")),
      newEmptyNode())
