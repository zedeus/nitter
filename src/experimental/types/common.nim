from ../../types import Error

type
  Url* = object
    url*: string
    expandedUrl*: string
    displayUrl*: string
    indices*: array[2, int]

  ErrorObj* = object
    code*: Error
    message*: string

  Errors* = object
    errors*: seq[ErrorObj]
