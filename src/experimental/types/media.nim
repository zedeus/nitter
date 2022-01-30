import options
from ../../types import VideoType, VideoVariant

type
  MediaType* = enum
    photo, video, animatedGif

  MediaEntity* = object
    kind*: MediaType
    mediaUrlHttps*: string
    videoInfo*: Option[VideoInfo]

  VideoInfo* = object
    durationMillis*: int
    variants*: seq[VideoVariant]
