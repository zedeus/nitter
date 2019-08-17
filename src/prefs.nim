import strutils
import types
import prefs_impl

export genUpdatePrefs

withCustomDb("prefs.db", "", "", ""):
  try:
    createTables()
  except DbError:
    discard

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

proc resetPrefs*(prefs: var Prefs) =
  var defPrefs = genDefaultPrefs()
  defPrefs.id = prefs.id
  cache(defPrefs)
  prefs = defPrefs
