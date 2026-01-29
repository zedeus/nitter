import options, strutils
from ../../types import User, VerifiedType

type
  GraphUser* = object
    data*: tuple[userResult: Option[UserData], user: Option[UserData]]

  UserData* = object
    result*: UserResult

  UserCore* = object
    name*: string
    screenName*: string
    createdAt*: string

  UserBio* = object
    description*: string

  UserAvatar* = object
    imageUrl*: string

  Verification* = object
    verifiedType*: VerifiedType

  Location* = object
    location*: string

  Privacy* = object
    protected*: bool

  UserResult* = object
    legacy*: User
    restId*: string
    isBlueVerified*: bool
    core*: UserCore
    avatar*: UserAvatar
    unavailableReason*: Option[string]
    reason*: Option[string]
    privacy*: Option[Privacy]
    profileBio*: Option[UserBio]
    verification*: Option[Verification]
    location*: Option[Location]

proc enumHook*(s: string; v: var VerifiedType) =
  v = try:
    parseEnum[VerifiedType](s)
  except:
    VerifiedType.none
