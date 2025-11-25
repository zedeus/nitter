import std/[algorithm, unicode, re, strutils, strformat, options, nre]
import jsony
import utils, slices
import ../types/user as userType
from ../../types import Result, User, Error

let
  unRegex = re.re"(^|[^A-z0-9-_./?])@([A-z0-9_]{1,15})"
  unReplace = "$1<a href=\"/$2\">@$2</a>"

  htRegex = nre.re"""(*U)(^|[^\w-_.?])([#＃$])([\w_]*+)(?!</a>|">|#)"""
  htReplace = "$1<a href=\"/search?q=%23$3\">$2$3</a>"

proc expandUserEntities(user: var User; raw: RawUser) =
  let
    orig = user.bio.toRunes
    ent = raw.entities

  if ent.url.urls.len > 0:
    user.website = ent.url.urls[0].expandedUrl

  var replacements = newSeq[ReplaceSlice]()

  for u in ent.description.urls:
    replacements.extractUrls(u, orig.high)

  replacements.dedupSlices
  replacements.sort(cmp)

  user.bio = orig.replacedWith(replacements, 0 .. orig.len)
                 .replacef(unRegex, unReplace)
                 .replace(htRegex, htReplace)

proc getBanner(user: RawUser): string =
  if user.profileBannerUrl.len > 0:
    return user.profileBannerUrl & "/1500x500"

  if user.profileLinkColor.len > 0:
    return '#' & user.profileLinkColor

  if user.profileImageExtensions.isSome:
    let ext = get(user.profileImageExtensions)
    if ext.mediaColor.r.ok.palette.len > 0:
      let color = ext.mediaColor.r.ok.palette[0].rgb
      return &"#{color.red:02x}{color.green:02x}{color.blue:02x}"

proc toUser*(raw: RawUser): User =
  result = User(
    id: raw.idStr,
    username: raw.screenName,
    fullname: raw.name,
    location: raw.location,
    bio: raw.description,
    following: raw.friendsCount,
    followers: raw.followersCount,
    tweets: raw.statusesCount,
    likes: raw.favouritesCount,
    media: raw.mediaCount,
    verifiedType: raw.verifiedType,
    protected: raw.protected,
    banner: getBanner(raw),
    userPic: getImageUrl(raw.profileImageUrlHttps).replace("_normal", "")
  )

  if raw.createdAt.len > 0:
    result.joinDate = parseTwitterDate(raw.createdAt)

  if raw.pinnedTweetIdsStr.len > 0:
    result.pinnedTweet = parseBiggestInt(raw.pinnedTweetIdsStr[0])

  result.expandUserEntities(raw)

proc parseHook*(s: string; i: var int; v: var User) =
  var u: RawUser
  parseHook(s, i, u)
  v = toUser u
