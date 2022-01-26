import user

type
  GraphUserResult* = object
    legacy*: RawUser
    restId*: string

  GraphUserData* = object
    result*: GraphUserResult

  GraphUser* = object
    data*: tuple[user: GraphUserData]
