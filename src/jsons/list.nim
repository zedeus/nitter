# SPDX-License-Identifier: AGPL-3.0-only
import json

import renderutils
import ".."/[types]

proc getListJson*(list: List): JsonNode =
  result = %*{
    "id": list.id,
    "name": list.name,
    "userId": list.userId,
    "username": list.username,
    "description": list.description,
    "members": list.members,
    "banner": list.banner
  }
