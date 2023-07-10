import options
import user

type
  GraphUser* = object
    data*: tuple[userResult: UserData]

  UserData* = object
    result*: UserResult

  UserResult = object
    legacy*: RawUser
    restId*: string
    isBlueVerified*: bool
    unavailableReason*: Option[string]
