import options
import jsony
import user, ../types/[graphuser, graphlistmembers]
from ../../types import User, Result, Query, QueryKind

proc parseGraphUser*(json: string): User =
  if json.len == 0 or json[0] != '{':
    return

  let raw = json.fromJson(GraphUser)

  if raw.data.userResult.result.unavailableReason.get("") == "Suspended":
    return User(suspended: true)

  result = toUser raw.data.userResult.result.legacy
  result.id = raw.data.userResult.result.restId
  result.verified = result.verified or raw.data.userResult.result.isBlueVerified

proc parseGraphListMembers*(json, cursor: string): Result[User] =
  result = Result[User](
    beginning: cursor.len == 0,
    query: Query(kind: userList)
  )

  let raw = json.fromJson(GraphListMembers)
  for instruction in raw.data.list.membersTimeline.timeline.instructions:
    if instruction.kind == "TimelineAddEntries":
      for entry in instruction.entries:
        case entry.content.entryType
        of TimelineTimelineItem:
          let userResult = entry.content.itemContent.userResults.result
          if userResult.restId.len > 0:
            result.content.add toUser userResult.legacy
        of TimelineTimelineCursor:
          if entry.content.cursorType == "Bottom":
            result.bottom = entry.content.value
