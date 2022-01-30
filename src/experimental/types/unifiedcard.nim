import options, tables
import media as mediaTypes

type
  UnifiedCard* = object
    componentObjects*: Table[string, Component]
    destinationObjects*: Table[string, Destination]
    mediaEntities*: Table[string, MediaEntity]
    appStoreData*: Table[string, seq[AppStoreData]]

  ComponentType* = enum
    details
    media
    swipeableMedia
    buttonGroup
    appStoreDetails
    twitterListDetails
    communityDetails
    mediaWithDetailsHorizontal

  Component* = object
    kind*: ComponentType
    data*: ComponentData

  ComponentData* = object
    id*: string
    appId*: string
    mediaId*: string
    destination*: string
    title*: Text
    subtitle*: Text
    name*: Text
    memberCount*: int
    mediaList*: seq[MediaItem]
    topicDetail*: tuple[title: Text]

  MediaItem* = object
    id*: string
    destination*: string

  UrlData* = object
    url*: string
    vanity*: string

  Destination* = object
    kind*: string
    data*: tuple[urlData: UrlData]

  AppType* = enum
    androidApp, iPhoneApp, iPadApp

  AppStoreData* = object
    kind*: AppType
    id*: string
    title*: Text
    category*: Text

  Text = object
    content: string

  HasTypeField = Component | Destination | MediaEntity | AppStoreData

converter fromText*(text: Text): string = text.content

proc renameHook*(v: var HasTypeField; fieldName: var string) =
  if fieldName == "type":
    fieldName = "kind"
