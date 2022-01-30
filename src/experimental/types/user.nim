import options
import jsony
import common

type
  RawUser* = object
    idStr*: string
    name*: string
    screenName*: string
    location*: string
    description*: string
    entities*: Entities
    createdAt*: string
    followersCount*: int
    friendsCount*: int
    favouritesCount*: int
    statusesCount*: int
    mediaCount*: int
    verified*: bool
    protected*: bool
    profileLinkColor*: string
    profileBannerUrl*: string
    profileImageUrlHttps*: string
    profileImageExtensions*: Option[ImageExtensions]
    pinnedTweetIdsStr*: seq[string]

  Entities* = object
    url*: Urls
    description*: Urls

  Urls* = object
    urls*: seq[Url]

  ImageExtensions = object
    mediaColor*: tuple[r: Ok]

  Ok = object
    ok*: Palette

  Palette = object
    palette*: seq[tuple[rgb: Color]]

  Color* = object
    red*, green*, blue*: int

proc parseHook*(s: string; i: var int; v: var Slice[int]) =
  var slice: array[2, int]
  parseHook(s, i, slice)
  v = slice[0] ..< slice[1]
