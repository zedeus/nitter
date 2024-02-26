import std/tables
from ../../types import User

type
  Search* = object
    globalObjects*: GlobalObjects
    timeline*: Timeline

  GlobalObjects = object
    users*: Table[string, User]

  Timeline = object
    instructions*: seq[Instructions]

  Instructions = object
    addEntries*: tuple[entries: seq[Entry]]

  Entry = object
    entryId*: string
    content*: tuple[operation: Operation]

  Operation = object
    cursor*: tuple[value, cursorType: string]
