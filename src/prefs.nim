import strutils, sequtils, macros
import prefs_impl, types

export genUpdatePrefs

static:
  var pFields: seq[string]
  for id in getTypeImpl(Prefs)[2]:
    if $id[0] == "id": continue
    pFields.add $id[0]

  let pDefs = toSeq(allPrefs()).mapIt(it.name)
  let missing = pDefs.filterIt(it notin pFields)
  if missing.len > 0:
    raiseAssert("{$1} missing from the Prefs type" % missing.join(", "))

dbFromTypes("prefs.db", "", "", "", [Prefs])

withDb:
  try:
    createTables()
  except DbError:
    discard

proc cache*(prefs: var Prefs) =
  withDb:
    try:
      doAssert prefs.id != 0
      discard Prefs.getOne("id = ?", prefs.id)
      prefs.update()
    except AssertionError, KeyError:
      prefs.insert()

proc getPrefs*(id: string): Prefs =
  if id.len == 0: return genDefaultPrefs()

  withDb:
    try:
      result.getOne("id = ?", id)
    except KeyError:
      result = genDefaultPrefs()

proc resetPrefs*(prefs: var Prefs) =
  var defPrefs = genDefaultPrefs()
  defPrefs.id = prefs.id
  cache(defPrefs)
  prefs = defPrefs
