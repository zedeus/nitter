import std/[options, tables, strutils, strformat, sugar]
import jsony
import user, ../types/unifiedcard
from ../../types import Card, CardKind, Video
from ../../utils import twimg, https

proc getImageUrl(entity: MediaEntity): string =
  entity.mediaUrlHttps.dup(removePrefix(twimg), removePrefix(https))

proc parseDestination(id: string; card: UnifiedCard; result: var Card) =
  let destination = card.destinationObjects[id].data
  result.dest = destination.urlData.vanity
  result.url = destination.urlData.url

proc parseDetails(data: ComponentData; card: UnifiedCard; result: var Card) =
  data.destination.parseDestination(card, result)

  result.text = data.title
  if result.text.len == 0:
    result.text = data.name

proc parseMediaDetails(data: ComponentData; card: UnifiedCard; result: var Card) =
  data.destination.parseDestination(card, result)

  result.kind = summary
  result.image = card.mediaEntities[data.mediaId].getImageUrl
  result.text = data.topicDetail.title
  result.dest = "Topic"

proc parseJobDetails(data: ComponentData; card: UnifiedCard; result: var Card) =
  data.destination.parseDestination(card, result)

  result.kind = CardKind.jobDetails
  result.title = data.title
  result.text = data.shortDescriptionText
  result.dest = &"@{data.profileUser.username} · {data.location}"

proc parseAppDetails(data: ComponentData; card: UnifiedCard; result: var Card) =
  let app = card.appStoreData[data.appId][0]

  case app.kind
  of androidApp:
    result.url = "http://play.google.com/store/apps/details?id=" & app.id
  of iPhoneApp, iPadApp:
    result.url = "https://itunes.apple.com/app/id" & app.id

  result.text = app.title
  result.dest = app.category

proc parseListDetails(data: ComponentData; result: var Card) =
  result.dest = &"List · {data.memberCount} Members"

proc parseCommunityDetails(data: ComponentData; result: var Card) =
  result.dest = &"Community · {data.memberCount} Members"

proc parseMedia(component: Component; card: UnifiedCard; result: var Card) =
  let mediaId =
    if component.kind == swipeableMedia:
      component.data.mediaList[0].id
    else:
      component.data.id

  let rMedia = card.mediaEntities[mediaId]
  case rMedia.kind:
  of photo:
    result.kind = summaryLarge
    result.image = rMedia.getImageUrl
  of video:
    let videoInfo = rMedia.videoInfo.get
    result.kind = promoVideo
    result.video = some Video(
      available: true,
      thumb: rMedia.getImageUrl,
      durationMs: videoInfo.durationMillis,
      variants: videoInfo.variants
    )
  of model3d:
    result.title = "Unsupported 3D model ad"

proc parseUnifiedCard*(json: string): Card =
  let card = json.fromJson(UnifiedCard)

  for component in card.componentObjects.values:
    case component.kind
    of details, communityDetails, twitterListDetails:
      component.data.parseDetails(card, result)
    of appStoreDetails:
      component.data.parseAppDetails(card, result)
    of mediaWithDetailsHorizontal:
      component.data.parseMediaDetails(card, result)
    of media, swipeableMedia:
      component.parseMedia(card, result)
    of buttonGroup:
      discard
    of ComponentType.jobDetails:
      component.data.parseJobDetails(card, result)
    of ComponentType.hidden:
      result.kind = CardKind.hidden
    of ComponentType.unknown:
      echo "ERROR: Unknown component type: ", json

    case component.kind
    of twitterListDetails:
      component.data.parseListDetails(result)
    of communityDetails:
      component.data.parseCommunityDetails(result)
    else: discard
