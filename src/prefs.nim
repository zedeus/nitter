import tables
import types, prefs_impl
from config import get
from parsecfg import nil

export genUpdatePrefs, genResetPrefs

var defaultPrefs*: Prefs

proc updateDefaultPrefs*(cfg: parsecfg.Config) =
  genDefaultPrefs()

proc getPrefs*(cookies: Table[string, string]): Prefs =
  result = defaultPrefs
  genCookiePrefs()
