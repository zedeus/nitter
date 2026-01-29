import options, strutils
import jsony
import user, utils, ../types/[graphuser, graphlistmembers]
from ../../types import User, VerifiedType, Result, Query, QueryKind

proc parseUserResult*(userResult: UserResult): User =
  result = userResult.legacy

  if result.verifiedType == none and userResult.isBlueVerified:
    result.verifiedType = blue

  if result.username.len == 0 and userResult.core.screenName.len > 0:
    result.id = userResult.restId
    result.username = userResult.core.screenName
    result.fullname = userResult.core.name
    result.userPic = userResult.avatar.imageUrl.replace("_normal", "")

    if userResult.privacy.isSome:
      result.protected = userResult.privacy.get.protected

    if userResult.location.isSome:
      result.location = userResult.location.get.location

    if userResult.core.createdAt.len > 0:
      result.joinDate = parseTwitterDate(userResult.core.createdAt)

    if userResult.verification.isSome:
      let v = userResult.verification.get
      if v.verifiedType != VerifiedType.none:
        result.verifiedType = v.verifiedType

    if userResult.profileBio.isSome and result.bio.len == 0:
      result.bio = userResult.profileBio.get.description

proc parseGraphUser*(json: string): User =
  if json.len == 0 or json[0] != '{':
    return

  let 
    raw = json.fromJson(GraphUser)
    userResult = 
      if raw.data.userResult.isSome: raw.data.userResult.get.result
      elif raw.data.user.isSome: raw.data.user.get.result
      else: UserResult()

  if userResult.unavailableReason.get("") == "Suspended" or
     userResult.reason.get("") == "Suspended":
    return User(suspended: true)

  result = parseUserResult(userResult)

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
            result.content.add parseUserResult(userResult)
        of TimelineTimelineCursor:
          if entry.content.cursorType == "Bottom":
            result.bottom = entry.content.value
