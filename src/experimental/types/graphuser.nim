import options, strutils
from ../../types import User, VerifiedType

type
  GraphUser* = object
    data*: tuple[userResult: UserData]

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

  UserResult* = object
    legacy*: User
    restId*: string
    isBlueVerified*: bool
    unavailableReason*: Option[string]
    core*: UserCore
    avatar*: UserAvatar
    profileBio*: Option[UserBio]
    verification*: Option[Verification]

proc enumHook*(s: string; v: var VerifiedType) =
  v = try:
    parseEnum[VerifiedType](s)
  except:
    VerifiedType.none
