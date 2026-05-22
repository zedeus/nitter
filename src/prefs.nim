# SPDX-License-Identifier: AGPL-3.0-only
import tables, strutils
import types, prefs_impl
from config import get
from parsecfg import nil

export genUpdatePrefs, genResetPrefs, genApplyPrefs

var defaultPrefs*: Prefs

proc updateDefaultPrefs*(cfg: parsecfg.Config) =
  genDefaultPrefs()

proc getPrefs*(cookies, params: Table[string, string]): Prefs =
  result = defaultPrefs
  genParsePrefs(cookies)
  genParsePrefs(params)

proc encodePrefs*(prefs: Prefs): string =
  var encPairs: seq[string]
  genEncodePrefs(prefs)
  encPairs.join(",")
