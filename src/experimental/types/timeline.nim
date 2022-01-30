import std/tables
import user, tweet

type
  Search* = object
    globalObjects*: GlobalObjects
    timeline*: Timeline

  GlobalObjects* = object
    users*: Table[string, RawUser]
    tweets*: Table[string, RawTweet]

  Timeline = object
    instructions*: seq[Instructions]

  Instructions = object
    addEntries*: tuple[entries: seq[Entry]]

  Entry* = object
    entryId*: string
    content*: tuple[operation: Operation]

  Operation = object
    cursor*: tuple[value, cursorType: string]

proc renameHook*(v: var Entity; fieldName: var string) =
  if fieldName == "type":
    fieldName = "kind"
