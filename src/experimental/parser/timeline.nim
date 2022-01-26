import std/[strutils, tables]
import jsony
import user, ../types/timeline
from ../../types import Result, User

proc getId(id: string): string {.inline.} =
  let start = id.rfind("-")
  if start < 0: return id
  id[start + 1 ..< id.len]

proc parseUsers*(json: string; after=""): Result[User] =
  result = Result[User](beginning: after.len == 0)

  let raw = json.fromJson(Search)
  if raw.timeline.instructions.len == 0:
    return

  for e in raw.timeline.instructions[0].addEntries.entries:
    let id = e.entryId.getId
    if e.entryId.startsWith("user"):
      if id in raw.globalObjects.users:
        result.content.add toUser raw.globalObjects.users[id]
    elif e.entryId.startsWith("cursor"):
      let cursor = e.content.operation.cursor
      if cursor.cursorType == "Top":
        result.top = cursor.value
      elif cursor.cursorType == "Bottom":
        result.bottom = cursor.value
