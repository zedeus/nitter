import options
import user

type
  GraphUser* = object
    data*: tuple[user: UserData]

  UserData* = object
    result*: UserResult

  UserResult = object
    legacy*: RawUser
    restId*: string
    reason*: Option[string]
