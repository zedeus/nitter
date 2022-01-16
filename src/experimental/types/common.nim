from ../../types import Error

type
  Url* = object
    url*: string
    expandedUrl*: string
    displayUrl*: string
    indices*: array[2, int]

  ErrorCode* = enum
    null = 0
    noUserMatches = 17
    protectedUser = 22
    couldntAuth = 32
    doesntExist = 34
    userNotFound = 50
    suspended = 63
    rateLimited = 88
    invalidToken = 89
    listIdOrSlug = 112
    forbidden = 200
    badToken = 239
    noCsrf = 353

  ErrorObj* = object
    code*: Error
    message*: string

  Errors* = object
    errors*: seq[ErrorObj]
