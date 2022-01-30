import std/[json, strutils, times, math]
import utils
import ".."/types/[media, tweet]
from ../../types import Poll, Gif, Video, VideoVariant, VideoType

proc parseVideo*(entity: Entity): Video =
  result = Video(
    thumb: entity.mediaUrlHttps.getImageUrl,
    views: entity.ext.mediaStats{"r", "ok", "viewCount"}.getStr,
    available: entity.extMediaAvailability.status == "available",
    title: entity.extAltText,
    durationMs: entity.videoInfo.durationMillis,
    description: entity.additionalMediaInfo.description,
    variants: entity.videoInfo.variants
    # playbackType: mp4
  )

  if entity.additionalMediaInfo.title.len > 0:
    result.title = entity.additionalMediaInfo.title

proc parseGif*(entity: Entity): Gif =
  result = Gif(
    url: entity.videoInfo.variants[0].url.getImageUrl,
    thumb: entity.getImageUrl
  )

proc parsePoll*(card: Card): Poll =
  let vals = card.bindingValues

  # name format is pollNchoice_*
  for i in '1' .. card.name[4]:
    let choice = "choice" & i
    result.values.add parseInt(vals{choice & "_count", "string_value"}.getStr("0"))
    result.options.add vals{choice & "_label", "string_value"}.getStr

  let time = vals{"end_datetime_utc", "string_value"}.getStr.parseIsoDate
  if time > now():
    let timeLeft = $(time - now())
    result.status = timeLeft[0 ..< timeLeft.find(",")]
  else:
    result.status = "Final results"

  result.leader = result.values.find(max(result.values))
  result.votes = result.values.sum
