import jsony
from ../../types import Error

type
  Url* = object
    url*: string
    expandedUrl*: string
    displayUrl*: string
    indices*: Slice[int]

  ErrorObj* = object
    code*: Error
    message*: string

  Errors* = object
    errors*: seq[ErrorObj]

proc contains*(codes: set[Error]; errors: Errors): bool =
  for e in errors.errors:
    if e.code in codes:
      return true

proc parseHook*(s: string; i: var int; v: var Slice[int]) =
  var slice: array[2, int]
  parseHook(s, i, slice)
  v = slice[0] ..< slice[1]
