import strutils, sequtils, macros
import norm/sqlite

import prefs_impl, types
export genUpdatePrefs

template safeAddColumn(field: typedesc): untyped =
  try: field.addColumn
  except DbError: discard

dbFromTypes("prefs.db", "", "", "", [Prefs])

withDb:
  try:
    createTables()
  except DbError:
    discard
  Prefs.theme.safeAddColumn
  Prefs.hidePins.safeAddColumn
  Prefs.hideReplies.safeAddColumn
  Prefs.infiniteScroll.safeAddColumn

proc getDefaultPrefs(cfg: Config): Prefs =
  result = genDefaultPrefs()
  result.replaceTwitter = cfg.hostname
  result.theme = cfg.defaultTheme

proc cache*(prefs: var Prefs) =
  withDb:
    try:
      doAssert prefs.id != 0
      discard Prefs.getOne("id = ?", prefs.id)
      prefs.update()
    except AssertionError, KeyError:
      prefs.insert()

proc getPrefs*(id: string; cfg: Config): Prefs =
  if id.len == 0:
    return getDefaultPrefs(cfg)

  withDb:
    try:
      result.getOne("id = ?", id)
      if result.theme.len == 0:
        result.theme = cfg.defaultTheme
    except KeyError:
      result = getDefaultPrefs(cfg)

proc resetPrefs*(prefs: var Prefs; cfg: Config) =
  var defPrefs = getDefaultPrefs(cfg)
  defPrefs.id = prefs.id
  cache(defPrefs)
  prefs = defPrefs
