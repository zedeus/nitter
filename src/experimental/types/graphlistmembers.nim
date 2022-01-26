import graphuser

type
  GraphListMembers* = object
    data*: tuple[list: List]

  List = object
    membersTimeline*: tuple[timeline: Timeline]

  Timeline = object
    instructions*: seq[Instruction]

  Instruction = object
    kind*: string
    entries*: seq[tuple[content: Content]]

  ContentEntryType* = enum
    TimelineTimelineItem
    TimelineTimelineCursor

  Content = object
    case entryType*: ContentEntryType
    of TimelineTimelineItem:
      itemContent*: tuple[userResults: UserData]
    of TimelineTimelineCursor:
      value*: string
      cursorType*: string

proc renameHook*(v: var Instruction; fieldName: var string) =
  if fieldName == "type":
    fieldName = "kind"
