# SPDX-License-Identifier: AGPL-3.0-only
import graphlistmembers

type
  GraphFollowers* = object
    data*: tuple[user: UserWrapper]

  UserWrapper = object
    result*: UserResultWrapper

  UserResultWrapper = object
    timeline*: tuple[timeline: graphlistmembers.Timeline]

# Hook to normalize snake_case field from API to camelCase used by shared types
proc renameHook*(v: var Content; fieldName: var string) =
  if fieldName == "user_results":
    fieldName = "userResults"
