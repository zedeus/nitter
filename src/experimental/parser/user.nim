import std/[algorithm, unicode, re, strutils]
import jsony
import utils, slices
import ../types/user as userType
from ../../types import Profile, Error

let
  unRegex = re"(^|[^A-z0-9-_./?])@([A-z0-9_]{1,15})"
  unReplace = "$1<a href=\"/$2\">@$2</a>"

  htRegex = re"(^|[^\w-_./?])([#＃$])([\w_]+)"
  htReplace = "$1<a href=\"/search?q=%23$3\">$2$3</a>"

proc expandProfileEntities(profile: var Profile; user: User) =
  let
    orig = profile.bio.toRunes
    ent = user.entities

  if ent.url.urls.len > 0:
    profile.website = ent.url.urls[0].expandedUrl

  var replacements = newSeq[ReplaceSlice]()

  for u in ent.description.urls:
    replacements.extractUrls(u, orig.high)

  replacements.dedupSlices
  replacements.sort(cmp)

  profile.bio = orig.replacedWith(replacements, 0 .. orig.len)
                    .replacef(unRegex, unReplace)
                    .replacef(htRegex, htReplace)

proc getBanner(user: User): string =
  if user.profileBannerUrl.len > 0:
    return user.profileBannerUrl & "/1500x500"
  if user.profileLinkColor.len > 0:
    return '#' & user.profileLinkColor
  return "#161616"

proc parseUser*(json: string; username=""): Profile =
  handleErrors:
    case error.code
    of suspended: return Profile(username: username, suspended: true)
    of userNotFound: return
    else: echo "[error - parseUser]: ", error

  let user = json.fromJson(User)

  result = Profile(
    id: user.idStr,
    username: user.screenName,
    fullname: user.name,
    location: user.location,
    bio: user.description,
    following: user.friendsCount,
    followers: user.followersCount,
    tweets: user.statusesCount,
    likes: user.favouritesCount,
    media: user.mediaCount,
    verified: user.verified,
    protected: user.protected,
    joinDate: parseTwitterDate(user.createdAt),
    banner: getBanner(user),
    userPic: getImageUrl(user.profileImageUrlHttps).replace("_normal", "")
  )

  result.expandProfileEntities(user)
