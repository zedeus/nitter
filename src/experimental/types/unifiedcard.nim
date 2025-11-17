import std/[options, tables, times]
import jsony
from ../../types import VideoType, VideoVariant, User

type
  Text* = distinct string

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
    jobDetails
    appStoreDetails
    twitterListDetails
    communityDetails
    mediaWithDetailsHorizontal
    hidden
    grokShare
    unknown

  Component* = object
    kind*: ComponentType
    data*: ComponentData

  ComponentData* = object
    id*: string
    appId*: string
    mediaId*: string
    destination*: string
    location*: string
    title*: Text
    subtitle*: Text
    name*: Text
    memberCount*: int
    mediaList*: seq[MediaItem]
    topicDetail*: tuple[title: Text]
    profileUser*: User
    shortDescriptionText*: string
    conversationPreview*: seq[GrokConversation]

  MediaItem* = object
    id*: string
    destination*: string

  Destination* = object
    kind*: string
    data*: tuple[urlData: UrlData]

  UrlData* = object
    url*: string
    vanity*: string

  MediaType* = enum
    photo, video, model3d

  MediaEntity* = object
    kind*: MediaType
    mediaUrlHttps*: string
    videoInfo*: Option[VideoInfo]

  VideoInfo* = object
    durationMillis*: int
    variants*: seq[VideoVariant]

  AppType* = enum
    androidApp, iPhoneApp, iPadApp

  AppStoreData* = object
    kind*: AppType
    id*: string
    title*: Text
    category*: Text

  GrokConversation* = object
    message*: string
    sender*: string

  TypeField = Component | Destination | MediaEntity | AppStoreData

converter fromText*(text: Text): string = string(text)

proc renameHook*(v: var TypeField; fieldName: var string) =
  if fieldName == "type":
    fieldName = "kind"

proc enumHook*(s: string; v: var ComponentType) =
  v = case s
      of "details": details
      of "media": media
      of "swipeable_media": swipeableMedia
      of "button_group": buttonGroup
      of "job_details": jobDetails
      of "app_store_details": appStoreDetails
      of "twitter_list_details": twitterListDetails
      of "community_details": communityDetails
      of "media_with_details_horizontal": mediaWithDetailsHorizontal
      of "commerce_drop_details": hidden
      of "grok_share": grokShare
      else: echo "ERROR: Unknown enum value (ComponentType): ", s; unknown

proc enumHook*(s: string; v: var AppType) =
  v = case s
      of "android_app": androidApp
      of "iphone_app": iPhoneApp
      of "ipad_app": iPadApp
      else: echo "ERROR: Unknown enum value (AppType): ", s; androidApp

proc enumHook*(s: string; v: var MediaType) =
  v = case s
      of "video": video
      of "photo": photo
      of "model3d": model3d
      else: echo "ERROR: Unknown enum value (MediaType): ", s; photo

proc parseHook*(s: string; i: var int; v: var DateTime) =
  var str: string
  parseHook(s, i, str)
  v = parse(str, "yyyy-MM-dd hh:mm:ss")

proc parseHook*(s: string; i: var int; v: var Text) =
  if s[i] == '"':
    var str: string
    parseHook(s, i, str)
    v = Text(str)
  else:
    var t: tuple[content: string]
    parseHook(s, i, t)
    v = Text(t.content)
