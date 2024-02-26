import options
from ../../types import User

type
  GraphUser* = object
    data*: tuple[userResult: UserData]

  UserData* = object
    result*: UserResult

  UserResult = object
    legacy*: User
    restId*: string
    isBlueVerified*: bool
    unavailableReason*: Option[string]
